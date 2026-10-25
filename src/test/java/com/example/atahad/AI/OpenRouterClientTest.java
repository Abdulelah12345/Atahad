package com.example.atahad.AI;

import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;
import static org.junit.jupiter.api.Assertions.*;

class OpenRouterClientTest {
    OpenRouterClient client(String url) {
        var client=new OpenRouterClient();ReflectionTestUtils.setField(client,"apiKey","test-local-key");ReflectionTestUtils.setField(client,"url",url);
        ReflectionTestUtils.setField(client,"textModel","test/model:free");ReflectionTestUtils.setField(client,"visionModel","test/vision:free");return client;
    }
    @Test void sendsOneCompatibleRequestWithTextAndImages() throws Exception {
        var server=HttpServer.create(new InetSocketAddress("127.0.0.1",0),0);var request=new AtomicReference<String>();
        server.createContext("/chat",exchange->{
            request.set(new String(exchange.getRequestBody().readAllBytes(),StandardCharsets.UTF_8));
            byte[] response="{\"choices\":[{\"message\":{\"content\":\"ACCEPTED\"}}]}".getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type","application/json");exchange.sendResponseHeaders(200,response.length);exchange.getResponseBody().write(response);exchange.close();
        });server.start();
        try {
            var client=client("http://127.0.0.1:"+server.getAddress().getPort()+"/chat");
            assertEquals("ACCEPTED",client.complete("vision","check","task",List.of("data:image/png;base64,dGVzdA=="),"fallback"));
            assertTrue(request.get().contains("test/vision:free"));assertTrue(request.get().contains("image_url"));
        } finally { server.stop(0); }
    }
    @Test void paidModelAndMissingKeyNeverMakeARequest() {
        var client=client("http://127.0.0.1:1/chat");ReflectionTestUtils.setField(client,"textModel","paid/model");
        assertEquals("fallback",client.complete("text","check","task",List.of(),"fallback"));
        ReflectionTestUtils.setField(client,"apiKey","");assertEquals("fallback",client.complete("vision","check","task",List.of(),"fallback"));
    }
    @Test void unavailableProviderUsesFallbackWithoutAutoAccepting() {
        var client=client("http://127.0.0.1:1/chat");
        assertEquals("ESCALATED",client.complete("text","check","task",List.of(),"ESCALATED"));
    }
}
