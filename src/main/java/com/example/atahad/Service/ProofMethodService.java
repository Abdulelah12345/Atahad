package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import com.example.atahad.Dto.In.ProofMethodRequest;
import com.example.atahad.Entity.Commitment;
import com.example.atahad.Entity.ProofMethodOption;
import com.example.atahad.Repository.ProofMethodOptionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

// the proof methods members can pick, managed by the admin
@Service
@RequiredArgsConstructor
public class ProofMethodService {

    private final ProofMethodOptionRepository optionRepository;

    private static final Map<String, String> BUILT_IN = new LinkedHashMap<>();
    static {
        BUILT_IN.put("PHOTO", "صورة");
        BUILT_IN.put("TIMER", "مؤقت");
        BUILT_IN.put("QUIZ", "كويز");
        BUILT_IN.put("LOCATION", "موقع");
        BUILT_IN.put("STEPS", "خطوات");
    }

    // first call makes the five built-in rows
    @Transactional
    public void ensureBuiltIns() {
        for (Map.Entry<String, String> method : BUILT_IN.entrySet()) {
            if (optionRepository.findProofMethodOptionByCode(method.getKey()) == null) {
                optionRepository.save(new ProofMethodOption(null, method.getKey(), method.getValue(), null, true, true));
            }
        }
    }

    public List<ProofMethodOption> getAll() {
        ensureBuiltIns();
        return optionRepository.findAll();
    }

    public List<ProofMethodOption> getActive() {
        ensureBuiltIns();
        return optionRepository.findProofMethodOptionsByEnabledTrue();
    }

    @Transactional
    public ProofMethodOption add(ProofMethodRequest dto) {
        ProofMethodOption option = new ProofMethodOption(null, "CUSTOM_NEW", dto.getNameAr().trim(), dto.getHint().trim(), false, true);
        optionRepository.save(option);
        option.setCode("CUSTOM_" + option.getId());
        return optionRepository.save(option);
    }

    // on <-> off. Commitments that already use it keep working, only new ones can't pick it
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

    // called before a new habit or goal is saved
    // a custom option turns into a PHOTO proof that carries the admin's rule
    public void apply(Commitment commitment) {
        ensureBuiltIns();
        Integer optionId = commitment.getProofOptionId();
        if (optionId != null) {
            ProofMethodOption option = optionRepository.findProofMethodOptionById(optionId);
            if (option == null || Boolean.TRUE.equals(option.getBuiltIn())) {
                throw new ApiException("Proof method not found");
            }
            if (!Boolean.TRUE.equals(option.getEnabled())) {
                throw new ApiException("This proof method is turned off");
            }
            commitment.setProofMethod("PHOTO");
            commitment.setProofLabel(option.getNameAr());
            commitment.setProofHint(option.getHint());
            return;
        }
        ProofMethodOption option = optionRepository.findProofMethodOptionByCode(commitment.getProofMethod());
        if (option != null && !Boolean.TRUE.equals(option.getEnabled())) {
            throw new ApiException("This proof method is turned off");
        }
    }
}
