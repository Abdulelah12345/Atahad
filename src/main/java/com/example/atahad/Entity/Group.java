package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.Set;

@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
@Table(name = "atahad_groups") // "groups" is a reserved word in MySQL 8
public class Group {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotEmpty(message = "Group name cannot be empty")
    @Size(max = 100, message = "Group name must be 100 characters max")
    @Column(columnDefinition = "VARCHAR(100) NOT NULL")
    private String name;

    @Size(max = 255, message = "Description must be 255 characters max")
    @Column(columnDefinition = "VARCHAR(255)")
    private String description;

    @Column(columnDefinition = "VARCHAR(20) UNIQUE")
    private String inviteCode; // also used inside the QR code

    @Column(columnDefinition = "VARCHAR(500)")
    private String qrCodeUrl;


    @Min(value = 0, message = "Points must be zero or more")
    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer points = 0;

    @Min(value = 1, message = "Points for a grace day must be at least 1")
    @Column(columnDefinition = "INTEGER DEFAULT 300")
    private Integer pointsForGraceDay = 300; // every member gets a grace day when the group reaches it

    @Pattern(regexp = "^(ACTIVE|ARCHIVED)$", message = "Status must be ACTIVE or ARCHIVED")
    @Column(columnDefinition = "VARCHAR(8)")
    private String status = "ACTIVE";

    // who donates when someone misses, chosen when the group is made and never changes:
    // SOLO = only the one who missed, ALL = everyone (null = an old group, its goals decide)
    @Column(columnDefinition = "VARCHAR(4)")
    private String payMode;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime createdAt;

    @OneToMany(mappedBy = "group")
    @JsonIgnore
    private Set<GroupMember> members;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "group")
    @JsonIgnore
    private Set<GroupGoal> goals; // the proposals, one active goal at a time, and the old goals

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "group")
    @JsonIgnore
    private Set<ChatMessage> chatMessages;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "group")
    @JsonIgnore
    private Set<PointLog> pointLogs;

    @OneToMany(mappedBy = "challenger")
    @JsonIgnore
    private Set<GroupMatch> challengesSent;

    @OneToMany(mappedBy = "opponent")
    @JsonIgnore
    private Set<GroupMatch> challengesReceived;
}