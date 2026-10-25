package com.example.atahad.Entity;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import com.fasterxml.jackson.annotation.JsonIgnore;

@Entity @Getter @Setter @NoArgsConstructor
public class ProofEvidence {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Integer id;
    @ManyToOne(optional=false, fetch=FetchType.LAZY) @JsonIgnore private Proof proof;
    @Column(length=20, nullable=false) private String type;
    @Column(length=10, nullable=false) private String result = "PENDING";
    @Column(length=1000) private String reason;
    @JsonIgnore @Column(columnDefinition="MEDIUMTEXT") private String data;
    private Integer beforeCaptureId;
    private Integer afterCaptureId;
    private LocalDateTime createdAt;
    private LocalDateTime decidedAt;
}
