package com.example.atahad.Entity;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import com.fasterxml.jackson.annotation.JsonIgnore;

@Entity @Getter @Setter @NoArgsConstructor
public class TimerSession {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Integer id;
    @OneToOne(optional=false) @JoinColumn(unique=true) @JsonIgnore private Proof proof;
    private int requiredSeconds;
    private long elapsedSeconds;
    private int extensionSeconds;
    private LocalDateTime lastStartedAt;
    private LocalDateTime deadline;
    private LocalDateTime requiredReachedAt;
    @Column(length=10) private String status = "RUNNING";
    @Column(length=10) private String feedback;
    @Column(length=1200) private String messages;
}
