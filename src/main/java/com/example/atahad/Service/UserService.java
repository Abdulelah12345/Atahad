package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.User;
import com.example.atahad.Repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;

    public List<User> getAllUsers() {
        return userRepository.findAll();
    }

    public User getUserById(Integer id) {
        User user = userRepository.findUserById(id);

        if (user == null) {
            throw new ApiException("User not found");
        }

        return user;
    }

    public void updateUser(Integer id, User updatedUser) {
        User user = userRepository.findUserById(id);

        if (user == null) {
            throw new ApiException("User not found");
        }

        User existingEmail = userRepository.findUserByEmail(updatedUser.getEmail());

        if (existingEmail != null && !existingEmail.getId().equals(id)) {
            throw new ApiException("Email already exists");
        }

        user.setName(updatedUser.getName());
        user.setEmail(updatedUser.getEmail());
        user.setPhone(updatedUser.getPhone());

        userRepository.save(user);
    }

    public void deleteUser(Integer id) {
        User user = userRepository.findUserById(id);

        if (user == null) {
            throw new ApiException("User not found");
        }

        userRepository.delete(user);
    }
}