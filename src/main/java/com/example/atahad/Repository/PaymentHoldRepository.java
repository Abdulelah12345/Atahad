package com.example.atahad.Repository;

import com.example.atahad.Entity.PaymentHold;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PaymentHoldRepository extends JpaRepository<PaymentHold, Integer> {
}
