package com.example.atahad.Entity;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import com.fasterxml.jackson.annotation.JsonIgnore;

@Entity @Getter @Setter @NoArgsConstructor
public class ProofCapture {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Integer id;
    @Column(nullable=false) private Integer memberId;
    private Integer proofId;
    @Column(length=8,nullable=false) private String kind;
    @JsonIgnore private String token;
    private LocalDateTime expiresAt;
    private LocalDateTime capturedAt;
    private LocalDateTime usedAt;
    @Column(length=64) private String fingerprint;
    @JsonIgnore @Column(columnDefinition="MEDIUMTEXT") private String imageData;
}
