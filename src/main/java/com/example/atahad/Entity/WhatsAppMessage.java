package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

// a WhatsApp message waiting in the queue, n8n reads the PENDING ones and sends them with UltraMsg
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class WhatsAppMessage {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotEmpty(message = "Phone cannot be empty")
    @Column(columnDefinition = "VARCHAR(16) NOT NULL")
    private String phone;

    @NotEmpty(message = "Message cannot be empty")
    @Size(max = 2000, message = "Message must be 2000 characters max")
    @Column(columnDefinition = "VARCHAR(2000) NOT NULL")
    private String body;

    @Pattern(regexp = "^(REMINDER|LOCK|UNLOCK|SETTLEMENT)$", message = "Type must be REMINDER, LOCK, UNLOCK or SETTLEMENT")
    @Column(columnDefinition = "VARCHAR(10)")
    private String type;

    @Pattern(regexp = "^(PENDING|SENT|FAILED)$", message = "Status must be PENDING, SENT or FAILED")
    @Column(columnDefinition = "VARCHAR(7)")
    private String status = "PENDING";

    @Column(columnDefinition = "VARCHAR(255)")
    private String error; // why UltraMsg failed

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime createdAt;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime sentAt;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Member member;
}
