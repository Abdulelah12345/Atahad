
package com.example.atahad.Service;

import com.example.atahad.Api.ApiException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;

@Service
public class GoogleTokenCryptoService {

    @Value("${google.calendar.encryption-key:}")
    private String encryptionKey;

    private SecretKeySpec getKey() {

        if (encryptionKey == null || encryptionKey.isBlank()) {
            throw new ApiException("Google Calendar encryption key is missing");
        }

        byte[] key = Base64.getDecoder().decode(encryptionKey);

        if (key.length != 32) {
            throw new ApiException("Google Calendar encryption key must be 32 bytes");
        }

        return new SecretKeySpec(key, "AES");
    }

    public String encrypt(String value) {

        try {
            byte[] iv = new byte[12];
            new SecureRandom().nextBytes(iv);

            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, getKey(), new GCMParameterSpec(128, iv));

            byte[] encrypted = cipher.doFinal(value.getBytes(StandardCharsets.UTF_8));

            byte[] result = new byte[iv.length + encrypted.length];
            System.arraycopy(iv, 0, result, 0, iv.length);
            System.arraycopy(encrypted, 0, result, iv.length, encrypted.length);

            return Base64.getEncoder().encodeToString(result);

        } catch (Exception e) {
            throw new ApiException("Failed to encrypt Google token");
        }
    }

    public String decrypt(String value) {

        try {
            byte[] result = Base64.getDecoder().decode(value);

            if (result.length < 29) {
                throw new ApiException("Invalid encrypted token");
            }

            byte[] iv = new byte[12];
            byte[] encrypted = new byte[result.length - 12];

            System.arraycopy(result, 0, iv, 0, 12);
            System.arraycopy(result, 12, encrypted, 0, encrypted.length);

            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, getKey(), new GCMParameterSpec(128, iv));

            return new String(cipher.doFinal(encrypted), StandardCharsets.UTF_8);

        } catch (Exception e) {
            throw new ApiException("Failed to decrypt Google token");
        }
    }
}
