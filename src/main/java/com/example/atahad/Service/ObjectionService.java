package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.Objection;
import com.example.atahad.Repository.ObjectionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ObjectionService {

    private final ObjectionRepository objectionRepository;

    public List<Objection> getAllObjections() {
        return objectionRepository.findAll();
    }

    public Objection getObjectionById(Integer id) {
        Objection objection = objectionRepository.findObjectionById(id);

        if (objection == null) {
            throw new ApiException("Objection not found");
        }

        return objection;
    }
}