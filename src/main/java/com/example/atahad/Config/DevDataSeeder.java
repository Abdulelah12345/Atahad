package com.example.atahad.Config;

import com.example.atahad.Dto.In.*;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.*;
import com.example.atahad.Service.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

import java.io.InputStream;
import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;

// test data for the app, runs once on an empty database
// on only when seed.enabled=true (in application-local.properties), the main user's email and phone are there too
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "seed.enabled", havingValue = "true")
public class DevDataSeeder implements ApplicationRunner {

    private final MemberService memberService;
    private final AdminService adminService;
    private final HabitService habitService;
    private final GroupService groupService;
    private final GroupMemberService groupMemberService;
    private final GroupGoalService groupGoalService;
    private final GoalProposalService goalProposalService;
    private final ChatMessageService chatMessageService;
    private final CommitmentWeekService commitmentWeekService;
    private final GroupAccessService groupAccessService;

    private final UserRepository userRepository;
    private final MemberRepository memberRepository;
    private final GroupRepository groupRepository;
    private final GroupMemberRepository groupMemberRepository;
    private final GroupGoalRepository groupGoalRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final ChatMessageRepository chatMessageRepository;
    private final ExcuseRepository excuseRepository;
    private final PenaltyRepository penaltyRepository;
    private final GraceDayRepository graceDayRepository;
    private final GroupSettlementRepository groupSettlementRepository;
    private final MomentRepository momentRepository;

    @Value("${seed.main-email}")
    private String mainEmail;
    @Value("${seed.main-phone}")
    private String mainPhone;
    @Value("${seed.password:Atahad123}")
    private String password;
    @Value("${seed.friend-email:}")
    private String friendEmail; // a real account of a friend to test with (optional)
    @Value("${seed.place-lat:24.7136}")
    private Double placeLat;
    @Value("${seed.place-lng:46.6753}")
    private Double placeLng;

