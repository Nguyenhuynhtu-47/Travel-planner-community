package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.AdministrativeAreaMigrationRunner;
import Travel_Planner.Travel_Planner.dto.request.BatchResolvePlacesRequest;
import Travel_Planner.Travel_Planner.dto.request.ManualLinkAdministrativeAreaRequest;
import Travel_Planner.Travel_Planner.model.AdministrativeArea;
import Travel_Planner.Travel_Planner.model.Place;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaTrustClassification;
import Travel_Planner.Travel_Planner.model.enums.PlaceCategory;
import Travel_Planner.Travel_Planner.model.enums.PlaceStatus;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.AdministrativeAreaRepository;
import Travel_Planner.Travel_Planner.repository.PlaceRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.math.BigDecimal;
import java.util.List;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
public class AdminPlaceAdministrativeAreaControllerTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PlaceRepository placeRepository;

    @Autowired
    private AdministrativeAreaRepository areaRepository;

    @Autowired
    private AdministrativeAreaMigrationRunner migrationRunner;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private ObjectMapper objectMapper;

    private MockMvc mockMvc;
    private User adminUser;
    private User regularUser;
    private String adminToken;
    private String userToken;
    private Place testPlace;

    @BeforeEach
    void setUp() throws Exception {
        mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        // Ensure administrative catalog is imported
        migrationRunner.migrateAndImport();

        adminUser = userRepository.save(User.builder()
                .username("admin_link_" + System.currentTimeMillis())
                .email("admin_link_" + System.currentTimeMillis() + "@test.com")
                .password(passwordEncoder.encode("Password@123"))
                .fullName("Admin Link User")
                .role(Role.ADMIN)
                .status(UserStatus.ACTIVE)
                .build());

        regularUser = userRepository.save(User.builder()
                .username("user_link_" + System.currentTimeMillis())
                .email("user_link_" + System.currentTimeMillis() + "@test.com")
                .password(passwordEncoder.encode("Password@123"))
                .fullName("Regular Link User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        adminToken = "Bearer " + jwtTokenProvider.generateToken(adminUser);
        userToken = "Bearer " + jwtTokenProvider.generateToken(regularUser);

        testPlace = placeRepository.save(Place.builder()
                .name("Văn Miếu Thử Nghiệm")
                .address("58 Quốc Tử Giám, Đống Đa, Hà Nội")
                .latitude(new BigDecimal("21.0293500"))
                .longitude(new BigDecimal("105.8360500"))
                .category(PlaceCategory.ATTRACTION)
                .status(PlaceStatus.ACTIVE)
                .build());
    }

    @AfterEach
    void tearDown() {
        if (testPlace != null && testPlace.getPlaceId() != null) {
            placeRepository.deleteById(testPlace.getPlaceId());
        }
        if (adminUser != null && adminUser.getUserId() != null) {
            userRepository.deleteById(adminUser.getUserId());
        }
        if (regularUser != null && regularUser.getUserId() != null) {
            userRepository.deleteById(regularUser.getUserId());
        }
    }

    @Test
    @DisplayName("POST /api/admin/places/{id}/administrative-area/preview should return 200 OK with resolution details")
    void testPreviewResolution_Admin() throws Exception {
        mockMvc.perform(post("/api/admin/places/" + testPlace.getPlaceId() + "/administrative-area/preview")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.placeId", is(testPlace.getPlaceId().intValue())))
                .andExpect(jsonPath("$.confidence", notNullValue()))
                .andExpect(jsonPath("$.resolvedArea", notNullValue()))
                .andExpect(jsonPath("$.eligibleForAutoLink", is(true)));
    }

    @Test
    @DisplayName("POST /api/admin/places/{id}/administrative-area/resolve should persist link and return 200 OK")
    void testResolveAndLink_Admin() throws Exception {
        mockMvc.perform(post("/api/admin/places/" + testPlace.getPlaceId() + "/administrative-area/resolve")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.placeId", is(testPlace.getPlaceId().intValue())))
                .andExpect(jsonPath("$.currentlyLinked", is(true)))
                .andExpect(jsonPath("$.resolvedArea.code", notNullValue()));

        Place updated = placeRepository.findById(testPlace.getPlaceId()).orElseThrow();
        assertNotNull(updated.getAdministrativeArea());
    }

    @Test
    @DisplayName("POST /api/admin/places/{id}/administrative-area/link should link manually to verified code")
    void testLinkManually_Success() throws Exception {
        ManualLinkAdministrativeAreaRequest req = ManualLinkAdministrativeAreaRequest.builder()
                .administrativeAreaCode("00070")
                .reason("Admin manual assignment")
                .build();

        mockMvc.perform(post("/api/admin/places/" + testPlace.getPlaceId() + "/administrative-area/link")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.placeId", is(testPlace.getPlaceId().intValue())))
                .andExpect(jsonPath("$.administrativeArea.code", is("00070")));

        Place updated = placeRepository.findById(testPlace.getPlaceId()).orElseThrow();
        assertNotNull(updated.getAdministrativeArea());
        assertEquals("00070", updated.getAdministrativeArea().getCode());
    }

    @Test
    @DisplayName("CRITICAL: POST /api/admin/places/{id}/administrative-area/link must reject quarantined Bắc Ninh code with 400 Bad Request")
    void testLinkManually_QuarantinedBacNinh_Rejected() throws Exception {
        ManualLinkAdministrativeAreaRequest req = ManualLinkAdministrativeAreaRequest.builder()
                .administrativeAreaCode("07294")
                .reason("Manual test link to quarantined unit")
                .build();

        mockMvc.perform(post("/api/admin/places/" + testPlace.getPlaceId() + "/administrative-area/link")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("cách ly pháp lý")));

        Place updated = placeRepository.findById(testPlace.getPlaceId()).orElseThrow();
        assertNull(updated.getAdministrativeArea());
    }

    @Test
    @DisplayName("DELETE /api/admin/places/{id}/administrative-area should unlink administrative area")
    void testUnlink_Success() throws Exception {
        // First resolve and link
        mockMvc.perform(post("/api/admin/places/" + testPlace.getPlaceId() + "/administrative-area/resolve")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk());

        // Then unlink
        mockMvc.perform(delete("/api/admin/places/" + testPlace.getPlaceId() + "/administrative-area")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.administrativeArea", nullValue()));

        Place updated = placeRepository.findById(testPlace.getPlaceId()).orElseThrow();
        assertNull(updated.getAdministrativeArea());
    }

    @Test
    @DisplayName("POST /api/admin/places/administrative-area/batch-resolve should return batch report")
    void testBatchResolve_Admin() throws Exception {
        BatchResolvePlacesRequest req = BatchResolvePlacesRequest.builder()
                .dryRun(true)
                .placeIds(List.of(testPlace.getPlaceId()))
                .build();

        mockMvc.perform(post("/api/admin/places/administrative-area/batch-resolve")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalPlacesExamined", is(1)))
                .andExpect(jsonPath("$.dryRun", is(true)))
                .andExpect(jsonPath("$.results", hasSize(1)));
    }

    @Test
    @DisplayName("Security: Unauthenticated request should return 401")
    void testSecurity_Unauthenticated() throws Exception {
        mockMvc.perform(post("/api/admin/places/" + testPlace.getPlaceId() + "/administrative-area/preview")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Security: Non-admin request should return 403 Forbidden")
    void testSecurity_NonAdmin() throws Exception {
        mockMvc.perform(post("/api/admin/places/" + testPlace.getPlaceId() + "/administrative-area/preview")
                        .header("Authorization", userToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isForbidden());
    }
}
