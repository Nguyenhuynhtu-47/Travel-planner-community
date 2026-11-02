package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.CreateDestinationRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdateDestinationRequest;
import Travel_Planner.Travel_Planner.model.Destination;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.DestinationStatus;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.DestinationRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
public class AdminDestinationControllerTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private DestinationRepository destinationRepository;

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
    private final List<Integer> createdDestinationIds = new ArrayList<>();

    @BeforeEach
    void setUp() {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        adminUser = userRepository.save(User.builder()
                .username("dest_admin_tester")
                .password(passwordEncoder.encode("Password123!"))
                .email("dest_admin_tester@example.com")
                .fullName("Quản Trị Viên Điểm Đến")
                .role(Role.ADMIN)
                .status(UserStatus.ACTIVE)
                .build());
        adminToken = "Bearer " + jwtTokenProvider.generateToken(adminUser);

        regularUser = userRepository.save(User.builder()
                .username("dest_regular_tester")
                .password(passwordEncoder.encode("Password123!"))
                .email("dest_regular_tester@example.com")
                .fullName("Người Dùng Thông Thường")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());
        userToken = "Bearer " + jwtTokenProvider.generateToken(regularUser);
    }

    @AfterEach
    void tearDown() {
        for (Integer id : createdDestinationIds) {
            destinationRepository.deleteById(id);
        }
        createdDestinationIds.clear();

        if (adminUser != null && adminUser.getUserId() != null) {
            userRepository.delete(adminUser);
        }
        if (regularUser != null && regularUser.getUserId() != null) {
            userRepository.delete(regularUser);
        }
    }

    // ========================================================
    // 1. ADMIN AUTHORIZATION & RBAC TESTS
    // ========================================================

    @Nested
    @DisplayName("Admin Authorization & RBAC Enforcement")
    class AuthorizationTests {

        @Test
        @DisplayName("Unauthenticated request to POST /api/admin/destinations returns 401 Unauthorized")
        void createDestination_unauthenticated_returns401() throws Exception {
            CreateDestinationRequest req = CreateDestinationRequest.builder()
                    .name("Điểm Đến Vô Danh")
                    .address("123 Đường ABC")
                    .build();

            mockMvc.perform(post("/api/admin/destinations")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(req)))
                    .andExpect(status().isUnauthorized());
        }

        @Test
        @DisplayName("Regular user (ROLE_USER) to POST /api/admin/destinations returns 403 Forbidden")
        void createDestination_asRegularUser_returns403() throws Exception {
            CreateDestinationRequest req = CreateDestinationRequest.builder()
                    .name("Điểm Đến Của User")
                    .address("123 Đường ABC")
                    .build();

            mockMvc.perform(post("/api/admin/destinations")
                            .header("Authorization", userToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(req)))
                    .andExpect(status().isForbidden());
        }

        @Test
        @DisplayName("Regular user (ROLE_USER) to PUT /api/admin/destinations/{id} returns 403 Forbidden")
        void updateDestination_asRegularUser_returns403() throws Exception {
            mockMvc.perform(put("/api/admin/destinations/1")
                            .header("Authorization", userToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{}"))
                    .andExpect(status().isForbidden());
        }

        @Test
        @DisplayName("Regular user (ROLE_USER) to DELETE /api/admin/destinations/{id} returns 403 Forbidden")
        void deleteDestination_asRegularUser_returns403() throws Exception {
            mockMvc.perform(delete("/api/admin/destinations/1")
                            .header("Authorization", userToken))
                    .andExpect(status().isForbidden());
        }
    }

    // ========================================================
    // 2. ADMIN DESTINATION CRUD OPERATIONS
    // ========================================================

    @Nested
    @DisplayName("Admin Destination CRUD Operations")
    class CrudOperationsTests {

        @Test
        @DisplayName("Admin creates a shared destination successfully with 201 Created")
        void createDestination_asAdmin_success() throws Exception {
            CreateDestinationRequest req = CreateDestinationRequest.builder()
                    .name("Chùa Linh Phước Test")
                    .address("Trại Mát, Phường 11, TP. Đà Lạt")
                    .description("Chùa ve chai độc đáo bậc nhất Đà Lạt")
                    .imageUrl("https://example.com/chua-linh-phuoc.jpg")
                    .latitude(new BigDecimal("11.9442000"))
                    .longitude(new BigDecimal("108.4983000"))
                    .status(DestinationStatus.ACTIVE)
                    .build();

            String responseContent = mockMvc.perform(post("/api/admin/destinations")
                            .header("Authorization", adminToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(req)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.destinationId").isNumber())
                    .andExpect(jsonPath("$.name").value("Chùa Linh Phước Test"))
                    .andExpect(jsonPath("$.address").value("Trại Mát, Phường 11, TP. Đà Lạt"))
                    .andExpect(jsonPath("$.latitude").value(11.9442))
                    .andExpect(jsonPath("$.longitude").value(108.4983))
                    .andExpect(jsonPath("$.status").value("ACTIVE"))
                    .andReturn().getResponse().getContentAsString();

            Integer destId = objectMapper.readTree(responseContent).get("destinationId").asInt();
            createdDestinationIds.add(destId);

            // Verify persistence
            assertTrue(destinationRepository.existsById(destId));
        }

        @Test
        @DisplayName("Admin updates an existing destination successfully with 200 OK")
        void updateDestination_asAdmin_success() throws Exception {
            Destination dest = destinationRepository.save(Destination.builder()
                    .name("Thác Datanla Gốc")
                    .address("Đèo Prenn, Phường 3, Đà Lạt")
                    .description("Thác nước đẹp tự nhiên")
                    .latitude(new BigDecimal("11.9031000"))
                    .longitude(new BigDecimal("108.4485000"))
                    .status(DestinationStatus.ACTIVE)
                    .build());
            createdDestinationIds.add(dest.getDestinationId());

            UpdateDestinationRequest updateReq = UpdateDestinationRequest.builder()
                    .name("Khu Du Lịch Thác Datanla")
                    .address("Quốc lộ 20, Đèo Prenn, Phường 3, Đà Lạt")
                    .description("Khu du lịch sinh thái và máng trượt alpine coaster")
                    .imageUrl("https://example.com/datanla-new.jpg")
                    .latitude(new BigDecimal("11.9032500"))
                    .longitude(new BigDecimal("108.4486200"))
                    .status(DestinationStatus.ACTIVE)
                    .build();

            mockMvc.perform(put("/api/admin/destinations/" + dest.getDestinationId())
                            .header("Authorization", adminToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(updateReq)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.destinationId").value(dest.getDestinationId()))
                    .andExpect(jsonPath("$.name").value("Khu Du Lịch Thác Datanla"))
                    .andExpect(jsonPath("$.description").value("Khu du lịch sinh thái và máng trượt alpine coaster"));

            Destination updated = destinationRepository.findById(dest.getDestinationId()).orElseThrow();
            assertEquals("Khu Du Lịch Thác Datanla", updated.getName());
        }

        @Test
        @DisplayName("Admin soft-deletes (hides) destination with 204 No Content, removing it from public catalog")
        void deleteDestination_softDeletesToHidden_preservesRecord() throws Exception {
            Destination dest = destinationRepository.save(Destination.builder()
                    .name("Địa Điểm Sắp Ẩn")
                    .address("123 Phố Ẩn, Đà Lạt")
                    .status(DestinationStatus.ACTIVE)
                    .build());
            createdDestinationIds.add(dest.getDestinationId());

            // 1. Verify visible in public endpoint prior to deletion
            mockMvc.perform(get("/api/destinations/" + dest.getDestinationId()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.name").value("Địa Điểm Sắp Ẩn"));

            // 2. Perform Admin DELETE
            mockMvc.perform(delete("/api/admin/destinations/" + dest.getDestinationId())
                            .header("Authorization", adminToken))
                    .andExpect(status().isNoContent());

            // 3. Verify record still exists in database with status HIDDEN (foreign key safety)
            Destination hidden = destinationRepository.findById(dest.getDestinationId()).orElseThrow();
            assertEquals(DestinationStatus.HIDDEN, hidden.getStatus());

            // 4. Verify no longer visible in public endpoint
            mockMvc.perform(get("/api/destinations/" + dest.getDestinationId()))
                    .andExpect(status().isNotFound());

            // 5. Verify still visible in Admin endpoint
            mockMvc.perform(get("/api/admin/destinations/" + dest.getDestinationId())
                            .header("Authorization", adminToken))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.status").value("HIDDEN"));
        }
    }

    // ========================================================
    // 3. VALIDATION & ERROR HANDLING TESTS
    // ========================================================

    @Nested
    @DisplayName("DTO Validation & Constraint Handling")
    class ValidationTests {

        @Test
        @DisplayName("Creating destination with blank name or address returns 400 Bad Request")
        void createDestination_blankFields_badRequest() throws Exception {
            CreateDestinationRequest req = CreateDestinationRequest.builder()
                    .name("   ")
                    .address("")
                    .build();

            mockMvc.perform(post("/api/admin/destinations")
                            .header("Authorization", adminToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(req)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.validationErrors.name").exists())
                    .andExpect(jsonPath("$.validationErrors.address").exists());
        }

        @Test
        @DisplayName("Creating destination with out-of-bounds coordinates returns 400 Bad Request")
        void createDestination_outOfBoundsCoordinates_badRequest() throws Exception {
            CreateDestinationRequest req = CreateDestinationRequest.builder()
                    .name("Tọa Độ Sai Bounds")
                    .address("Việt Nam")
                    .latitude(new BigDecimal("95.0"))
                    .longitude(new BigDecimal("105.0"))
                    .build();

            mockMvc.perform(post("/api/admin/destinations")
                            .header("Authorization", adminToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(req)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.validationErrors.latitude").exists());
        }

        @Test
        @DisplayName("Creating destination with duplicate name returns 400 Bad Request")
        void createDestination_duplicateName_badRequest() throws Exception {
            Destination existing = destinationRepository.save(Destination.builder()
                    .name("Trùng Tên Duy Nhất")
                    .address("Đà Lạt")
                    .status(DestinationStatus.ACTIVE)
                    .build());
            createdDestinationIds.add(existing.getDestinationId());

            CreateDestinationRequest duplicateReq = CreateDestinationRequest.builder()
                    .name("Trùng Tên Duy Nhất")
                    .address("Địa chỉ khác")
                    .build();

            mockMvc.perform(post("/api/admin/destinations")
                            .header("Authorization", adminToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(duplicateReq)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.message").value(containsString("đã tồn tại")));
        }

        @Test
        @DisplayName("Updating or deleting non-existent destination ID returns 404 Not Found")
        void updateOrDelete_nonExistentId_returns404() throws Exception {
            UpdateDestinationRequest updateReq = UpdateDestinationRequest.builder()
                    .name("Tên Mới")
                    .address("Địa chỉ mới")
                    .build();

            mockMvc.perform(put("/api/admin/destinations/999999")
                            .header("Authorization", adminToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(updateReq)))
                    .andExpect(status().isNotFound());

            mockMvc.perform(delete("/api/admin/destinations/999999")
                            .header("Authorization", adminToken))
                    .andExpect(status().isNotFound());
        }
    }
}

