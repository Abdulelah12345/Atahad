package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.*;
import java.time.*;

@Entity @Getter @Setter @NoArgsConstructor
@Table(uniqueConstraints=@UniqueConstraint(name="uk_steps_member_day",columnNames={"member_id","activity_day"}))
public class DailySteps {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Integer id;
    @ManyToOne(optional=false) @JoinColumn(name="member_id") @JsonIgnore
    @org.hibernate.annotations.OnDelete(action=org.hibernate.annotations.OnDeleteAction.CASCADE)
    private Member member;
    @Column(name="activity_day",nullable=false) private LocalDate day;
    @Column(nullable=false) private Integer total;
    @Column(nullable=false,length=20) private String source;
    @JsonIgnore @Column(nullable=false,length=100) private String deviceId;
    @Column(nullable=false,length=40) private String zoneId;
    private LocalDateTime observedAt;
    private LocalDateTime syncedAt;
}
