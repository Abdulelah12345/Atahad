package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.time.LocalDateTime;

@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class GroupMember {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime joinedAt;

    @Min(value = 0, message = "Points must be zero or more")
    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer points = 0;

    @Pattern(regexp = "^(OWNER|MEMBER)$")
    @Column(columnDefinition = "VARCHAR(6)")
    private String role = "MEMBER";

    @Min(value = 0, message = "Failure count must be zero or more")
    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer failureCount = 0; // second failure in the group = kicked

    @Pattern(regexp = "^(ACTIVE|KICKED|LEFT)$", message = "Status must be ACTIVE, KICKED or LEFT")
    @Column(columnDefinition = "VARCHAR(6)")
    private String status = "ACTIVE";

    @ManyToOne
    @JoinColumn(name = "group_id")
    @JsonIgnore
    private Group group;

    @ManyToOne
    @JoinColumn(name = "member_id")
    @JsonIgnore
    private Member member;
}