package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.Excuse;
import com.example.atahad.Repository.ExcuseRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ExcuseService {

    private final ExcuseRepository excuseRepository;

    public List<Excuse> getAllExcuses() {
        return excuseRepository.findAll();
    }

    public Excuse getExcuseById(Integer id) {
        Excuse excuse = excuseRepository.findExcuseById(id);

        if (excuse == null) {
            throw new ApiException("Excuse not found");
        }

        return excuse;
    }
}