package com.example.atahad.Service;

import com.example.atahad.Entity.User;
import com.example.atahad.Repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class MyUserDetailsService implements UserDetailsService {
    private final UserRepository userRepository;

    // Spring يسمي المدخل username، لكن قيمة تسجيل الدخول في مشروعنا هي البريد.
    // نرجع كلاس User نفسه حتى يعمل @AuthenticationPrincipal User في الكنترولر.
    @Override
    @Transactional(readOnly = true)
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        User user = userRepository.findUserByEmail(username);
        if (user == null) {
            throw new UsernameNotFoundException("Invalid email or password");
        }
        return user;
    }
}
