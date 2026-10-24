package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.Out.QuizQuestionResponse;
import com.example.atahad.Dto.Out.QuizResponse;
import com.example.atahad.Entity.*;
import com.example.atahad.Repository.CommitmentWeekRepository;
import com.example.atahad.Repository.GoalTaskRepository;
import com.example.atahad.Repository.QuizRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

// QUIZ proof: the AI writes 3 questions about what the member studied, he answers them,
// and the proof is accepted with 2 right answers or more
@Service
@RequiredArgsConstructor
public class QuizService {
    private final QuizRepository quizRepository;
    private final CommitmentWeekRepository commitmentWeekRepository;
    private final GoalTaskRepository goalTaskRepository;
    private final AiService aiService;

    public static final int QUESTIONS = 3;
    public static final int TO_PASS = 2;
    public static final int VALID_HOURS = 2; // the quiz must be answered within 2 hours

    // topic = what he studied today (optional), else the title of the task
    public QuizResponse create(Integer memberId, Integer weekId, Integer goalTaskId, String topic){
        CommitmentWeek week = commitmentWeekRepository.findCommitmentWeekById(weekId);
        if(week == null || !week.getCommitment().getMember().getId().equals(memberId)){
            throw new ApiException("Week not found");
        }
        LocalDate today = LocalDate.now();
        if(today.isAfter(week.getWeekEnd().toLocalDate()) || today.isBefore(week.getWeekStart().toLocalDate())){
            throw new ApiException("This week is not running");
        }
        GoalTask task = null;
        String method = week.getCommitment().getProofMethod();
        String title = week.getCommitment().getTitle();
        if(goalTaskId != null){
            task = goalTaskRepository.findGoalTaskById(goalTaskId);
            if(task == null || !task.getGoal().getId().equals(week.getCommitment().getId()) || !task.getWeekNumber().equals(week.getWeekNumber())){
                throw new ApiException("This task is not in this week");
            }
            method = task.getProofMethod();
            title = title + " - " + task.getTitle();
        }
        if(!"QUIZ".equals(method)){
            throw new ApiException("This commitment is not proved with a quiz");
        }
        String subject = topic == null || topic.isBlank() ? title : topic.trim();
        if(subject.length() > 200){
            subject = subject.substring(0, 200);
        }

        String answer = aiService.ask(
                "You write short quizzes that check if a person really studied a topic today. "
                        + "Write exactly " + QUESTIONS + " multiple choice questions in Arabic, each with 3 options and one right answer, "
                        + "not too easy and not tricky. Use exactly this format for every question:\n"
                        + "Q: the question\nA) option\nB) option\nC) option\nANSWER: the letter",
                "Topic: " + subject + "\nCommitment: " + title,
                "");
        List<QuizQuestionResponse> questions = new ArrayList<>();
        StringBuilder correct = new StringBuilder();
        Matcher matcher = Pattern.compile("Q:\\s*(.+?)\\s*\\n\\s*A\\)\\s*(.+?)\\s*\\n\\s*B\\)\\s*(.+?)\\s*\\n\\s*C\\)\\s*(.+?)\\s*\\n\\s*ANSWER:\\s*([ABCabc])")
                .matcher(answer.replace("*", ""));
        while(matcher.find() && questions.size() < QUESTIONS){
            questions.add(new QuizQuestionResponse(questions.size() + 1, matcher.group(1),
                    List.of("A) " + matcher.group(2), "B) " + matcher.group(3), "C) " + matcher.group(4))));
            correct.append(matcher.group(5).toUpperCase());
        }
        if(questions.size() < QUESTIONS){
            throw new ApiException("The quiz is not available now, try again in a minute");
        }

        StringBuilder text = new StringBuilder();
        for(QuizQuestionResponse q : questions){
            text.append(q.getNumber()).append(". ").append(q.getQuestion()).append("\n");
            for(String option : q.getOptions()){
                text.append("   ").append(option).append("\n");
            }
        }
        Quiz quiz = new Quiz();
        quiz.setTopic(subject);
        quiz.setQuestions(text.length() > 3000 ? text.substring(0, 3000) : text.toString());
        quiz.setCorrectAnswers(correct.toString());
        quiz.setCreatedAt(LocalDateTime.now());
        quiz.setMember(week.getCommitment().getMember());
        quiz.setCommitmentWeek(week);
        quiz.setGoalTask(task);
        quizRepository.save(quiz);

        return new QuizResponse(quiz.getId(), subject, questions,
                "Send a QUIZ proof with evidenceData = \"" + quiz.getId() + ":\" + your letters in order, like " + quiz.getId() + ":BCA");
    }

    // evidence "12:BCA" -> null when it passed, else the reason it failed
    public String grade(Proof proof){
        Matcher matcher = Pattern.compile("(\\d+)\\s*[:|]\\s*([A-Ca-c]+)").matcher(proof.getEvidenceData() == null ? "" : proof.getEvidenceData());
        if(!matcher.find()){
            return "صيغة الإجابة غلط، المفروض مثل 12:BCA";
        }
        Quiz quiz = quizRepository.findQuizById(Integer.valueOf(matcher.group(1)));
        if(quiz == null || !quiz.getCommitmentWeek().getId().equals(proof.getCommitmentWeek().getId())){
            return "الاختبار مو لهالأسبوع";
        }
        boolean sameTask = quiz.getGoalTask() == null ? proof.getGoalTask() == null
                : proof.getGoalTask() != null && quiz.getGoalTask().getId().equals(proof.getGoalTask().getId());
        if(!sameTask){
            return "الاختبار مو لهالمهمة";
        }
        if(quiz.getUsedAt() != null){
            return "الاختبار مستخدم قبل، اطلب اختبار جديد";
        }
        if(quiz.getCreatedAt().plusHours(VALID_HOURS).isBefore(LocalDateTime.now())){
            return "انتهى وقت الاختبار (" + VALID_HOURS + " ساعات)، اطلب اختبار جديد";
        }
        quiz.setUsedAt(LocalDateTime.now());
        quizRepository.save(quiz);

        String answers = matcher.group(2).toUpperCase();
        int right = 0;
        for(int i = 0; i < quiz.getCorrectAnswers().length() && i < answers.length(); i++){
            if(answers.charAt(i) == quiz.getCorrectAnswers().charAt(i)){
                right++;
            }
        }
        return right >= TO_PASS ? null : "جاوبت " + right + " من " + QUESTIONS + "، لازم " + TO_PASS + " على الأقل";
    }
}
