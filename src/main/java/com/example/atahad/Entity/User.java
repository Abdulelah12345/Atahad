package com.example.atahad.Entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.Collections;

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

    // تسجيل الدخول بالبريد؛ اسم الميثود مفروض من واجهة UserDetails.
    @Override
    @JsonIgnore
    public String getUsername() {
        return email;
    }

    // نرجع نفس الدور المستخدم في hasAuthority: MEMBER أو ADMIN.
    @Override
    @JsonIgnore
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return Collections.singleton(new SimpleGrantedAuthority(role));
    }

    @Override
    @JsonIgnore
    public boolean isAccountNonExpired() {
        return true;
    }

    /*
     لا نمنع تسجيل الدخول بسبب خصومات غير مدفوعة، حتى يبقى رفع إثبات التبرع متاحًا.
     أما الحساب المعطل فيمنع من الدخول عن طريق isEnabled أدناه.
     قفل الخصومات يقيّد العمليات حسب الفلو، ولا يقفل تسجيل الدخول نفسه.
    */
    @Override
    @JsonIgnore
    public boolean isAccountNonLocked() {
        return true;
    }

    @Override
    @JsonIgnore
    public boolean isCredentialsNonExpired() {
        return true;
    }

    // الحساب المعطل لا يدخل، أما الحساب المحظور فتطبق عليه قيود الفلو بعد الدخول.
    @Override
    @JsonIgnore
    public boolean isEnabled() {
        if (member == null) {
            return true;
        }
        String status = member.getAccountStatus();
        if (status == null) {
            return true;
        }
        return !status.equals("DEACTIVATED");
    }

    //Relations
    @OneToOne(cascade = CascadeType.ALL, mappedBy = "user")
    @PrimaryKeyJoinColumn
    @JsonIgnore
    private Member member;

    @OneToOne(cascade = CascadeType.ALL, mappedBy = "user")
    @PrimaryKeyJoinColumn
    @JsonIgnore
    private Admin admin;
}