    @Override
    public void run(ApplicationArguments args) {
        if (userRepository.findUserByEmail(mainEmail) != null) {
            log.info("Seed: the data is already there, nothing added");
            return;
        }

        // ---------- the users ----------
        Member noura = member("نوره", mainEmail, mainPhone);
        Member sara = member("سارة", "sara@atahad.test", "+15550100001");
        Member reem = member("ريم", "reem@atahad.test", "+15550100002");
        Member lama = member("لمى", "lama@atahad.test", "+15550100003");
        Member dana = member("دانة", "dana@atahad.test", "+15550100004");
        Member jana = member("جنى", "jana@atahad.test", "+15550100005");
        Member faisal = member("فيصل", "faisal@atahad.test", "+15550100010");
        Member mohammed = member("محمد", "mohammed@atahad.test", "+15550100011");
        Member amal = member("عبدالله", "abdullah@atahad.test", "+15550100006");
        Member hind = member("هند", "hind@atahad.test", "+15550100007");
        Member jood = member("عمر", "omar@atahad.test", "+15550100008");
        admin("فريق المراجعة", "admin@atahad.test", "+15550100009");
        Member friend = friendEmail.isBlank() ? null : member("عبدالإله", friendEmail, "+15550100012");

        // ---------- Noura's own habits ----------
        Habit walk = new Habit();
        walk.setTitle("المشي ٣٠ دقيقة");
        walk.setProofMethod("PHOTO");
        walk.setTimesPerWeek(3);
        walk.setBaseAmount(new BigDecimal("10.00"));
        walk.setPlannedDays(Set.of("SUN", "TUE", "THU"));
        habitService.addHabit(noura.getId(), walk);

        Habit read = new Habit();
        read.setTitle("قراءة ٢٠ دقيقة");
        read.setProofMethod("TIMER");
        read.setTargetMinutes(20);
        read.setTimesPerWeek(4);
        read.setBaseAmount(new BigDecimal("5.00"));
        read.setPlannedDays(Set.of("SUN", "MON", "WED", "FRI"));
        habitService.addHabit(noura.getId(), read);

        // walked once today
        commitmentWeekService.recordCompletion(commitmentWeekService.getCurrentWeek(noura.getId(), walk.getId()).getId(), null);

        // an excuse waiting for the admin (travel)
        CommitmentWeek readWeek = commitmentWeekService.getCurrentWeek(noura.getId(), read.getId());
        Excuse excuse = new Excuse();
        excuse.setType("TRAVEL");
        excuse.setExcuseDate(LocalDate.now());
        excuse.setAiAssessment("العذر يبدو منطقيًا لكن المرفق غير واضح، يحتاج مراجعة المشرف");
        excuse.setStatus("ESCALATED");
        excuse.setProcessingStatus("FINISHED");
        excuse.setForwardedToAdmin(true);
        excuse.setCommitmentWeek(readWeek);
        excuseRepository.save(excuse);

        // a habit proved by the location (the place is in application-local.properties, the simulator can be moved there)
        Habit club = new Habit();
        club.setTitle("الذهاب للنادي");
        club.setProofMethod("LOCATION");
        club.setTimesPerWeek(3);
        club.setBaseAmount(new BigDecimal("10.00"));
        club.setTargetLatitude(placeLat);
        club.setTargetLongitude(placeLng);
        club.setTargetRadiusMeters(150);
        club.setTargetPlaceName("النادي");
        club.setTargetMinutes(2); // 2 minutes inside the place, short for testing
        club.setPlannedDays(Set.of("SUN", "TUE", "THU"));
        habitService.addHabit(noura.getId(), club);

        // ---------- group 1: Noura is the owner, active goal ----------
        Group gym = group(noura, "Healthier Month", "شهر صحي: نتمرن بالنادي ٣ مرات بالأسبوع");
        join(gym, sara, reem, lama);
        if (friend != null) join(gym, friend);
        GroupGoalRequest gymGoal = new GroupGoalRequest();
        gymGoal.setTitle("تمرين بالنادي");
        gymGoal.setProofMethod("LOCATION"); // every member chooses his own gym from the search
        gymGoal.setTargetMinutes(2); // 2 minutes inside the place, short for testing
        gymGoal.setTimesPerWeek(3);
        gymGoal.setTotalWeeks(4);
        gymGoal.setAmountPerTime(new BigDecimal("10.00"));
        GroupGoal gymActive = groupGoalService.createGoal(gym.getId(), noura.getId(), gymGoal);

        // Sara is ahead, Noura did one, Reem and Lama nothing yet
        done(gymActive, sara, 2);
        done(gymActive, noura, 1);

        chat(gym, sara, "صباح الخير، خلصت تمريني الثاني");
        chat(gym, noura, "كفو يا سارة! أنا بروح العصر");
        chat(gym, reem, "اليوم مشغولة بس بكرة أعوّض");

        // Sara alerted Noura today
        alert(gym, sara, noura, "باقي لك مرتين هالأسبوع، المجموعة تنتظرك");

        // ---------- group 2: Dana is the owner, no goal yet, proposals and votes ----------
        Group books = group(dana, "٣ كتب في ٤ شهور", "نقرأ ٣ كتب خلال ٤ شهور ونتناقش في كل كتاب");
        join(books, noura, jana);
        proposal(books, dana, "قراءة ١٥ صفحة يوميًا", "كل يوم ١٥ صفحة، نخلص الكتاب تقريبًا كل ٥ أسابيع");
        proposal(books, noura, "جلسة قراءة ٣ مرات بالأسبوع", "كل جلسة ٤٠ دقيقة بالمؤقت");
        GroupGoal first = groupGoalRepository.findGroupGoalsByGroupIdAndStatus(books.getId(), "PROPOSED").get(0);
        goalProposalService.vote(first.getId(), dana.getId());
        goalProposalService.vote(first.getId(), jana.getId());
        chat(books, dana, "صوّتوا على الهدف الجاي، الكتاب الأول نبدأه الأحد");

        // ---------- group 3: Faisal is the owner, a university course with a plan of weeks, Abdullah was kicked ----------
        Group study = group(faisal, "نجتاز مقرر ريض ١٠١ (تفاضل وتكامل ١)", "نذاكر المقرر مع بعض لين الاختبار النهائي");
        join(study, noura, mohammed, amal);
        GroupGoalRequest studyGoal = new GroupGoalRequest();
        studyGoal.setTitle("مذاكرة مركزة");
        studyGoal.setProofMethod("TIMER");
        studyGoal.setTargetMinutes(45);
        studyGoal.setAmountPerTime(new BigDecimal("5.00"));
        studyGoal.setWeeks(List.of(
                new PlanWeekRequest("مراجعة النهايات والاتصال", 3),
                new PlanWeekRequest("حل تمارين الاشتقاق", 4),
                new PlanWeekRequest("مراجعة شاملة للنهائي", 5)));
        groupGoalService.createGoal(study.getId(), faisal.getId(), studyGoal);
        GroupMember amalInStudy = groupAccessService.getActiveMembership(study.getId(), amal.getId());
        groupGoalService.removeMemberCommitment(study, amal, false);
        amalInStudy.setFailureCount(2);
        amalInStudy.setStatus("KICKED");
        groupMemberRepository.save(amalInStudy);
        groupAccessService.systemMessage(study, "عبدالله خرج من المجموعة بعد إخفاقين");

        // ---------- group 4: archived, the goal ended with a summary ----------
        Group summer = group(noura, "نتعلم السباحة بالصيف", "حصص سباحة طول الصيف");
        join(summer, sara);
        GroupGoalRequest summerGoal = new GroupGoalRequest();
        summerGoal.setTitle("حصة سباحة");
        summerGoal.setProofMethod("PHOTO");
        summerGoal.setTimesPerWeek(3);
        summerGoal.setTotalWeeks(1);
        summerGoal.setAmountPerTime(new BigDecimal("5.00"));
        GroupGoal summerActive = groupGoalService.createGoal(summer.getId(), noura.getId(), summerGoal);
        GroupSettlement settlement = new GroupSettlement();
        settlement.setWeekStart(LocalDate.now().minusWeeks(1));
        settlement.setSettlementText("أسبوع قوي! سارة حضرت كل الحصص، ونوره فاتتها حصة وحدة. استمروا");
        settlement.setTitles("IRON=" + groupAccessService.getActiveMembership(summer.getId(), sara.getId()).getId());
        settlement.setCreatedAt(LocalDateTime.now().minusDays(1));
        settlement.setGroupGoal(summerActive);
        groupSettlementRepository.save(settlement);
        groupGoalService.endGoal(summerActive);
        summer.setStatus("ARCHIVED");
        groupRepository.save(summer);

        // ---------- moments (photos in src/main/resources/seed/moments) ----------
        moment(gym, noura, "walk.jpg", 0, 8);
        moment(gym, sara, "gym.jpg", 0, 2);
        moment(gym, sara, "water.jpg", 1, 5);
        moment(gym, noura, "gym.jpg", 2, 3);
        moment(gym, noura, "water.jpg", 4, 6);
        moment(gym, sara, "walk.jpg", 6, 1);
        moment(books, noura, "reading.jpg", 0, 4);
        moment(books, dana, "reading.jpg", 3, 2);
        moment(study, noura, "study.jpg", 0, 1);
        moment(study, faisal, "study.jpg", 2, 7);

        // ---------- member states ----------
        // Noura: committed, a grace day ready
        noura = memberRepository.findMemberById(noura.getId());
        noura.setLevel("COMMITTED");
        noura.setConsecutiveWeeks(3);
        noura.setPoints(120);
        memberRepository.save(noura);
        graceDay(noura);

        // Sara: the strongest
        sara = memberRepository.findMemberById(sara.getId());
        sara.setLevel("IRON");
        sara.setConsecutiveWeeks(9);
        sara.setPoints(140);
        memberRepository.save(sara);

        // Lama: locked, an unpaid penalty
        lama = memberRepository.findMemberById(lama.getId());
        Penalty penalty = new Penalty();
        penalty.setAmount(new BigDecimal("20.00"));
        penalty.setReason("LOST_DAY");
        penalty.setStatus("PENDING");
        penalty.setCreatedAt(LocalDateTime.now().minusDays(1));
        penalty.setMember(lama);
        penalty.setCommitmentWeek(groupGoalService.currentWeek(gymActive, lama));
        penaltyRepository.save(penalty);
        lama.setIsLocked(true);
        memberRepository.save(lama);

        // Omar: refused to pay a group penalty, banned from groups for a month
        jood = memberRepository.findMemberById(jood.getId());
        jood.setGroupRefusalCount(1);
        jood.setGroupBanUntil(LocalDate.now().plusMonths(1));
        memberRepository.save(jood);

        // Hind: new, no groups (join by code or add her by phone)

        log.info("Seed: done, every account uses the same password");
    }

