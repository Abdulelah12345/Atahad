package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.AdminRegisterRequest;
import com.example.atahad.Dto.In.AdminUpdateRequest;
import com.example.atahad.Dto.Out.AdminResponse;
import com.example.atahad.Entity.Admin;
import com.example.atahad.Entity.User;
import com.example.atahad.Repository.AdminRepository;
import com.example.atahad.Repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class AdminService {

    private final AdminRepository adminRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public void registerAdmin(AdminRegisterRequest dto) {

        User existingUser = userRepository.findUserByEmail(dto.getEmail());

        if (existingUser != null) {
            throw new ApiException("Email already exists");
        }

        User user = new User();
        user.setName(dto.getName());
        user.setEmail(dto.getEmail());
        user.setPhone(dto.getPhone());
        user.setRole("ADMIN");
        user.setCreatedAt(LocalDateTime.now());
        // نخزن BCrypt فقط؛ لا نخزن كلمة المرور الأصلية.
        user.setPassword(passwordEncoder.encode(dto.getPassword()));

        userRepository.save(user);

        Admin admin = new Admin();
        admin.setUser(user);
        admin.setJobTitle(dto.getJobTitle());
        admin.setReviewedCount(0);

        adminRepository.save(admin);
    }

    public List<AdminResponse> getAllAdmins() {

        List<Admin> admins = adminRepository.findAll();
        List<AdminResponse> adminResponses = new ArrayList<>();

        for (Admin admin : admins) {
            adminResponses.add(convertToDTO(admin));
        }

        return adminResponses;
    }

    public AdminResponse getAdminById(Integer id) {

        Admin admin = adminRepository.findAdminById(id);

        if (admin == null) {
            throw new ApiException("Admin not found");
        }

        return convertToDTO(admin);
    }

    @Transactional
    public void updateAdmin(Integer id, AdminUpdateRequest dto) {

        Admin admin = adminRepository.findAdminById(id);

        if (admin == null) {
            throw new ApiException("Admin not found");
        }

        User user = admin.getUser();

        User existingUser = userRepository.findUserByEmail(dto.getEmail());

        if (existingUser != null && !existingUser.getId().equals(user.getId())) {
            throw new ApiException("Email already exists");
        }

        user.setName(dto.getName());
        user.setEmail(dto.getEmail());
        user.setPhone(dto.getPhone());

        admin.setJobTitle(dto.getJobTitle());

        userRepository.save(user);
        adminRepository.save(admin);
    }

    public AdminResponse convertToDTO(Admin admin) {

        User user = admin.getUser();

        return new AdminResponse(
                admin.getId(),
                user.getName(),
                user.getEmail(),
                user.getPhone(),
                admin.getJobTitle(),
                admin.getLastLoginAt(),
                admin.getReviewedCount(),
                user.getCreatedAt()
        );
    }
}