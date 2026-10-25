
package com.example.atahad.Repository;

import com.example.atahad.Entity.GoogleCalendarConnection;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface GoogleCalendarConnectionRepository extends JpaRepository<GoogleCalendarConnection, Integer> {

    GoogleCalendarConnection findGoogleCalendarConnectionByMemberId(Integer memberId);
}