    private Member member(String name, String email, String phone) {
        MemberRegisterRequest dto = new MemberRegisterRequest(name, email, phone, password);
        memberService.registerMember(dto);
        return memberRepository.findMemberById(userRepository.findUserByEmail(email).getId());
    }

    private void admin(String name, String email, String phone) {
        adminService.registerAdmin(new AdminRegisterRequest(name, email, phone, password, "مراجعة الأعذار"));
    }

    private Group group(Member owner, String name, String description) {
        Integer id = groupService.addGroup(owner.getId(), new GroupCreateRequest(name, description)).getId();
        return groupAccessService.getGroup(id);
    }

    private void join(Group group, Member... members) {
        for (Member m : members) {
            groupMemberService.joinGroup(m.getId(), group.getInviteCode());
        }
    }

    private void done(GroupGoal goal, Member member, int times) {
        for (int i = 0; i < times; i++) {
            commitmentWeekService.recordCompletion(groupGoalService.currentWeek(goal, member).getId(), null);
        }
    }

    private void chat(Group group, Member member, String text) {
        chatMessageService.send(group.getId(), member.getId(), new ChatMessageRequest(text));
    }

    private void alert(Group group, Member from, Member to, String text) {
        ChatMessage message = new ChatMessage();
        message.setType("ALERT");
        message.setContent(text);
        message.setSentAt(LocalDateTime.now());
        message.setGroup(group);
        message.setSender(groupAccessService.getActiveMembership(group.getId(), from.getId()));
        message.setReceiver(groupAccessService.getActiveMembership(group.getId(), to.getId()));
        chatMessageRepository.save(message);
    }

