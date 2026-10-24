package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;

@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class User implements UserDetails {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotEmpty(message = "Name cannot be empty")
    @Size(max = 50, message = "Name must be 50 characters max")
    @Column(columnDefinition = "VARCHAR(50) NOT NULL")
    private String name;

    @NotEmpty(message = "Email cannot be empty")
    @Size(max = 100, message = "Email must be 100 characters max")
    @Column(columnDefinition = "VARCHAR(100) NOT NULL UNIQUE")
    private String email;

    @NotEmpty(message = "Phone cannot be empty")
    @Pattern(regexp = "^\\+[1-9]\\d{7,14}$", message = "Phone must be in international format, e.g. +966501234567")
    @Column(columnDefinition = "VARCHAR(16) NOT NULL")
    private String phone;

    @NotEmpty(message = "Password cannot be empty")
    @Size(min = 8, message = "Password must be at least 8 characters")
    @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)
    @Column(columnDefinition = "VARCHAR(255) NOT NULL")
    private String password;

    @Pattern(regexp = "^(MEMBER|ADMIN)$", message = "Role must be MEMBER or ADMIN")
    @Column(columnDefinition = "VARCHAR(6)")
    private String role;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime createdAt;

    //Relations
    @OneToOne(cascade = CascadeType.ALL, mappedBy = "user")
    @PrimaryKeyJoinColumn
    private Member member;

    @OneToOne(cascade = CascadeType.ALL, mappedBy = "user")
    @PrimaryKeyJoinColumn
    private Admin admin;

    //Security
    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_" + role));
    }

    @Override
    public String getUsername() {
        return email;
    }

    @Override
    public String getPassword() {
        return password;
    }

    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    @Override
    public boolean isAccountNonLocked() {
        return true;
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    @Override
    public boolean isEnabled() {
        return true;
    }
}