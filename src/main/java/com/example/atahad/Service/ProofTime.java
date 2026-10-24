package com.example.atahad.Service;
import org.springframework.stereotype.Component;
import java.time.*;
@Component
public class ProofTime {
    private Clock clock = Clock.system(ZoneId.of("Asia/Riyadh"));
    public LocalDateTime now() { return LocalDateTime.now(clock); }
}
