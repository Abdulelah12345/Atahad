package com.example.atahad.Service;

import com.example.atahad.Entity.*;
import com.example.atahad.Repository.ProofRepository;
import org.junit.jupiter.api.Test;
import org.springframework.security.access.AccessDeniedException;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class ProofReadOwnershipTest {
    private final ProofRepository repository = mock(ProofRepository.class);
    private final ProofService service = new ProofService(repository, null, null, null, null, null, null);

    private Proof storedProof() {
        User user = new User();
        user.setId(7);
        Member member = new Member();
        member.setUser(user);
        Habit habit = new Habit();
        habit.setMember(member);
        CommitmentWeek week = new CommitmentWeek();
        week.setCommitment(habit);
        Proof proof = new Proof();
        proof.setCommitmentWeek(week);
        when(repository.findProofById(1)).thenReturn(proof);
        return proof;
    }

    @Test
    void ownerCanReadTheProof() {
        Proof proof = storedProof();
        assertSame(proof, service.getProofById(7, 1));
    }

    @Test
    void anotherMemberCannotReadTheProof() {
        storedProof();
        assertThrows(AccessDeniedException.class, () -> service.getProofById(8, 1));
    }
}
