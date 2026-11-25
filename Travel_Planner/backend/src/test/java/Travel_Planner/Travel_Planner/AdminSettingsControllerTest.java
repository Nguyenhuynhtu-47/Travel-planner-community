package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.UpdateSystemSettingRequest;
import Travel_Planner.Travel_Planner.model.AuditLog;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.AuditActionType;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.AuditLogRepository;
import Travel_Planner.Travel_Planner.repository.SystemSettingRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import Travel_Planner.Travel_Planner.service.SystemSettingService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.util.List;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
public class AdminSettingsControllerTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private SystemSettingRepository settingRepository;

    @Autowired
    private SystemSettingService systemSettingService;

    @Autowired
    private AuditLogRepository auditLogRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private MockMvc mockMvc;
    private String adminToken;
    private String userToken;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        long ts = System.currentTimeMillis();
        User adminUser = userRepository.save(User.builder()
                .username("settings_admin_" + ts)
                .email("settings_admin_" + ts + "@test.com")
                .password(passwordEncoder.encode("Password@123"))
                .fullName("Settings Admin")
                .role(Role.ADMIN)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .build());

        User regularUser = userRepository.save(User.builder()
                .username("settings_user_" + ts)
                .email("settings_user_" + ts + "@test.com")
                .password(passwordEncoder.encode("Password@123"))
                .fullName("Settings Regular User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .build());

        adminToken = "Bearer " + jwtTokenProvider.generateToken(adminUser);
        userToken = "Bearer " + jwtTokenProvider.generateToken(regularUser);
    }

    @AfterEach
    void tearDown() {
        // Always restore maintenance mode off and default values after test
        settingRepository.findById("SYSTEM_MAINTENANCE_MODE").ifPresent(s -> {
            s.setSettingValue("false");
            settingRepository.saveAndFlush(s);
        });
        settingRepository.findById("MEDIA_MAX_IMAGE_SIZE_MB").ifPresent(s -> {
            s.setSettingValue("2");
            settingRepository.saveAndFlush(s);
        });
        systemSettingService.refreshCache();
        TestDatabaseCleaner.clean(jdbcTemplate);
    }

    @Test
    @DisplayName("RBAC: Unauthenticated (401) and non-ADMIN (403) rejected; ADMIN retrieves business settings only")
    void security_RbacAndAllowlist() throws Exception {
        mockMvc.perform(get("/api/admin/settings"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get("/api/admin/settings")
                        .header("Authorization", userToken))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/admin/settings")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(5)))
                .andExpect(jsonPath("$[*].settingKey", hasItems(
                        "MODERATION_AUTO_HIDE_THRESHOLD",
                        "GEO_AUTO_RESOLVE_CONFIDENCE_THRESHOLD",
                        "MEDIA_MAX_IMAGE_SIZE_MB",
                        "SYSTEM_MAINTENANCE_MODE",
                        "SYSTEM_MAINTENANCE_MESSAGE"
                )));
    }

    @Test
    @DisplayName("Validation: Rejects out-of-range settings (>5MB upload) and unknown/secret keys")
    void validation_RejectsInvalidValuesAndUnknownKeys() throws Exception {
        // MEDIA_MAX_IMAGE_SIZE_MB > 5MB -> 400
        UpdateSystemSettingRequest invalidUpload = UpdateSystemSettingRequest.builder()
                .settingValue("6")
                .reason("Attempt exceeding servlet limit")
                .build();
        mockMvc.perform(put("/api/admin/settings/MEDIA_MAX_IMAGE_SIZE_MB")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(invalidUpload)))
                .andExpect(status().isBadRequest());

        // MODERATION_AUTO_HIDE_THRESHOLD > 50 -> 400
        UpdateSystemSettingRequest invalidModeration = UpdateSystemSettingRequest.builder()
                .settingValue("51")
                .build();
        mockMvc.perform(put("/api/admin/settings/MODERATION_AUTO_HIDE_THRESHOLD")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(invalidModeration)))
                .andExpect(status().isBadRequest());

        // GEO_AUTO_RESOLVE_CONFIDENCE_THRESHOLD < 0.50 -> 400
        UpdateSystemSettingRequest invalidGeo = UpdateSystemSettingRequest.builder()
                .settingValue("0.30")
                .build();
        mockMvc.perform(put("/api/admin/settings/GEO_AUTO_RESOLVE_CONFIDENCE_THRESHOLD")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(invalidGeo)))
                .andExpect(status().isBadRequest());

        // Unknown/secret key -> 400
        UpdateSystemSettingRequest secretKeyReq = UpdateSystemSettingRequest.builder()
                .settingValue("hacked")
                .build();
        mockMvc.perform(put("/api/admin/settings/JWT_SECRET")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(secretKeyReq)))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("Update & Strict Audit: Persists valid setting update and records SETTING_UPDATE audit log")
    void updateSetting_PersistsAndRecordsStrictAudit() throws Exception {
        UpdateSystemSettingRequest req = UpdateSystemSettingRequest.builder()
                .settingValue("4")
                .reason("Increase upload limit to 4MB")
                .build();

        mockMvc.perform(put("/api/admin/settings/MEDIA_MAX_IMAGE_SIZE_MB")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.settingKey", is("MEDIA_MAX_IMAGE_SIZE_MB")))
                .andExpect(jsonPath("$.settingValue", is("4")));

        assertEquals(4, systemSettingService.getMaxImageSizeMb());

        List<AuditLog> logs = auditLogRepository
                .findByOrderByCreatedAtDescLogIdDesc(PageRequest.of(0, 5))
                .getContent();
        assertFalse(logs.isEmpty());
        AuditLog latest = logs.get(0);
        assertEquals(AuditActionType.SETTING_UPDATE, latest.getActionType());
        assertEquals("MEDIA_MAX_IMAGE_SIZE_MB", latest.getTargetId());
    }

    @Test
    @DisplayName("Maintenance Mode: Blocks non-admin/unauthenticated with 503 while allowing health, login, CORS OPTIONS, and ADMIN bypass")
    void maintenanceMode_Enforces503AndAdminBypass() throws Exception {
        UpdateSystemSettingRequest enableMaintenance = UpdateSystemSettingRequest.builder()
                .settingValue("true")
                .reason("Scheduled DB maintenance")
                .build();

        mockMvc.perform(put("/api/admin/settings/SYSTEM_MAINTENANCE_MODE")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(enableMaintenance)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.settingValue", is("true")));

        // Verify MAINTENANCE_TOGGLE audit log recorded
        List<AuditLog> logs = auditLogRepository
                .findByOrderByCreatedAtDescLogIdDesc(PageRequest.of(0, 5))
                .getContent();
        assertEquals(AuditActionType.MAINTENANCE_TOGGLE, logs.get(0).getActionType());

        // 1. Unauthenticated request -> 503
        mockMvc.perform(get("/api/itineraries"))
                .andExpect(status().isServiceUnavailable());

        // 2. Regular USER -> 503 (even on /api/admin/**)
        mockMvc.perform(get("/api/itineraries")
                        .header("Authorization", userToken))
                .andExpect(status().isServiceUnavailable());
        mockMvc.perform(get("/api/admin/places")
                        .header("Authorization", userToken))
                .andExpect(status().isServiceUnavailable());

        // 3. Essential endpoints remain accessible (/api/health, /api/auth/login)
        mockMvc.perform(get("/api/health"))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"identifier\":\"nobody\",\"password\":\"wrong\"}"))
                .andExpect(status().is(not(503)));

        // 4. CORS OPTIONS preflight -> 200 OK
        mockMvc.perform(options("/api/itineraries")
                        .header("Origin", "http://localhost:8081")
                        .header("Access-Control-Request-Method", "GET"))
                .andExpect(status().isOk());

        // 5. Authenticated ADMIN bypasses maintenance mode successfully
        mockMvc.perform(get("/api/admin/settings")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
        mockMvc.perform(get("/api/itineraries")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
    }
}
