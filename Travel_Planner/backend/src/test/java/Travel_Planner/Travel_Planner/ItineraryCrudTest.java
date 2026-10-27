package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.*;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.*;
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
import java.util.List;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
class ItineraryCrudTest {

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
    private RatingRepository ratingRepository;

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

    @BeforeEach
    void setUp() {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        objectMapper.registerModule(new com.fasterxml.jackson.datatype.jsr310.JavaTimeModule());
        objectMapper.disable(com.fasterxml.jackson.databind.SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

        cleanupDatabase();

        ownerUser = userRepository.save(User.builder()
                .username("itinerary_owner")
                .password(passwordEncoder.encode("Password123!"))
                .email("owner@example.com")
                .fullName("Chủ Lịch Trình")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        otherUser = userRepository.save(User.builder()
                .username("itinerary_other")
                .password(passwordEncoder.encode("Password123!"))
                .email("other@example.com")
                .fullName("Người Dùng Khác")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        ownerToken = "Bearer " + jwtTokenProvider.generateToken(ownerUser);
        otherToken = "Bearer " + jwtTokenProvider.generateToken(otherUser);

        activeDestination = destinationRepository.save(Destination.builder()
                .name("Hồ Xuân Hương")
                .address("Trung tâm TP. Đà Lạt")
                .description("Hồ nước đẹp giữa lòng Đà Lạt")
                .latitude(new BigDecimal("11.9404192"))
                .longitude(new BigDecimal("108.4583132"))
                .status(DestinationStatus.ACTIVE)
                .build());
    }

    @AfterEach
    void tearDown() {
        cleanupDatabase();
    }

    private void cleanupDatabase() {
        activityRepository.deleteAll();
        itineraryDayRepository.deleteAll();
        ratingRepository.deleteAll();
        itineraryRepository.deleteAll();
        destinationRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    @DisplayName("1. Unauthenticated users cannot access protected CRUD endpoints (401)")
    void testUnauthenticatedAccessRejected() throws Exception {
        mockMvc.perform(get("/api/user/itineraries"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(post("/api/itineraries")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(put("/api/itineraries/1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(delete("/api/itineraries/1"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("2. Create itinerary successfully with auto-generated initial days (201)")
    void testCreateItinerarySuccess() throws Exception {
        CreateItineraryRequest request = CreateItineraryRequest.builder()
                .title("Du lịch Đà Lạt 3N2Đ")
                .description("Lịch trình thư giãn nghỉ dưỡng")
                .location("Đà Lạt")
                .coverImage("https://example.com/dalat.jpg")
                .totalDays(3)
                .budget(new BigDecimal("4500000.00"))
                .theme("Nghỉ dưỡng")
                .visibility(Visibility.PRIVATE)
                .build();

        mockMvc.perform(post("/api/itineraries")
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.itineraryId").isNumber())
                .andExpect(jsonPath("$.title").value("Du lịch Đà Lạt 3N2Đ"))
                .andExpect(jsonPath("$.location").value("Đà Lạt"))
                .andExpect(jsonPath("$.totalDays").value(3))
                .andExpect(jsonPath("$.visibility").value("PRIVATE"))
                .andExpect(jsonPath("$.creator.username").value("itinerary_owner"))
                .andExpect(jsonPath("$.days", hasSize(3)))
                .andExpect(jsonPath("$.days[0].dayNumber").value(1))
                .andExpect(jsonPath("$.days[1].dayNumber").value(2))
                .andExpect(jsonPath("$.days[2].dayNumber").value(3));

        // Verify in database
        List<Itinerary> list = itineraryRepository.findAll();
        assertEquals(1, list.size());
        User owner = userRepository.findById(list.get(0).getUser().getUserId()).orElseThrow();
        assertEquals("itinerary_owner", owner.getUsername());

        List<ItineraryDay> days = itineraryDayRepository.findByItinerary_ItineraryIdOrderByDayNumberAsc(list.get(0).getItineraryId());
        assertEquals(3, days.size());
    }

    @Test
    @DisplayName("3. Create itinerary validation errors (400)")
    void testCreateItineraryValidationErrors() throws Exception {
        // Blank title and negative budget
        CreateItineraryRequest request = CreateItineraryRequest.builder()
                .title("")
                .location("Đà Lạt")
                .totalDays(0) // < 1
                .budget(new BigDecimal("-1000"))
                .build();

        mockMvc.perform(post("/api/itineraries")
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.validationErrors.title").exists())
                .andExpect(jsonPath("$.validationErrors.totalDays").exists())
                .andExpect(jsonPath("$.validationErrors.budget").exists());
    }

    @Test
    @DisplayName("4. Get user's itineraries returns only current user's trips")
    void testGetMyItineraries() throws Exception {
        // Create 2 trips for owner (1 public, 1 private)
        Itinerary trip1 = itineraryRepository.save(Itinerary.builder()
                .title("Trip Public Owner")
                .location("Hà Nội")
                .totalDays(2)
                .budget(new BigDecimal("2000000"))
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .user(ownerUser)
                .build());

        Itinerary trip2 = itineraryRepository.save(Itinerary.builder()
                .title("Trip Private Owner")
                .location("Sài Gòn")
                .totalDays(3)
                .budget(new BigDecimal("3000000"))
                .visibility(Visibility.PRIVATE)
                .status(ItineraryStatus.ACTIVE)
                .user(ownerUser)
                .build());

        // Create 1 trip for otherUser
        itineraryRepository.save(Itinerary.builder()
                .title("Trip Other User")
                .location("Đà Nẵng")
                .totalDays(4)
                .budget(new BigDecimal("4000000"))
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .user(otherUser)
                .build());

        // Owner queries their itineraries
        mockMvc.perform(get("/api/user/itineraries")
                        .header("Authorization", ownerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(2))
                .andExpect(jsonPath("$.content", hasSize(2)))
                .andExpect(jsonPath("$.content[*].title", containsInAnyOrder("Trip Public Owner", "Trip Private Owner")));

        // Filter by visibility=PRIVATE
        mockMvc.perform(get("/api/user/itineraries")
                        .header("Authorization", ownerToken)
                        .param("visibility", "PRIVATE"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Trip Private Owner"));
    }

    @Test
    @DisplayName("5. Update itinerary by owner succeeds; non-owner is rejected with 403")
    void testUpdateItineraryOwnership() throws Exception {
        Itinerary trip = itineraryRepository.save(Itinerary.builder()
                .title("Trip Gốc")
                .location("Hội An")
                .totalDays(2)
                .budget(new BigDecimal("2000000"))
                .visibility(Visibility.PRIVATE)
                .status(ItineraryStatus.ACTIVE)
                .user(ownerUser)
                .build());

        UpdateItineraryRequest updateRequest = UpdateItineraryRequest.builder()
                .title("Trip Đã Cập Nhật")
                .location("Hội An & Đà Nẵng")
                .budget(new BigDecimal("2500000"))
                .visibility(Visibility.PUBLIC)
                .build();

        // 1. Non-owner cannot update (403 Forbidden)
        mockMvc.perform(put("/api/itineraries/" + trip.getItineraryId())
                        .header("Authorization", otherToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(updateRequest)))
                .andExpect(status().isForbidden());

        // 2. Owner updates successfully (200 OK)
        mockMvc.perform(put("/api/itineraries/" + trip.getItineraryId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(updateRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Trip Đã Cập Nhật"))
                .andExpect(jsonPath("$.location").value("Hội An & Đà Nẵng"))
                .andExpect(jsonPath("$.visibility").value("PUBLIC"));
    }

    @Test
    @DisplayName("6. Soft delete itinerary: excluded from Explore and Detail returns 404")
    void testSoftDeleteItinerary() throws Exception {
        Itinerary trip = itineraryRepository.save(Itinerary.builder()
                .title("Trip Cần Xóa")
                .location("Huế")
                .totalDays(2)
                .budget(new BigDecimal("1500000"))
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .user(ownerUser)
                .build());

        // Non-owner cannot delete (403)
        mockMvc.perform(delete("/api/itineraries/" + trip.getItineraryId())
                        .header("Authorization", otherToken))
                .andExpect(status().isForbidden());

        // Owner deletes (200 OK)
        mockMvc.perform(delete("/api/itineraries/" + trip.getItineraryId())
                        .header("Authorization", ownerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Đã xóa lịch trình thành công"));

        // Verify status is DELETED in DB
        Itinerary deletedTrip = itineraryRepository.findById(trip.getItineraryId()).orElseThrow();
        assertEquals(ItineraryStatus.DELETED, deletedTrip.getStatus());

        // Explore API excludes deleted trip
        mockMvc.perform(get("/api/itineraries").param("keyword", "Huế"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(0));

        // Detail API returns 404 for deleted trip
        mockMvc.perform(get("/api/itineraries/" + trip.getItineraryId()))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("7. Add, update, and delete days with automatic totalDays synchronization")
    void testDayManagement() throws Exception {
        Itinerary trip = itineraryRepository.save(Itinerary.builder()
                .title("Trip Quản Lý Ngày")
                .location("Sa Pa")
                .totalDays(2)
                .budget(new BigDecimal("3000000"))
                .visibility(Visibility.PRIVATE)
                .status(ItineraryStatus.ACTIVE)
                .user(ownerUser)
                .build());

        ItineraryDay day1 = itineraryDayRepository.save(ItineraryDay.builder()
                .itinerary(trip).dayNumber(1).title("Ngày 1").build());
        ItineraryDay day2 = itineraryDayRepository.save(ItineraryDay.builder()
                .itinerary(trip).dayNumber(2).title("Ngày 2").build());

        // 1. Add Day 3
        CreateDayRequest addDayReq = CreateDayRequest.builder()
                .title("Ngày 3 - Khám phá Fansipan")
                .date(LocalDate.of(2026, 12, 1))
                .build();

        mockMvc.perform(post("/api/itineraries/" + trip.getItineraryId() + "/days")
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(addDayReq)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.dayNumber").value(3))
                .andExpect(jsonPath("$.title").value("Ngày 3 - Khám phá Fansipan"));

        Itinerary reloadedTrip = itineraryRepository.findById(trip.getItineraryId()).orElseThrow();
        assertEquals(3, reloadedTrip.getTotalDays());

        // 2. Update Day 2
        UpdateDayRequest updateDayReq = UpdateDayRequest.builder()
                .title("Ngày 2 - Bản Cát Cát")
                .date(LocalDate.of(2026, 11, 30))
                .build();

        mockMvc.perform(put("/api/itineraries/" + trip.getItineraryId() + "/days/" + day2.getDayId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(updateDayReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Ngày 2 - Bản Cát Cát"));

        // 3. Delete Day 2 (day 3 should be renumbered to 2, totalDays becomes 2)
        mockMvc.perform(delete("/api/itineraries/" + trip.getItineraryId() + "/days/" + day2.getDayId())
                        .header("Authorization", ownerToken))
                .andExpect(status().isOk());

        reloadedTrip = itineraryRepository.findById(trip.getItineraryId()).orElseThrow();
        assertEquals(2, reloadedTrip.getTotalDays());

        List<ItineraryDay> remainingDays = itineraryDayRepository.findByItinerary_ItineraryIdOrderByDayNumberAsc(trip.getItineraryId());
        assertEquals(2, remainingDays.size());
        assertEquals(1, remainingDays.get(0).getDayNumber());
        assertEquals(2, remainingDays.get(1).getDayNumber());
        assertEquals("Ngày 3 - Khám phá Fansipan", remainingDays.get(1).getTitle());
    }

    @Test
    @DisplayName("8. Cannot delete the only remaining day (totalDays <= 1 returns 400)")
    void testCannotDeleteLastDay() throws Exception {
        Itinerary trip = itineraryRepository.save(Itinerary.builder()
                .title("Trip 1 Ngày")
                .location("Vũng Tàu")
                .totalDays(1)
                .budget(new BigDecimal("1000000"))
                .visibility(Visibility.PRIVATE)
                .status(ItineraryStatus.ACTIVE)
                .user(ownerUser)
                .build());

        ItineraryDay day1 = itineraryDayRepository.save(ItineraryDay.builder()
                .itinerary(trip).dayNumber(1).title("Ngày 1").build());

        mockMvc.perform(delete("/api/itineraries/" + trip.getItineraryId() + "/days/" + day1.getDayId())
                        .header("Authorization", ownerToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(containsString("ít nhất 1 ngày")));
    }

    @Test
    @DisplayName("9. Add activity with destination AND activity without destination (null destinationId supported)")
    void testActivityWithAndWithoutDestination() throws Exception {
        Itinerary trip = itineraryRepository.save(Itinerary.builder()
                .title("Trip Hoạt Động")
                .location("Đà Lạt")
                .totalDays(1)
                .budget(new BigDecimal("2000000"))
                .visibility(Visibility.PRIVATE)
                .status(ItineraryStatus.ACTIVE)
                .user(ownerUser)
                .build());

        ItineraryDay day1 = itineraryDayRepository.save(ItineraryDay.builder()
                .itinerary(trip).dayNumber(1).title("Ngày 1").build());

        // 1. Add activity WITH destination
        CreateActivityRequest act1Req = CreateActivityRequest.builder()
                .name("Dạo bờ hồ Xuân Hương")
                .description("Ngắm cảnh và đạp vịt")
                .destinationId(activeDestination.getDestinationId())
                .startTime(LocalTime.of(8, 0))
                .endTime(LocalTime.of(10, 0))
                .cost(new BigDecimal("50000"))
                .build();

        mockMvc.perform(post("/api/itineraries/" + trip.getItineraryId() + "/days/" + day1.getDayId() + "/activities")
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(act1Req)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.name").value("Dạo bờ hồ Xuân Hương"))
                .andExpect(jsonPath("$.displayOrder").value(1))
                .andExpect(jsonPath("$.destination.name").value("Hồ Xuân Hương"));

        // 2. Add activity WITHOUT destination (null destinationId)
        CreateActivityRequest act2Req = CreateActivityRequest.builder()
                .name("Nghỉ trưa tự do tại khách sạn")
                .description("Không cần vị trí bản đồ")
                .destinationId(null)
                .startTime(LocalTime.of(12, 0))
                .endTime(LocalTime.of(13, 30))
                .cost(BigDecimal.ZERO)
                .build();

        mockMvc.perform(post("/api/itineraries/" + trip.getItineraryId() + "/days/" + day1.getDayId() + "/activities")
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(act2Req)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.name").value("Nghỉ trưa tự do tại khách sạn"))
                .andExpect(jsonPath("$.displayOrder").value(2))
                .andExpect(jsonPath("$.destination").doesNotExist());

        // Verify in database
        List<Activity> activities = activityRepository.findByItineraryDay_DayIdOrderByDisplayOrderAsc(day1.getDayId());
        assertEquals(2, activities.size());
        assertNotNull(activities.get(0).getDestination());
        assertNull(activities.get(1).getDestination());
    }

    @Test
    @DisplayName("10. Reject cross-itinerary and cross-day activity tampering (400/404)")
    void testCrossResourceTamperingRejected() throws Exception {
        Itinerary trip1 = itineraryRepository.save(Itinerary.builder()
                .title("Trip 1").location("Loc").totalDays(1).budget(BigDecimal.ZERO)
                .visibility(Visibility.PRIVATE).status(ItineraryStatus.ACTIVE).user(ownerUser).build());
        ItineraryDay day1 = itineraryDayRepository.save(ItineraryDay.builder()
                .itinerary(trip1).dayNumber(1).title("Day 1").build());

        Itinerary trip2 = itineraryRepository.save(Itinerary.builder()
                .title("Trip 2").location("Loc").totalDays(1).budget(BigDecimal.ZERO)
                .visibility(Visibility.PRIVATE).status(ItineraryStatus.ACTIVE).user(ownerUser).build());
        ItineraryDay day2 = itineraryDayRepository.save(ItineraryDay.builder()
                .itinerary(trip2).dayNumber(1).title("Day 2").build());

        Activity actInDay2 = activityRepository.save(Activity.builder()
                .itineraryDay(day2).name("Act In Day 2").cost(BigDecimal.ZERO).displayOrder(1).build());

        // Attempt to update actInDay2 through trip1/day1 path
        UpdateActivityRequest req = UpdateActivityRequest.builder().name("Hack Name").build();
        mockMvc.perform(put("/api/itineraries/" + trip1.getItineraryId() + "/days/" + day1.getDayId() + "/activities/" + actInDay2.getActivityId())
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("11. Two-pass activity reordering successfully avoids unique key collisions on (day_id, display_order)")
    void testReorderActivitiesSuccess() throws Exception {
        Itinerary trip = itineraryRepository.save(Itinerary.builder()
                .title("Trip Sắp Xếp").location("Loc").totalDays(1).budget(BigDecimal.ZERO)
                .visibility(Visibility.PRIVATE).status(ItineraryStatus.ACTIVE).user(ownerUser).build());
        ItineraryDay day = itineraryDayRepository.save(ItineraryDay.builder()
                .itinerary(trip).dayNumber(1).title("Day 1").build());

        Activity act1 = activityRepository.save(Activity.builder()
                .itineraryDay(day).name("Act 1").cost(BigDecimal.ZERO).displayOrder(1).build());
        Activity act2 = activityRepository.save(Activity.builder()
                .itineraryDay(day).name("Act 2").cost(BigDecimal.ZERO).displayOrder(2).build());
        Activity act3 = activityRepository.save(Activity.builder()
                .itineraryDay(day).name("Act 3").cost(BigDecimal.ZERO).displayOrder(3).build());

        // Reverse order: 1 -> 3, 2 -> 2, 3 -> 1
        List<ReorderActivityItem> items = List.of(
                new ReorderActivityItem(act1.getActivityId(), 3),
                new ReorderActivityItem(act2.getActivityId(), 2),
                new ReorderActivityItem(act3.getActivityId(), 1)
        );

        mockMvc.perform(put("/api/itineraries/" + trip.getItineraryId() + "/days/" + day.getDayId() + "/activities/reorder")
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(items)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(3)))
                .andExpect(jsonPath("$[0].name").value("Act 3"))
                .andExpect(jsonPath("$[0].displayOrder").value(1))
                .andExpect(jsonPath("$[1].name").value("Act 2"))
                .andExpect(jsonPath("$[1].displayOrder").value(2))
                .andExpect(jsonPath("$[2].name").value("Act 1"))
                .andExpect(jsonPath("$[2].displayOrder").value(3));
    }
}
