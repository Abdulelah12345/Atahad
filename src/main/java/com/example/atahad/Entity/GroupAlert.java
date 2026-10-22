package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Set;

// The loud alert a member sends to a late member, the AI writes the text
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class GroupAlert {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Size(max = 500, message = "Message must be 500 characters max")
    @Column(columnDefinition = "VARCHAR(500)")
    private String message;

    @Column(columnDefinition = "BOOLEAN DEFAULT false")
    private Boolean isCollective = false; // two or more alerts on the same day

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime sentAt;

    //Relations
    @ManyToOne
    @JoinColumn(name = "sender_id")
    @JsonIgnore
    private GroupMember sender;

    @ManyToOne
    @JoinColumn(name = "receiver_id")
    @JsonIgnore
    private GroupMember receiver;
}
