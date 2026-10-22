package com.example.atahad.Entity;

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
@Table(name = "groups")
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
    private String inviteCode;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime createdAt;

    @OneToMany(mappedBy = "group")
    private Set<GroupMember> members;
}