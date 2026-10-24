package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Set;

@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class ChatMessage {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Pattern(regexp = "^(TEXT|SYSTEM|ALERT|COLLECTIVE)$", message = "Type must be TEXT, SYSTEM, ALERT or COLLECTIVE")
    @Column(columnDefinition = "VARCHAR(10)")
    private String type = "TEXT"; // SYSTEM: app messages like a new settlement, ALERT: the siren to one friend (COLLECTIVE when 2 or more alerted him the same day)

    @NotEmpty(message = "Message cannot be empty")
    @Size(max = 1000, message = "Message must be 1000 characters max")
    @Column(columnDefinition = "VARCHAR(1000) NOT NULL")
    private String content;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime sentAt;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Group group;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private GroupMember sender; // Null for SYSTEM messages

    @ManyToOne
    @JoinColumn(name = "receiver_id")
    @JsonIgnore
    private GroupMember receiver; // alerts only, they are not shown in the group chat
}
