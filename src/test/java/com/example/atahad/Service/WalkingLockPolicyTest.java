package com.example.atahad.Service;
import com.example.atahad.Entity.Member;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class WalkingLockPolicyTest {
    private final LockService locks=new LockService(null,null,null,null);
    @Test void ordinaryLockDoesNotBlockDelayedWalkingEvidence() {
        Member m=new Member();m.setIsLocked(true);
        assertNull(locks.blockReason(m,"POST","/api/v1/walking/weeks/1/sync"));
        assertNull(locks.blockReason(m,"POST","/api/v1/walking/weeks/1/screenshot"));
        assertNotNull(locks.blockReason(m,"POST","/api/v1/habit/add"));
    }
    @Test void bannedAndDeactivatedMembersKeepTheirRestrictions() {
        Member m=new Member();m.setAccountBanned(true);
        assertNotNull(locks.blockReason(m,"POST","/api/v1/walking/weeks/1/sync"));
        m.setAccountBanned(false);m.setAccountStatus("DEACTIVATED");
        assertNotNull(locks.blockReason(m,"GET","/api/v1/walking/connection"));
    }
}
