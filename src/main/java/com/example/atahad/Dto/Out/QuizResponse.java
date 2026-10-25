package com.example.atahad.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

// the quiz without the answers: the proof is "quizId:answers", like 12:BCA
@Data
@AllArgsConstructor
@NoArgsConstructor
public class QuizResponse {
    private Integer quizId;
    private String topic;
    private List<QuizQuestionResponse> questions;
    private String howToAnswer;
    private java.time.LocalDateTime expiresAt;

    public QuizResponse(Integer quizId, String topic, List<QuizQuestionResponse> questions, String howToAnswer) {
        this(quizId, topic, questions, howToAnswer, null);
    }
}
