
package com.example.atahad.Entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;

@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class LuckyChallenge {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(columnDefinition = "varchar(100) not null")
    private String title;

    @Column(columnDefinition = "int not null")
    private Integer attempts;

    @Column(columnDefinition = "date not null")
    private LocalDate challengeDate;

    @Column(columnDefinition = "varchar(20) not null")
    private String status;

    @Lob
    @Column(columnDefinition = "LONGTEXT")
    private String proofUrl;

    @Column(columnDefinition = "int not null")
    private Integer points = 20;

    @Column(columnDefinition = "varchar(10)")
    private String difficulty;

    @ManyToOne
    @JoinColumn(name = "member_id")
    private Member member;
}
