package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.CreateActivityRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdateActivityRequest;
import Travel_Planner.Travel_Planner.model.Activity;
import Travel_Planner.Travel_Planner.model.Destination;
import Travel_Planner.Travel_Planner.model.Itinerary;
import Travel_Planner.Travel_Planner.model.ItineraryDay;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.DestinationStatus;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;
import Travel_Planner.Travel_Planner.repository.ActivityRepository;
import Travel_Planner.Travel_Planner.repository.DestinationRepository;
import Travel_Planner.Travel_Planner.repository.ItineraryDayRepository;
import Travel_Planner.Travel_Planner.repository.ItineraryRepository;
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
import java.time.LocalDate;
import java.time.LocalTime;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
class ActivityLocationTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ItineraryRepository itineraryRepository;

    @Autowired
    private ItineraryDayRepository itineraryDayRepository;

    @Autowired
    private ActivityRepository activityRepository;

    @Autowired
    private DestinationRepository destinationRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private ObjectMapper objectMapper;

    private MockMvc mockMvc;

    private User ownerUser;
    private User otherUser;
    private String ownerToken;
    private String otherToken;
    private Destination activeDestination;
    private Itinerary testItinerary;
    private ItineraryDay testDay;

    @BeforeEach
    void setUp() {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        objectMapper.registerModule(new com.fasterxml.jackson.datatype.jsr310.JavaTimeModule());
        objectMapper.disable(com.fasterxml.jackson.databind.SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

        activityRepository.deleteAll();
        itineraryDayRepository.deleteAll();
        itineraryRepository.deleteAll();
        destinationRepository.deleteAll();
        userRepository.deleteAll();

        ownerUser = userRepository.save(User.builder()
                .username("location_owner")
                .password(passwordEncoder.encode("Password123!"))
                .email("location_owner@example.com")
                .fullName("Chủ Lịch Trình Map")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        otherUser = userRepository.save(User.builder()
                .username("location_other")
                .password(passwordEncoder.encode("Password123!"))
                .email("location_other@example.com")
                .fullName("Người Dùng Khác Map")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        ownerToken = "Bearer " + jwtTokenProvider.generateToken(ownerUser);
        otherToken = "Bearer " + jwtTokenProvider.generateToken(otherUser);

        activeDestination = destinationRepository.save(Destination.builder()
                .name("Chùa Cầu Hội An")
                .address("Đường Nguyễn Thị Minh Khai, Phường Minh An, Hội An")
                .description("Di tích lịch sử nổi tiếng")
                .latitude(new BigDecimal("15.8771120"))
                .longitude(new BigDecimal("108.3259830"))
                .status(DestinationStatus.ACTIVE)
                .build());

        testItinerary = itineraryRepository.save(Itinerary.builder()
                .user(ownerUser)
                .title("Hành Trình Khám Phá Địa Điểm")
                .location("Quảng Nam")
                .totalDays(3)
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .build());

        testDay = itineraryDayRepository.save(ItineraryDay.builder()
                .itinerary(testItinerary)
                .dayNumber(1)
                .title("Ngày 1: Phố Cổ")
                .date(LocalDate.now().plusDays(5))
                .build());
    }

    @AfterEach
    void tearDown() {
        activityRepository.deleteAll();
        itineraryDayRepository.deleteAll();
        itineraryRepository.deleteAll();
        destinationRepository.deleteAll();
        userRepository.deleteAll();
    }

    // ==========================================
    // 1. THREE VALID LOCATION STATES
    // ==========================================

    @Test
    @DisplayName("State 1: Catalog Destination - destinationId set, all custom location fields null")
    void createActivity_catalogDestination_success() throws Exception {
        CreateActivityRequest request = CreateActivityRequest.builder()
                .name("Tham quan Chùa Cầu")
                .description("Check-in di tích lịch sử")
                .destinationId(activeDestination.getDestinationId())
                .startTime(LocalTime.of(9, 0))
                .endTime(LocalTime.of(10, 30))
                .cost(new BigDecimal("50000.00"))
                .build();

        mockMvc.perform(post("/api/itineraries/{itineraryId}/days/{dayId}/activities",
                        testItinerary.getItineraryId(), testDay.getDayId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.name").value("Tham quan Chùa Cầu"))
                .andExpect(jsonPath("$.destination.destinationId").value(activeDestination.getDestinationId()))
                .andExpect(jsonPath("$.destination.name").value("Chùa Cầu Hội An"))
                .andExpect(jsonPath("$.customLocationName").doesNotExist())
                .andExpect(jsonPath("$.customAddress").doesNotExist())
                .andExpect(jsonPath("$.latitude").doesNotExist())
                .andExpect(jsonPath("$.longitude").doesNotExist())
                .andExpect(jsonPath("$.placeId").doesNotExist())
                .andExpect(jsonPath("$.locationProvider").doesNotExist());

        Activity saved = activityRepository.findAll().get(0);
        assertNotNull(saved.getDestination());
        assertEquals(activeDestination.getDestinationId(), saved.getDestination().getDestinationId());
        assertNull(saved.getCustomLocationName());
        assertNull(saved.getCustomAddress());
        assertNull(saved.getLatitude());
        assertNull(saved.getLongitude());
        assertNull(saved.getPlaceId());
        assertNull(saved.getLocationProvider());
    }

    @Test
    @DisplayName("State 2: Custom Location - destinationId null, latitude/longitude and custom fields populated")
    void createActivity_customLocation_success() throws Exception {
        CreateActivityRequest request = CreateActivityRequest.builder()
                .name("Ghé quán Cà phê Faifo")
                .description("Ngắm hoàng hôn trên tầng thượng")
                .destinationId(null)
                .customLocationName("Faifo Coffee")
                .customAddress("130 Trần Phú, Phường Minh An, Hội An")
                .latitude(new BigDecimal("15.8778450"))
                .longitude(new BigDecimal("108.3289120"))
                .placeId("osm_node_998877")
                .locationProvider("LOCATION_IQ")
                .cost(new BigDecimal("75000.00"))
                .build();

        mockMvc.perform(post("/api/itineraries/{itineraryId}/days/{dayId}/activities",
                        testItinerary.getItineraryId(), testDay.getDayId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.name").value("Ghé quán Cà phê Faifo"))
                .andExpect(jsonPath("$.destination").doesNotExist())
                .andExpect(jsonPath("$.customLocationName").value("Faifo Coffee"))
                .andExpect(jsonPath("$.customAddress").value("130 Trần Phú, Phường Minh An, Hội An"))
                .andExpect(jsonPath("$.latitude").value(15.8778450))
                .andExpect(jsonPath("$.longitude").value(108.3289120))
                .andExpect(jsonPath("$.placeId").value("osm_node_998877"))
                .andExpect(jsonPath("$.locationProvider").value("LOCATION_IQ"));

        Activity saved = activityRepository.findAll().get(0);
        assertNull(saved.getDestination());
        assertEquals("Faifo Coffee", saved.getCustomLocationName());
        assertEquals("130 Trần Phú, Phường Minh An, Hội An", saved.getCustomAddress());
        assertEquals(new BigDecimal("15.8778450"), saved.getLatitude());
        assertEquals(new BigDecimal("108.3289120"), saved.getLongitude());
        assertEquals("osm_node_998877", saved.getPlaceId());
        assertEquals("LOCATION_IQ", saved.getLocationProvider());
    }

    @Test
    @DisplayName("State 2: Custom Location (Coordinates-Only Pin Drop) - optional custom venue name omitted")
    void createActivity_customLocation_coordinatesOnly_success() throws Exception {
        CreateActivityRequest request = CreateActivityRequest.builder()
                .name("Đi dạo ven sông Hoài")
                .destinationId(null)
                .latitude(new BigDecimal("15.8765000"))
                .longitude(new BigDecimal("108.3275000"))
                .build();

        mockMvc.perform(post("/api/itineraries/{itineraryId}/days/{dayId}/activities",
                        testItinerary.getItineraryId(), testDay.getDayId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.destination").doesNotExist())
                .andExpect(jsonPath("$.customLocationName").doesNotExist())
                .andExpect(jsonPath("$.latitude").value(15.8765000))
                .andExpect(jsonPath("$.longitude").value(108.3275000));

        Activity saved = activityRepository.findAll().get(0);
        assertNull(saved.getDestination());
        assertNull(saved.getCustomLocationName());
        assertEquals(new BigDecimal("15.8765000"), saved.getLatitude());
        assertEquals(new BigDecimal("108.3275000"), saved.getLongitude());
    }

    @Test
    @DisplayName("State 3: No Location - all location fields null")
    void createActivity_noLocation_success() throws Exception {
        CreateActivityRequest request = CreateActivityRequest.builder()
                .name("Nghỉ ngơi tự do tại khách sạn")
                .description("Thư giãn, đọc sách")
                .destinationId(null)
                .customLocationName(null)
                .customAddress(null)
                .latitude(null)
                .longitude(null)
                .build();

        mockMvc.perform(post("/api/itineraries/{itineraryId}/days/{dayId}/activities",
                        testItinerary.getItineraryId(), testDay.getDayId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.destination").doesNotExist())
                .andExpect(jsonPath("$.customLocationName").doesNotExist())
                .andExpect(jsonPath("$.latitude").doesNotExist())
                .andExpect(jsonPath("$.longitude").doesNotExist());

        Activity saved = activityRepository.findAll().get(0);
        assertNull(saved.getDestination());
        assertNull(saved.getCustomLocationName());
        assertNull(saved.getLatitude());
        assertNull(saved.getLongitude());
    }

    @Test
    @DisplayName("Activity cover image is returned and preserved by legacy update payloads")
    void activityImage_createAndLegacyUpdate_preservesImage() throws Exception {
        String coverUrl = "https://res.cloudinary.com/test/image/upload/v1/activity-cover.jpg";
        CreateActivityRequest request = CreateActivityRequest.builder()
                .name("Ghé quán cà phê")
                .imageUrl(coverUrl)
                .build();

        String response = mockMvc.perform(post("/api/itineraries/{itineraryId}/days/{dayId}/activities",
                        testItinerary.getItineraryId(), testDay.getDayId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.imageUrl").value(coverUrl))
                .andReturn().getResponse().getContentAsString();
        int activityId = objectMapper.readTree(response).get("activityId").asInt();

        mockMvc.perform(put("/api/itineraries/{itineraryId}/days/{dayId}/activities/{activityId}",
                        testItinerary.getItineraryId(), testDay.getDayId(), activityId)
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Cập nhật tên\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.imageUrl").value(coverUrl));
    }

    // ==========================================
    // 2. INVALID COMBINATIONS & BOUNDS
    // ==========================================

    @Test
    @DisplayName("Invalid: Both destinationId and custom coordinates supplied - rejected with HTTP 400")
    void createActivity_conflictDestinationAndCustomCoords_throwsBadRequest() throws Exception {
        CreateActivityRequest request = CreateActivityRequest.builder()
                .name("Hoạt động xung đột vị trí")
                .destinationId(activeDestination.getDestinationId())
                .latitude(new BigDecimal("15.8770000"))
                .longitude(new BigDecimal("108.3260000"))
                .build();

        mockMvc.perform(post("/api/itineraries/{itineraryId}/days/{dayId}/activities",
                        testItinerary.getItineraryId(), testDay.getDayId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(containsString("Không thể đồng thời chỉ định địa điểm từ danh mục và tọa độ tùy chỉnh")));
    }

    @Test
    @DisplayName("Invalid: Unpaired coordinates (latitude provided, longitude missing) - rejected with HTTP 400")
    void createActivity_unpairedLatitude_throwsBadRequest() throws Exception {
        CreateActivityRequest request = CreateActivityRequest.builder()
                .name("Tọa độ thiếu longitude")
                .latitude(new BigDecimal("15.8770000"))
                .longitude(null)
                .build();

        mockMvc.perform(post("/api/itineraries/{itineraryId}/days/{dayId}/activities",
                        testItinerary.getItineraryId(), testDay.getDayId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(containsString("Tọa độ latitude và longitude phải được cung cấp đồng thời")));
    }

    @Test
    @DisplayName("Invalid: Unpaired coordinates (longitude provided, latitude missing) - rejected with HTTP 400")
    void createActivity_unpairedLongitude_throwsBadRequest() throws Exception {
        CreateActivityRequest request = CreateActivityRequest.builder()
                .name("Tọa độ thiếu latitude")
                .latitude(null)
                .longitude(new BigDecimal("108.3260000"))
                .build();

        mockMvc.perform(post("/api/itineraries/{itineraryId}/days/{dayId}/activities",
                        testItinerary.getItineraryId(), testDay.getDayId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(containsString("Tọa độ latitude và longitude phải được cung cấp đồng thời")));
    }

    @Test
    @DisplayName("Invalid: Custom venue name supplied without coordinates - rejected with HTTP 400")
    void createActivity_customNameWithoutCoordinates_throwsBadRequest() throws Exception {
        CreateActivityRequest request = CreateActivityRequest.builder()
                .name("Địa điểm không có tọa độ")
                .customLocationName("Quán Cà Phê Ảo")
                .latitude(null)
                .longitude(null)
                .build();

        mockMvc.perform(post("/api/itineraries/{itineraryId}/days/{dayId}/activities",
                        testItinerary.getItineraryId(), testDay.getDayId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(containsString("Tọa độ latitude và longitude là bắt buộc khi sử dụng địa điểm tùy chỉnh")));
    }

    @Test
    @DisplayName("Invalid: Latitude out of bounds (> 90.0 or < -90.0) - rejected with HTTP 400")
    void createActivity_latitudeOutOfBounds_throwsBadRequest() throws Exception {
        CreateActivityRequest requestTooHigh = CreateActivityRequest.builder()
                .name("Latitude quá lớn")
                .latitude(new BigDecimal("90.0001"))
                .longitude(new BigDecimal("108.0"))
                .build();

        mockMvc.perform(post("/api/itineraries/{itineraryId}/days/{dayId}/activities",
                        testItinerary.getItineraryId(), testDay.getDayId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(requestTooHigh)))
                .andExpect(status().isBadRequest());

        CreateActivityRequest requestTooLow = CreateActivityRequest.builder()
                .name("Latitude quá nhỏ")
                .latitude(new BigDecimal("-90.0001"))
                .longitude(new BigDecimal("108.0"))
                .build();

        mockMvc.perform(post("/api/itineraries/{itineraryId}/days/{dayId}/activities",
                        testItinerary.getItineraryId(), testDay.getDayId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(requestTooLow)))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("Invalid: Longitude out of bounds (> 180.0 or < -180.0) - rejected with HTTP 400")
    void createActivity_longitudeOutOfBounds_throwsBadRequest() throws Exception {
        CreateActivityRequest requestTooHigh = CreateActivityRequest.builder()
                .name("Longitude quá lớn")
                .latitude(new BigDecimal("15.0"))
                .longitude(new BigDecimal("180.0001"))
                .build();

        mockMvc.perform(post("/api/itineraries/{itineraryId}/days/{dayId}/activities",
                        testItinerary.getItineraryId(), testDay.getDayId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(requestTooHigh)))
                .andExpect(status().isBadRequest());

        CreateActivityRequest requestTooLow = CreateActivityRequest.builder()
                .name("Longitude quá nhỏ")
                .latitude(new BigDecimal("15.0"))
                .longitude(new BigDecimal("-180.0001"))
                .build();

        mockMvc.perform(post("/api/itineraries/{itineraryId}/days/{dayId}/activities",
                        testItinerary.getItineraryId(), testDay.getDayId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(requestTooLow)))
                .andExpect(status().isBadRequest());
    }

    // ==========================================
    // 3. STATE TRANSITIONS & STALE FIELD CLEANUP
    // ==========================================

    @Test
    @DisplayName("Transition: Custom Location -> Catalog Destination cleanly clears all custom fields")
    void updateActivity_transitionCustomToCatalogDestination_clearsStaleCustomFields() throws Exception {
        // Step 1: Create an activity with custom location
        Activity activity = activityRepository.save(Activity.builder()
                .itineraryDay(testDay)
                .name("Ăn sáng bánh mì")
                .customLocationName("Bánh Mì Phượng")
                .customAddress("Phan Chu Trinh, Hội An")
                .latitude(new BigDecimal("15.8770000"))
                .longitude(new BigDecimal("108.3300000"))
                .placeId("place_123")
                .locationProvider("LOCATION_IQ")
                .displayOrder(1)
                .build());

        // Step 2: Update activity to switch to catalog destination
        UpdateActivityRequest updateRequest = UpdateActivityRequest.builder()
                .name("Chuyển sang Chùa Cầu")
                .destinationId(activeDestination.getDestinationId())
                .customLocationName(null)
                .customAddress(null)
                .latitude(null)
                .longitude(null)
                .placeId(null)
                .locationProvider(null)
                .build();

        mockMvc.perform(put("/api/itineraries/{itineraryId}/days/{dayId}/activities/{activityId}",
                        testItinerary.getItineraryId(), testDay.getDayId(), activity.getActivityId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(updateRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Chuyển sang Chùa Cầu"))
                .andExpect(jsonPath("$.destination.destinationId").value(activeDestination.getDestinationId()))
                .andExpect(jsonPath("$.customLocationName").doesNotExist())
                .andExpect(jsonPath("$.customAddress").doesNotExist())
                .andExpect(jsonPath("$.latitude").doesNotExist())
                .andExpect(jsonPath("$.longitude").doesNotExist())
                .andExpect(jsonPath("$.placeId").doesNotExist())
                .andExpect(jsonPath("$.locationProvider").doesNotExist());

        // Verify database entity is completely devoid of stale custom location data
        Activity updated = activityRepository.findById(activity.getActivityId()).orElseThrow();
        assertNotNull(updated.getDestination());
        assertEquals(activeDestination.getDestinationId(), updated.getDestination().getDestinationId());
        assertNull(updated.getCustomLocationName());
        assertNull(updated.getCustomAddress());
        assertNull(updated.getLatitude());
        assertNull(updated.getLongitude());
        assertNull(updated.getPlaceId());
        assertNull(updated.getLocationProvider());
    }

    @Test
    @DisplayName("Transition: Catalog Destination -> Custom Location cleanly clears stale destination reference")
    void updateActivity_transitionCatalogToCustomLocation_clearsStaleDestination() throws Exception {
        // Step 1: Create an activity with catalog destination
        Activity activity = activityRepository.save(Activity.builder()
                .itineraryDay(testDay)
                .name("Điểm ban đầu là Chùa Cầu")
                .destination(activeDestination)
                .displayOrder(1)
                .build());

        // Step 2: Update activity to switch to custom location
        UpdateActivityRequest updateRequest = UpdateActivityRequest.builder()
                .name("Đổi sang quán nước mót")
                .destinationId(null)
                .customLocationName("Trà Thảo Mộc Mót Hội An")
                .customAddress("150 Trần Phú, Hội An")
                .latitude(new BigDecimal("15.8774000"))
                .longitude(new BigDecimal("108.3292000"))
                .placeId("osm_node_554433")
                .locationProvider("LOCATION_IQ")
                .build();

        mockMvc.perform(put("/api/itineraries/{itineraryId}/days/{dayId}/activities/{activityId}",
                        testItinerary.getItineraryId(), testDay.getDayId(), activity.getActivityId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(updateRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Đổi sang quán nước mót"))
                .andExpect(jsonPath("$.destination").doesNotExist())
                .andExpect(jsonPath("$.customLocationName").value("Trà Thảo Mộc Mót Hội An"))
                .andExpect(jsonPath("$.customAddress").value("150 Trần Phú, Hội An"))
                .andExpect(jsonPath("$.latitude").value(15.8774000))
                .andExpect(jsonPath("$.longitude").value(108.3292000));

        Activity updated = activityRepository.findById(activity.getActivityId()).orElseThrow();
        assertNull(updated.getDestination());
        assertEquals("Trà Thảo Mộc Mót Hội An", updated.getCustomLocationName());
        assertEquals("150 Trần Phú, Hội An", updated.getCustomAddress());
        assertEquals(new BigDecimal("15.8774000"), updated.getLatitude());
        assertEquals(new BigDecimal("108.3292000"), updated.getLongitude());
    }

    @Test
    @DisplayName("Transition: Custom Location -> No Location cleanly clears all location data")
    void updateActivity_transitionCustomToNoLocation_clearsAllLocationFields() throws Exception {
        Activity activity = activityRepository.save(Activity.builder()
                .itineraryDay(testDay)
                .name("Hoạt động có vị trí")
                .customLocationName("Địa điểm X")
                .latitude(new BigDecimal("15.8770000"))
                .longitude(new BigDecimal("108.3300000"))
                .displayOrder(1)
                .build());

        UpdateActivityRequest updateRequest = UpdateActivityRequest.builder()
                .name("Chuyển thành không có vị trí")
                .destinationId(null)
                .customLocationName(null)
                .latitude(null)
                .longitude(null)
                .build();

        mockMvc.perform(put("/api/itineraries/{itineraryId}/days/{dayId}/activities/{activityId}",
                        testItinerary.getItineraryId(), testDay.getDayId(), activity.getActivityId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(updateRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.destination").doesNotExist())
                .andExpect(jsonPath("$.customLocationName").doesNotExist())
                .andExpect(jsonPath("$.latitude").doesNotExist())
                .andExpect(jsonPath("$.longitude").doesNotExist());

        Activity updated = activityRepository.findById(activity.getActivityId()).orElseThrow();
        assertNull(updated.getDestination());
        assertNull(updated.getCustomLocationName());
        assertNull(updated.getLatitude());
        assertNull(updated.getLongitude());
    }

    // ==========================================
    // 4. BACKWARD COMPATIBILITY WITH EXISTING RECORDS
    // ==========================================

    @Test
    @DisplayName("Backward Compatibility: Existing activity with null custom-location fields retrieves cleanly")
    void existingActivityWithNullCustomFields_retrievedSuccessfully() throws Exception {
        // Simulate pre-Phase-1 record in database (no custom location fields)
        Activity prePhase1Activity = activityRepository.save(Activity.builder()
                .itineraryDay(testDay)
                .destination(activeDestination)
                .name("Hoạt động thời kỳ cũ")
                .description("Không có trường tọa độ tùy chỉnh")
                .displayOrder(1)
                .build());

        mockMvc.perform(get("/api/itineraries/{id}", testItinerary.getItineraryId())
                        .header("Authorization", ownerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.days[0].activities[0].activityId").value(prePhase1Activity.getActivityId()))
                .andExpect(jsonPath("$.days[0].activities[0].name").value("Hoạt động thời kỳ cũ"))
                .andExpect(jsonPath("$.days[0].activities[0].destination.destinationId").value(activeDestination.getDestinationId()))
                .andExpect(jsonPath("$.days[0].activities[0].customLocationName").doesNotExist())
                .andExpect(jsonPath("$.days[0].activities[0].latitude").doesNotExist())
                .andExpect(jsonPath("$.days[0].activities[0].longitude").doesNotExist());
    }

    // ==========================================
    // 5. AUTHORIZATION & ITINERARY/DAY CONSISTENCY
    // ==========================================

    @Test
    @DisplayName("Authorization: Non-owner cannot add activity to another user's itinerary (HTTP 403)")
    void createActivity_nonOwner_forbidden() throws Exception {
        CreateActivityRequest request = CreateActivityRequest.builder()
                .name("Can thiệp trái phép")
                .destinationId(activeDestination.getDestinationId())
                .build();

        mockMvc.perform(post("/api/itineraries/{itineraryId}/days/{dayId}/activities",
                        testItinerary.getItineraryId(), testDay.getDayId())
                        .header("Authorization", otherToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("Consistency: Day not belonging to itinerary is rejected with HTTP 404")
    void createActivity_dayMismatch_notFound() throws Exception {
        Itinerary anotherItinerary = itineraryRepository.save(Itinerary.builder()
                .user(ownerUser)
                .title("Lịch trình khác của cùng tác giả")
                .location("Đà Nẵng")
                .totalDays(3)
                .status(ItineraryStatus.ACTIVE)
                .build());

        CreateActivityRequest request = CreateActivityRequest.builder()
                .name("Hoạt động cấy ghép sai ngày")
                .destinationId(activeDestination.getDestinationId())
                .build();

        // Pass anotherItinerary.getId with testDay.getId (which belongs to testItinerary)
        mockMvc.perform(post("/api/itineraries/{itineraryId}/days/{dayId}/activities",
                        anotherItinerary.getItineraryId(), testDay.getDayId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("Security: Unauthenticated request to add activity is rejected with HTTP 401")
    void createActivity_unauthenticated_unauthorized() throws Exception {
        CreateActivityRequest request = CreateActivityRequest.builder()
                .name("Hoạt động ẩn danh")
                .destinationId(activeDestination.getDestinationId())
                .build();

        mockMvc.perform(post("/api/itineraries/{itineraryId}/days/{dayId}/activities",
                        testItinerary.getItineraryId(), testDay.getDayId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isUnauthorized());
    }
}
