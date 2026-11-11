package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.CreatePlaceRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdatePlaceRequest;
import Travel_Planner.Travel_Planner.model.Place;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.PlaceCategory;
import Travel_Planner.Travel_Planner.model.enums.PlaceStatus;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.PlaceProviderMappingRepository;
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

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
public class PlaceControllerTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PlaceRepository placeRepository;

    @Autowired
    private PlaceProviderMappingRepository mappingRepository;

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

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        cleanUp();

        adminUser = userRepository.save(User.builder()
                .username("admin_place_" + System.currentTimeMillis())
                .email("admin_place_" + System.currentTimeMillis() + "@test.com")
                .password(passwordEncoder.encode("Password@123"))
                .fullName("Admin Place User")
                .role(Role.ADMIN)
                .status(UserStatus.ACTIVE)
                .build());

        regularUser = userRepository.save(User.builder()
                .username("user_place_" + System.currentTimeMillis())
                .email("user_place_" + System.currentTimeMillis() + "@test.com")
                .password(passwordEncoder.encode("Password@123"))
                .fullName("Regular Place User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        adminToken = "Bearer " + jwtTokenProvider.generateToken(adminUser);
        userToken = "Bearer " + jwtTokenProvider.generateToken(regularUser);
    }

    @AfterEach
    void tearDown() {
        cleanUp();
    }

    private void cleanUp() {
        mappingRepository.deleteAll();
        placeRepository.deleteAll();
        if (adminUser != null) userRepository.delete(adminUser);
        if (regularUser != null) userRepository.delete(regularUser);
    }

    @Test
    @DisplayName("Public search GET /api/places returns 200 with paginated active places")
    void testPublicSearchPlaces() throws Exception {
        placeRepository.save(Place.builder()
                .name("Chùa Một Cột")
                .normalizedName("chua mot cot")
                .address("Ba Đình, Hà Nội")
                .latitude(new BigDecimal("21.0358000"))
                .longitude(new BigDecimal("105.8335000"))
                .category(PlaceCategory.ATTRACTION)
                .status(PlaceStatus.ACTIVE)
                .build());

        mockMvc.perform(get("/api/places")
                        .param("keyword", "Chùa")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].name", is("Chùa Một Cột")));
    }

    @Test
    @DisplayName("Public detail GET /api/places/{id} returns 200 for active, 404 for hidden")
    void testPublicGetPlaceById() throws Exception {
        Place active = placeRepository.save(Place.builder()
                .name("Hồ Gươm")
                .normalizedName("ho guom")
                .address("Hoàn Kiếm, Hà Nội")
                .latitude(new BigDecimal("21.0285000"))
                .longitude(new BigDecimal("105.8542000"))
                .category(PlaceCategory.ATTRACTION)
                .status(PlaceStatus.ACTIVE)
                .build());

        Place hidden = placeRepository.save(Place.builder()
                .name("Khu Vực Đang Đóng Cửa")
                .normalizedName("khu vuc dang dong cua")
                .address("Hà Nội")
                .latitude(new BigDecimal("21.0300000"))
                .longitude(new BigDecimal("105.8500000"))
                .category(PlaceCategory.OTHER)
                .status(PlaceStatus.HIDDEN)
                .build());

        mockMvc.perform(get("/api/places/" + active.getPlaceId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name", is("Hồ Gươm")));

        mockMvc.perform(get("/api/places/" + hidden.getPlaceId()))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("Admin create POST /api/admin/places: 403 for regular user, 201 for admin")
    void testAdminCreatePlaceAuthorization() throws Exception {
        CreatePlaceRequest request = CreatePlaceRequest.builder()
                .name("Quán Phở Thìn Lò Đúc")
                .address("13 Lò Đúc, Hai Bà Trưng, Hà Nội")
                .latitude(new BigDecimal("21.0186000"))
                .longitude(new BigDecimal("105.8567000"))
                .category(PlaceCategory.RESTAURANT)
                .build();

        // 1. Regular user gets 403 Forbidden
        mockMvc.perform(post("/api/admin/places")
                        .header("Authorization", userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isForbidden());

        // 2. Admin gets 201 Created
        mockMvc.perform(post("/api/admin/places")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.placeId", notNullValue()))
                .andExpect(jsonPath("$.name", is("Quán Phở Thìn Lò Đúc")))
                .andExpect(jsonPath("$.category", is("RESTAURANT")));
    }

    @Test
    @DisplayName("Admin update PUT /api/admin/places/{id} updates place detail successfully")
    void testAdminUpdatePlace() throws Exception {
        Place place = placeRepository.save(Place.builder()
                .name("Tên Cũ")
                .normalizedName("ten cu")
                .address("Địa Chỉ Cũ")
                .latitude(new BigDecimal("21.0000000"))
                .longitude(new BigDecimal("105.0000000"))
                .category(PlaceCategory.OTHER)
                .status(PlaceStatus.ACTIVE)
                .build());

        UpdatePlaceRequest request = UpdatePlaceRequest.builder()
                .name("Tên Mới")
                .address("Địa Chỉ Mới")
                .latitude(new BigDecimal("21.0100000"))
                .longitude(new BigDecimal("105.0100000"))
                .category(PlaceCategory.CAFE)
                .status(PlaceStatus.ACTIVE)
                .build();

        mockMvc.perform(put("/api/admin/places/" + place.getPlaceId())
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name", is("Tên Mới")))
                .andExpect(jsonPath("$.category", is("CAFE")));
    }

    @Test
    @DisplayName("Admin delete DELETE /api/admin/places/{id} soft-deletes to HIDDEN status")
    void testAdminDeletePlace() throws Exception {
        Place place = placeRepository.save(Place.builder()
                .name("Địa Điểm Chuẩn Bị Ẩn")
                .normalizedName("dia diem chuan bi an")
                .address("Hà Nội")
                .latitude(new BigDecimal("21.0000000"))
                .longitude(new BigDecimal("105.0000000"))
                .category(PlaceCategory.ATTRACTION)
                .status(PlaceStatus.ACTIVE)
                .build());

        mockMvc.perform(delete("/api/admin/places/" + place.getPlaceId())
                        .header("Authorization", adminToken))
                .andExpect(status().isNoContent());

        Place reloaded = placeRepository.findById(place.getPlaceId()).orElseThrow();
        assertEquals(PlaceStatus.HIDDEN, reloaded.getStatus());
    }

    @Test
    @DisplayName("Admin list GET /api/admin/places can list and filter places by status including HIDDEN")
    void testAdminGetPlacesFilter() throws Exception {
        placeRepository.save(Place.builder()
                .name("Nơi Đã Ẩn")
                .normalizedName("noi da an")
                .address("Hà Nội")
                .latitude(new BigDecimal("21.0000000"))
                .longitude(new BigDecimal("105.0000000"))
                .category(PlaceCategory.ATTRACTION)
                .status(PlaceStatus.HIDDEN)
                .build());

        mockMvc.perform(get("/api/admin/places")
                        .header("Authorization", adminToken)
                        .param("status", "HIDDEN"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].status", is("HIDDEN")));
    }
}
