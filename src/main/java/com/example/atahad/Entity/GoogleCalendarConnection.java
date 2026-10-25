
package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class GoogleCalendarConnection {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @OneToOne
    @JoinColumn(name = "member_id", unique = true, nullable = false)
    @JsonIgnore
    private Member member;

    @Column(columnDefinition = "TEXT")
    @JsonIgnore
    private String encryptedAccessToken;

    @Column(columnDefinition = "TEXT")
    @JsonIgnore
    private String encryptedRefreshToken;

    private LocalDateTime expiresAt;

    private Boolean connected = false;

    private LocalDateTime connectedAt;
}
