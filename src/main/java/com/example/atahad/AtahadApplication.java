package com.example.atahad;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling // the daily check at 00:00 and the weekly close on sunday
public class AtahadApplication {

    public static void main(String[] args) {
        SpringApplication.run(AtahadApplication.class, args);
    }

}
