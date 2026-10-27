package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Entity.Commitment;
import com.example.atahad.Entity.ProofMethodOption;
import com.example.atahad.Repository.ProofMethodOptionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

// the admin turns proof methods on and off
@Service
@RequiredArgsConstructor
public class ProofMethodService {

    private final ProofMethodOptionRepository optionRepository;

    private static final Map<String, String> METHODS = new LinkedHashMap<>();
    static {
        METHODS.put("PHOTO", "صورة");
        METHODS.put("TIMER", "مؤقت");
        METHODS.put("QUIZ", "كويز");
        METHODS.put("LOCATION", "موقع");
        METHODS.put("STEPS", "خطوات");
    }

    // the first call makes the five rows
    @Transactional
    public void ensureRows() {
        for (Map.Entry<String, String> method : METHODS.entrySet()) {
            if (optionRepository.findProofMethodOptionByCode(method.getKey()) == null) {
                optionRepository.save(new ProofMethodOption(null, method.getKey(), method.getValue(), true));
            }
        }
    }

    public List<ProofMethodOption> getAll() {
        ensureRows();
        return optionRepository.findAll().stream().filter(o -> METHODS.containsKey(o.getCode())).toList();
    }

    public List<ProofMethodOption> getActive() {
        ensureRows();
        return optionRepository.findProofMethodOptionsByEnabledTrue().stream().filter(o -> METHODS.containsKey(o.getCode())).toList();
    }

    // on <-> off, commitments that already use it keep working
    public ProofMethodOption toggle(Integer id) {
        ProofMethodOption option = optionRepository.findProofMethodOptionById(id);
        if (option == null) {
            throw new ApiException("Proof method not found");
        }
        if (Boolean.TRUE.equals(option.getEnabled()) && "PHOTO".equals(option.getCode())) {
            throw new ApiException("Photo is the default method and stays on");
        }
        option.setEnabled(!Boolean.TRUE.equals(option.getEnabled()));
        return optionRepository.save(option);
    }

    // before a new habit or goal is saved: its method must be on
    public void apply(Commitment commitment) {
        ensureRows();
        ProofMethodOption option = optionRepository.findProofMethodOptionByCode(commitment.getProofMethod());
        if (option != null && !Boolean.TRUE.equals(option.getEnabled())) {
            throw new ApiException("This proof method is turned off");
        }
    }
}