    private void proposal(Group group, Member member, String title, String details) {
        goalProposalService.propose(group.getId(), member.getId(), new GoalProposalRequest(title, details));
    }

    // a photo moment shared with the group, days and hours ago (the old ones show in the past weeks)
    private void moment(Group group, Member member, String file, int daysAgo, int hoursAgo) {
        String name = "seed-" + file;
        try (InputStream in = new ClassPathResource("seed/moments/" + file).getInputStream()) {
            Files.createDirectories(MomentService.UPLOADS);
            Files.copy(in, MomentService.UPLOADS.resolve(name), StandardCopyOption.REPLACE_EXISTING);
        } catch (Exception e) {
            log.warn("Seed: the photo {} was not copied", file);
            return;
        }
        Moment moment = new Moment();
        moment.setMediaUrl("/uploads/moments/" + name); // the app puts the server address before it
        moment.setMediaType("PHOTO");
        moment.setVisibility("GROUP");
        moment.setCreatedAt(LocalDateTime.now().minusDays(daysAgo).minusHours(hoursAgo));
        moment.setMember(member);
        moment.setGroup(group);
        momentRepository.save(moment);
    }

    private void graceDay(Member member) {
        GraceDay day = new GraceDay();
        day.setSource("PERSONAL_POINTS");
        day.setEarnedAt(LocalDate.now().minusDays(3));
        day.setExpiresAt(LocalDate.now().minusDays(3).plusWeeks(4));
        day.setMember(member);
        graceDayRepository.save(day);
    }
}
