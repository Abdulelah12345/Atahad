package com.example.atahad.Config;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.PasswordEncoder;
import com.example.atahad.Repository.UserRepository;
import com.example.atahad.Service.MyUserDetailsService;
import com.example.atahad.Entity.Member;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import static org.mockito.Mockito.*;
import org.springframework.test.context.junit.jupiter.SpringJUnitConfig;
import org.springframework.test.context.web.WebAppConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.context.WebApplicationContext;
import org.springframework.web.servlet.config.annotation.EnableWebMvc;

import java.util.stream.Stream;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.setup.MockMvcBuilders.webAppContextSetup;

// Tests the real filter chain without loading the database, application services or external APIs.
@SpringJUnitConfig(classes = {SecurityConfig.class, SecurityConfigTest.TestWebConfig.class})
@WebAppConfiguration
class SecurityConfigTest {
    @Autowired
    private WebApplicationContext context;
    private MockMvc mvc;

    record Route(String method, String path, String authority) {}

    static Stream<Route> restrictedRoutes() {
        return Stream.of(
                new Route("GET", "/api/v1/proof/get-all", "ADMIN"),
                new Route("GET", "/api/v1/proof/get/1", "MEMBER"),
                new Route("GET", "/api/v1/proof/get-my-proofs", "MEMBER"),
                new Route("POST", "/api/v1/proof/add/goal-task/1/week/2", "MEMBER"),
                new Route("PUT", "/api/v1/proof/update/goal-task/1", "MEMBER"),
                new Route("DELETE", "/api/v1/proof/delete/goal-task/1", "MEMBER"),
                new Route("GET", "/api/v1/excuse/get", "ADMIN"),
                new Route("GET", "/api/v1/excuse/get/1", "MEMBER"),
                new Route("POST", "/api/v1/excuse/add/goal-task/1/week/2", "MEMBER"),
                new Route("PUT", "/api/v1/excuse/update/goal-task/1", "MEMBER"),
                new Route("DELETE", "/api/v1/excuse/delete/goal-task/1", "MEMBER"),
                new Route("GET", "/api/v1/objection/get-all", "ADMIN"),
                new Route("GET", "/api/v1/objection/get/1", "MEMBER"),
                new Route("POST", "/api/v1/objection/add/proof/1", "MEMBER"),
                new Route("POST", "/api/v1/objection/add/excuse/1", "MEMBER"),
                new Route("PUT", "/api/v1/objection/update/1", "MEMBER"),
                new Route("DELETE", "/api/v1/objection/delete/1", "MEMBER"),
                new Route("POST", "/api/v1/proof/habit/1/2", "MEMBER"),
                new Route("POST", "/api/v1/excuse/habit/1/2", "MEMBER"),
                new Route("POST", "/api/v1/donation-proof/screenshot/1", "MEMBER"),
                new Route("POST", "/api/v1/donation-proof/email/1", "MEMBER"),
                new Route("GET", "/api/v1/donation-proof/gmail/connect/1", "MEMBER"),
                new Route("GET", "/api/v1/donation-proof/my/1", "MEMBER"),
                new Route("POST", "/api/v1/donation-proof/objection/1/2", "MEMBER"),
                new Route("GET", "/api/v1/penalty/my/1", "MEMBER"),
                new Route("GET", "/api/v1/penalty/get/1", "ADMIN"),
                new Route("PUT", "/api/v1/penalty/cancel/1/2", "ADMIN"),
                new Route("GET", "/api/v1/admin-review/queue/1", "ADMIN"),
                new Route("PUT", "/api/v1/admin-review/decide/1/PROOF/2/true", "ADMIN")
        );
    }

    @BeforeEach
    void setup() {
        mvc = webAppContextSetup(context).apply(springSecurity()).build();
    }

    @ParameterizedTest
    @MethodSource("restrictedRoutes")
    void anonymousCannotUseRestrictedRoute(Route route) throws Exception {
        mvc.perform(request(HttpMethod.valueOf(route.method()), route.path()))
                .andExpect(status().isUnauthorized());
    }

    @ParameterizedTest
    @MethodSource("restrictedRoutes")
    void correctAuthorityCanReachRoute(Route route) throws Exception {
        mvc.perform(request(HttpMethod.valueOf(route.method()), route.path())
                        .with(user("test-user").authorities(new SimpleGrantedAuthority(route.authority()))))
                .andExpect(status().isOk());
    }

    @ParameterizedTest
    @MethodSource("restrictedRoutes")
    void otherAuthorityCannotUseRoute(Route route) throws Exception {
        String other = route.authority().equals("ADMIN") ? "MEMBER" : "ADMIN";
        mvc.perform(request(HttpMethod.valueOf(route.method()), route.path())
                        .with(user("test-user").authorities(new SimpleGrantedAuthority(other))))
                .andExpect(status().isForbidden());
    }

