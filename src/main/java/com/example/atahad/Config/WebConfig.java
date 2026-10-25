package com.example.atahad.Config;

import com.example.atahad.Service.MomentService;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
@RequiredArgsConstructor
public class WebConfig implements WebMvcConfigurer {
    private final LockInterceptor lockInterceptor;

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(lockInterceptor).addPathPatterns("/api/v1/**");
    }

    // the uploaded photos and videos of the moments: /uploads/moments/<name>
    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        String folder = MomentService.UPLOADS.getParent().toAbsolutePath().toUri().toString();
        registry.addResourceHandler("/uploads/**").addResourceLocations(folder);
    }
}
