package com.example.atahad.Service;

import com.example.atahad.Entity.Member;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.*;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;

// push notifications to the member phone with Firebase Cloud Messaging (free)
// the key file (firebase-key.json) is not in git, without it the push is skipped and the app works normally
@Service
public class PushService {

    @Value("${firebase.credentials-path:firebase-key.json}")
    private String credentialsPath;

    // the sound file name inside the mobile app, "default" = the normal notification sound of the phone
    @Value("${push.alert-sound:default}")
    private String alertSound;

    private boolean ready = false;

    @PostConstruct
    void init(){
        if(!Files.exists(Path.of(credentialsPath))){
            System.out.println("Firebase key not found (" + credentialsPath + "), push notifications are off");
            return;
        }
        try(InputStream key = new FileInputStream(credentialsPath)){
            if(FirebaseApp.getApps().isEmpty()){
                FirebaseApp.initializeApp(FirebaseOptions.builder().setCredentials(GoogleCredentials.fromStream(key)).build());
            }
            ready = true;
            System.out.println("Firebase is ready, push notifications are on");
        }catch(Exception e){
            System.out.println("Firebase could not start: " + e.getMessage());
        }
    }

    // the group alert, with the alert sound
    public void sendAlert(Member member, String title, String body){
        send(member, title, body, alertSound);
    }

    // returns false when it was not sent (no key, no device token, or Firebase refused it)
    public boolean send(Member member, String title, String body, String sound){
        if(!ready || member == null || member.getDeviceToken() == null || member.getDeviceToken().isBlank()){
            return false;
        }
        Message message = Message.builder()
                .setToken(member.getDeviceToken())
                .setNotification(Notification.builder().setTitle(title).setBody(body).build())
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .setNotification(AndroidNotification.builder().setSound(sound).setChannelId("alerts").build())
                        .build())
                .setApnsConfig(ApnsConfig.builder()
                        .setAps(Aps.builder().setSound(sound).build())
                        .build())
                .build();
        try{
            FirebaseMessaging.getInstance().send(message);
            return true;
        }catch(FirebaseMessagingException e){
            // a push problem never stops the alert, it is still saved and shown in the app
            System.out.println("Push failed for member " + member.getId() + ": " + e.getMessage());
            return false;
        }
    }

    // is Firebase on (the key file was read)
    public String check(){
        if(!ready){
            return "Firebase is off: the key file was not found or is not valid";
        }
        return "Firebase is ready";
    }
}
