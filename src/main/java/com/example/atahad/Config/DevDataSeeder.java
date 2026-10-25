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
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
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

        // ---------- the users: 5 members and 1 admin ----------
        Member noura = member("نوره", mainEmail, mainPhone);
        Member sara = member("سارة", "sara@atahad.test", "+15550100001");
        Member reem = member("ريم", "reem@atahad.test", "+15550100002");
        Member faisal = member("فيصل", "faisal@atahad.test", "+15550100003");
        Member abdulelah = member("عبدالإله", friendEmail.isBlank() ? "abdulelah@atahad.test" : friendEmail, "+15550100004");
        admin("فريق المراجعة", "admin@atahad.test", "+15550100009");

        LocalDate thisSunday = LocalDate.now().with(TemporalAdjusters.previousOrSame(DayOfWeek.SUNDAY));
        LocalDate lastSunday = thisSunday.minusWeeks(1);
        LocalDate twoWeeksAgo = thisSunday.minusWeeks(2);

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

        // walked once this week
        commitmentWeekService.recordCompletion(commitmentWeekService.getCurrentWeek(noura.getId(), walk.getId()).getId(), null);

        // an excuse waiting for the admin (travel)
        Excuse excuse = new Excuse();
        excuse.setType("TRAVEL");
        excuse.setExcuseDate(LocalDate.now());
        excuse.setAiAssessment("العذر يبدو منطقيًا لكن المرفق غير واضح، يحتاج مراجعة المشرف");
        excuse.setStatus("ESCALATED");
        excuse.setProcessingStatus("FINISHED");
        excuse.setForwardedToAdmin(true);
        excuse.setCommitmentWeek(commitmentWeekService.getCurrentWeek(noura.getId(), read.getId()));
        excuseRepository.save(excuse);

        // ---------- group 1: Healthier Month, all 5 members, in its third week with two settled weeks ----------
        Group gym = group(noura, "Healthier Month", "شهر صحي: نتمرن بالنادي ٣ مرات بالأسبوع");
        join(gym, sara, reem, faisal, abdulelah);
        GroupGoalRequest gymGoal = new GroupGoalRequest();
        gymGoal.setTitle("تمرين بالنادي");
        gymGoal.setProofMethod("LOCATION"); // every member chooses his own gym
        gymGoal.setTargetMinutes(2); // 2 minutes inside the place, short for testing
        gymGoal.setTimesPerWeek(3);
        gymGoal.setTotalWeeks(4);
        gymGoal.setAmountPerTime(new BigDecimal("10.00"));
        GroupGoal gymActive = groupGoalService.createGoal(gym.getId(), noura.getId(), gymGoal);
        // it started two weeks ago (week 3 of 4 now)
        gymActive.setStartDate(twoWeeksAgo);
        gymActive.setEndDate(twoWeeksAgo.plusDays(6).plusWeeks(3));
        groupGoalRepository.save(gymActive);

        // the two past weeks: the AI summary and the titles of every week
        GroupSettlement week1 = settlement(gymActive, twoWeeksAgo,
                "أول أسبوع وبداية حلوة! سارة كمّلت الثلاث مرات قبل الكل، ونوره نبّهت المجموعة أكثر وحدة. ريم فاتتها مرتين وتبرعت بالمبلغ، الأسبوع الجاي نبيها معنا.",
                titles(gym, "IRON", sara, "ROCKET", sara, "ALARMIST", noura));
        GroupSettlement week2 = settlement(gymActive, lastSunday,
                "أسبوع أقوى من اللي قبله! ريم رجعت وكمّلت كل مراتها، وعبدالإله أول واحد خلّص. فيصل سجّل أغلب إثباتاته بالليل. باقي أسبوعين ونخلص الشهر.",
                titles(gym, "IRON", sara, "ROCKET", abdulelah, "COMEBACK", reem, "OWL", faisal, "TOP_DONOR", reem));

        // what the members won last week, and the points of the group
        setTitle(gym, sara, "IRON", 60);
        setTitle(gym, abdulelah, "ROCKET", 45);
        setTitle(gym, reem, "COMEBACK,TOP_DONOR", 30);
        setTitle(gym, faisal, "OWL", 40);
        setTitle(gym, noura, null, 50);
        gym.setPoints(225);
        groupRepository.save(gym);

        // Reem missed two times in the first week and paid them
        Penalty paid = new Penalty();
        paid.setAmount(new BigDecimal("20.00"));
        paid.setReason("LOST_DAY");
        paid.setStatus("PAID");
        paid.setCreatedAt(twoWeeksAgo.plusDays(7).atTime(0, 5));
        paid.setPaidAt(twoWeeksAgo.plusDays(8).atTime(19, 30));
        paid.setMember(reem);
        paid.setGroupSettlement(week1);
        penaltyRepository.save(paid);

        // this week: Sara is ahead, Noura and Abdulelah did one, Reem and Faisal nothing yet
        done(gymActive, sara, 2);
        done(gymActive, noura, 1);
        done(gymActive, abdulelah, 1);

        chat(gym, noura, "يلا يا جماعة، الأسبوع الثالث بدأ");
        chat(gym, sara, "صباح الخير، خلصت تمريني الثاني");
        chat(gym, abdulelah, "سجّلت أول مرة اليوم");
        chat(gym, reem, "اليوم مشغولة بس بكرة أعوّض");
        chat(gym, faisal, "أنا بروح الليلة إن شاء الله");

        // Sara alerted Noura today
        alert(gym, sara, noura, "باقي لك مرتين هالأسبوع، المجموعة تنتظرك");

        // ---------- group 2: Sara is the owner, no goal yet, proposals and votes ----------
        Group books = group(sara, "٣ كتب في ٤ شهور", "نقرأ ٣ كتب خلال ٤ شهور ونتناقش في كل كتاب");
        join(books, noura, reem);
        proposal(books, sara, "قراءة ١٥ صفحة يوميًا", "كل يوم ١٥ صفحة، نخلص الكتاب تقريبًا كل ٥ أسابيع");
        proposal(books, noura, "جلسة قراءة ٣ مرات بالأسبوع", "كل جلسة ٤٠ دقيقة بالمؤقت");
        GroupGoal first = groupGoalRepository.findGroupGoalsByGroupIdAndStatus(books.getId(), "PROPOSED").get(0);
        goalProposalService.vote(first.getId(), sara.getId());
        goalProposalService.vote(first.getId(), reem.getId());
        chat(books, sara, "صوّتوا على الهدف الجاي، الكتاب الأول نبدأه الأحد");

        // ---------- group 3: Faisal is the owner, a university course with a plan of weeks ----------
        Group study = group(faisal, "نجتاز مقرر ريض ١٠١ (تفاضل وتكامل ١)", "نذاكر المقرر مع بعض لين الاختبار النهائي");
        join(study, noura, abdulelah);
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
        chat(study, faisal, "الأسبوع هذا النهايات، أول جلسة اليوم ٩ بالليل");

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
        settlement(summerActive, LocalDate.now().minusMonths(3),
                "آخر أسبوع بالصيف! سارة حضرت كل الحصص، ونوره فاتتها حصة وحدة.",
                titles(summer, "IRON", sara));
        groupGoalService.endGoal(summerActive);
        summer.setStatus("ARCHIVED");
        groupRepository.save(summer);

        // ---------- moments (photos in src/main/resources/seed/moments) ----------
        moment(gym, noura, "walk.jpg", 0, 8);
        moment(gym, sara, "gym.jpg", 0, 2);
        moment(gym, abdulelah, "water.jpg", 0, 5);
        moment(gym, sara, "water.jpg", 2, 5);
        moment(gym, noura, "gym.jpg", 3, 3);
        moment(gym, reem, "walk.jpg", 5, 1);
        moment(gym, faisal, "gym.jpg", 9, 2);
        moment(books, noura, "reading.jpg", 0, 4);
        moment(books, sara, "reading.jpg", 3, 2);
        moment(study, noura, "study.jpg", 0, 1);
        moment(study, faisal, "study.jpg", 1, 7);

        // ---------- member states ----------
        level(noura, "COMMITTED", 3, 120);
        graceDay(noura);
        level(sara, "IRON", 9, 140);
        level(reem, "BEGINNER", 1, 40);
        level(faisal, "COMMITTED", 2, 90);
        level(abdulelah, "PERSEVERING", 5, 110);
        log.info("Seed: done, every account uses the same password");
    }

    // the summary of a closed week, its titles are TITLE=groupMemberId separated by ;
    private GroupSettlement settlement(GroupGoal goal, LocalDate weekStart, String text, String titles) {
        GroupSettlement settlement = new GroupSettlement();
        settlement.setWeekStart(weekStart);
        settlement.setSettlementText(text);
        settlement.setTitles(titles);
        settlement.setCreatedAt(weekStart.plusDays(7).atTime(0, 5));
        settlement.setGroupGoal(goal);
        return groupSettlementRepository.save(settlement);
    }

    // titles(group, "IRON", sara, "ROCKET", noura) -> "IRON=4;ROCKET=1"
    private String titles(Group group, Object... pairs) {
        Map<String, Member> map = new LinkedHashMap<>();
        for (int i = 0; i < pairs.length; i += 2) {
            map.put((String) pairs[i], (Member) pairs[i + 1]);
        }
        StringBuilder text = new StringBuilder();
        map.forEach((title, member) -> text.append(text.length() == 0 ? "" : ";").append(title).append("=")
                .append(groupAccessService.getActiveMembership(group.getId(), member.getId()).getId()));
        return text.toString();
    }

    private void setTitle(Group group, Member member, String title, int points) {
        GroupMember groupMember = groupAccessService.getActiveMembership(group.getId(), member.getId());
        groupMember.setTitle(title);
        groupMember.setPoints(points);
        groupMemberRepository.save(groupMember);
    }

    private void level(Member member, String level, int weeks, int points) {
        Member saved = memberRepository.findMemberById(member.getId());
        saved.setLevel(level);
        saved.setConsecutiveWeeks(weeks);
        saved.setPoints(points);
        memberRepository.save(saved);
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
