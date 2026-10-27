package com.example.atahad.Service;

import com.example.atahad.Entity.User;
import com.example.atahad.Repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.AuthenticationCredentialsNotFoundException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AuthenticatedUserService {
    private final UserRepository userRepository;

    // the id in the path must be the logged in member
    public void checkMember(Integer memberId) {
        User user = getCurrentUser();
        if (user.getRole() == null) {
            throw new AccessDeniedException("Member access is required");
        }
        boolean isMember = user.getRole().equals("MEMBER");
        if (!isMember) {
            throw new AccessDeniedException("Member access is required");
        }
        if (user.getMember() == null) {
            throw new AccessDeniedException("Member profile is required");
        }
        if (!user.getMember().getId().equals(memberId)) {
            throw new AccessDeniedException("You can only access your own member data");
        }
    }

    // the deciding admin is the logged in one
    public void checkAdmin(Integer adminId) {
        User user = getCurrentUser();
        if (user.getRole() == null) {
            throw new AccessDeniedException("Admin access is required");
        }
        boolean isAdmin = user.getRole().equals("ADMIN");
        if (!isAdmin) {
            throw new AccessDeniedException("Admin access is required");
        }
        if (user.getAdmin() == null) {
            throw new AccessDeniedException("Admin profile is required");
        }
        if (!user.getAdmin().getId().equals(adminId)) {
            throw new AccessDeniedException("Use your own admin identity");
        }
    }

    private User getCurrentUser() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null) {
            throw new AuthenticationCredentialsNotFoundException("Login is required");
        }
        if (!authentication.isAuthenticated()) {
            throw new AuthenticationCredentialsNotFoundException("Login is required");
        }
        User user = userRepository.findUserByEmail(authentication.getName());
        if (user == null) {
            throw new AuthenticationCredentialsNotFoundException("Login is required");
        }
        return user;
    }
}
