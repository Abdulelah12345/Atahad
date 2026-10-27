package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

/** A device-reported connectivity check, not server attestation of sensor data. */
@Entity @Getter @Setter @NoArgsConstructor
public class StepConnection {
    @Id private Integer memberId;
    @OneToOne @MapsId @JsonIgnore
    @org.hibernate.annotations.OnDelete(action=org.hibernate.annotations.OnDeleteAction.CASCADE)
    private Member member;
    @Column(nullable=false, length=20) private String source;
    @JsonIgnore @Column(nullable=false, length=100) private String deviceId;
    @Column(nullable=false, length=20) private String status;
    private LocalDateTime checkedAt;
    private LocalDateTime lastSuccessfulReadAt;
}