    @Test
    void googleCallbackIsReachableWithoutLogin() throws Exception {
        mvc.perform(get("/api/v1/donation-proof/gmail/callback"))
                .andExpect(status().isOk());
    }

    @Test
    void callbackExceptionDoesNotOpenOtherDonationRoutes() throws Exception {
        mvc.perform(get("/api/v1/donation-proof/gmail/connect/1"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void unknownMethodCannotBypassClassification() throws Exception {
        mvc.perform(post("/api/v1/proof/get-all").with(user("member").authorities(new SimpleGrantedAuthority("MEMBER"))))
                .andExpect(status().isForbidden());
    }

    @Test
    void unclassifiedRouteInsideReviewedControllerIsDenied() throws Exception {
        mvc.perform(get("/api/v1/admin-review/new-route").with(user("admin").authorities(new SimpleGrantedAuthority("ADMIN"))))
                .andExpect(status().isForbidden());
    }

    @Test
    void remainingProjectRequiresLogin() throws Exception {
        mvc.perform(get("/api/v1/other"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void basicAuthenticationUsesEncodedPasswordAndAuthority() throws Exception {
        mvc.perform(get("/api/v1/proof/get-my-proofs").with(httpBasic("member@example.test", "test-password")))
                .andExpect(status().isOk());
        mvc.perform(get("/api/v1/proof/get-all").with(httpBasic("member@example.test", "test-password")))
                .andExpect(status().isForbidden());
    }

    @Test
    void incorrectBasicPasswordIsRejected() throws Exception {
        mvc.perform(get("/api/v1/proof/get-my-proofs").with(httpBasic("member@example.test", "wrong")))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void basicLoginInjectsTheApplicationUserAsPrincipal() throws Exception {
        mvc.perform(get("/api/v1/security-test/me").with(httpBasic("member@example.test", "test-password")))
                .andExpect(status().isOk())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.content().string("member@example.test|MEMBER"));
    }

    @Test
    void unpaidPenaltiesDoNotPreventLogin() throws Exception {
        mvc.perform(get("/api/v1/proof/get-my-proofs").with(httpBasic("locked@example.test", "test-password")))
                .andExpect(status().isOk());
    }

    @Test
    void bannedAccountCanStillLoginToPay() throws Exception {
        mvc.perform(get("/api/v1/donation-proof/my/1").with(httpBasic("banned@example.test", "test-password")))
                .andExpect(status().isOk());
    }

    @Test
    void deactivatedAccountCannotLogin() throws Exception {
        mvc.perform(get("/api/v1/proof/get-my-proofs").with(httpBasic("disabled@example.test", "test-password")))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void unknownEmailCannotLogin() throws Exception {
        mvc.perform(get("/api/v1/proof/get-my-proofs").with(httpBasic("missing@example.test", "test-password")))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void memberRegistrationIsPublicButAdminRegistrationIsNot() throws Exception {
        mvc.perform(post("/api/v1/member/register")).andExpect(status().isOk());
        mvc.perform(post("/api/v1/admin/register")).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/admin/register").with(httpBasic("member@example.test", "test-password")))
                .andExpect(status().isForbidden());
    }

    @Configuration
    @EnableWebMvc
    static class TestWebConfig {
        @Bean
        TestEndpoint testEndpoint() {
            return new TestEndpoint();
        }

        @Bean
        UserDetailsService testUsers(PasswordEncoder encoder) {
            // Exercise the production loader and entity with an isolated repository.
            UserRepository repository = mock(UserRepository.class);
            String hash = encoder.encode("test-password");
            for (String email : new String[]{"member@example.test", "locked@example.test", "disabled@example.test", "banned@example.test"}) {
                com.example.atahad.Entity.User user = new com.example.atahad.Entity.User();
                user.setId(1);
                user.setEmail(email);
                user.setPassword(hash);
                user.setRole("MEMBER");
                Member member = new Member();
                member.setId(1);
                member.setIsLocked(email.startsWith("locked"));
                member.setAccountBanned(email.startsWith("banned"));
                member.setAccountStatus(email.startsWith("disabled") ? "DEACTIVATED" : "ACTIVE");
                user.setMember(member);
                when(repository.findUserByEmail(email)).thenReturn(user);
            }
            return new MyUserDetailsService(repository);
        }
    }

    @RestController
    static class TestEndpoint {
        @RequestMapping("/api/v1/security-test/me")
        String principal(@AuthenticationPrincipal com.example.atahad.Entity.User user) {
            return user.getEmail() + "|" + user.getRole();
        }

        @RequestMapping("/**")
        String endpoint() {
            return "Reached after authorization";
        }
    }
}
