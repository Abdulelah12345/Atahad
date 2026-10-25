package com.example.atahad.Repository;

import com.example.atahad.Entity.GoogleCalendarOAuthState;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface GoogleCalendarOAuthStateRepository extends JpaRepository<GoogleCalendarOAuthState, String> {

}