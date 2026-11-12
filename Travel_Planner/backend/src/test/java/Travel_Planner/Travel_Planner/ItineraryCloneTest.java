package Travel_Planner.Travel_Planner;

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
class ItineraryCloneTest {

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
    private PlaceRepository placeRepository;

    @Autowired
    private ItineraryPlaceRepository itineraryPlaceRepository;

    @Autowired
    private RatingRepository ratingRepository;

    @Autowired
    private FavoriteRepository favoriteRepository;

    @Autowired
    private SavedItineraryRepository savedItineraryRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private ObjectMapper objectMapper;

    private MockMvc mockMvc;

    private User sourceOwner;
    private User clonerUser;
    private User bannedUser;
    private String sourceOwnerToken;
    private String clonerToken;
    private String bannedToken;

    private Place canonicalPlace1;
    private Place canonicalPlace2;

    private Itinerary publicItinerary;
    private Itinerary privateItinerary;
    private Itinerary deletedItinerary;

    private ItineraryDay day1;
    private ItineraryDay day2;
    private Activity activity1;
    private Activity activity2;

    @BeforeEach
    void setUp() {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        cleanupDatabase();

        sourceOwner = userRepository.save(User.builder()
                .username("source_owner_user")
                .password(passwordEncoder.encode("Password123!"))
                .email("source_owner@example.com")
                .fullName("Chủ Lịch Trình Nguồn")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        clonerUser = userRepository.save(User.builder()
                .username("cloner_user")
                .password(passwordEncoder.encode("Password123!"))
                .email("cloner@example.com")
                .fullName("Người Dùng Nhân Bản")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        bannedUser = userRepository.save(User.builder()
                .username("banned_cloner_user")
                .password(passwordEncoder.encode("Password123!"))
                .email("banned@example.com")
                .fullName("Người Dùng Bị Khóa")
                .role(Role.USER)
                .status(UserStatus.BANNED)
                .build());

        sourceOwnerToken = "Bearer " + jwtTokenProvider.generateToken(sourceOwner);
        clonerToken = "Bearer " + jwtTokenProvider.generateToken(clonerUser);
        bannedToken = "Bearer " + jwtTokenProvider.generateToken(bannedUser);

        canonicalPlace1 = placeRepository.save(Place.builder()
                .name("Nhà thờ Đức Bà")
                .address("Số 1 Công xã Paris, Bến Nghé, Quận 1, TP. Hồ Chí Minh")
                .description("Nhà thờ chính tòa cổ kính")
                .category(PlaceCategory.ATTRACTION)
                .latitude(new BigDecimal("10.7798000"))
                .longitude(new BigDecimal("106.6990000"))
                .status(PlaceStatus.ACTIVE)
                .build());

        canonicalPlace2 = placeRepository.save(Place.builder()
                .name("Chợ Bến Thành")
                .address("Đường Lê Lợi, Bến Thành, Quận 1, TP. Hồ Chí Minh")
                .description("Chợ truyền thống lâu đời")
                .category(PlaceCategory.SHOPPING)
                .latitude(new BigDecimal("10.7725000"))
                .longitude(new BigDecimal("106.6980000"))
                .status(PlaceStatus.ACTIVE)
                .build());

        publicItinerary = itineraryRepository.save(Itinerary.builder()
                .title("Khám phá Sài Gòn Nắng Gió")
                .description("Hành trình khám phá các điểm nổi tiếng tại TP.HCM")
                .location("TP. Hồ Chí Minh")
                .coverImage("https://example.com/saigon.jpg")
                .totalDays(2)
                .budget(new BigDecimal("2500000.00"))
                .theme("Văn hóa & Ẩm thực")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(100)
                .favoriteCount(25)
                .ratingCount(10)
                .commentCount(5)
                .reuseCount(0)
                .user(sourceOwner)
                .build());

        privateItinerary = itineraryRepository.save(Itinerary.builder()
                .title("Hành Trình Bí Mật Của Tôi")
                .description("Kế hoạch du lịch riêng tư")
                .location("Đà Lạt")
                .totalDays(1)
                .budget(new BigDecimal("1000000.00"))
                .theme("Nghỉ dưỡng")
                .visibility(Visibility.PRIVATE)
                .status(ItineraryStatus.ACTIVE)
                .reuseCount(0)
                .user(sourceOwner)
                .build());

        deletedItinerary = itineraryRepository.save(Itinerary.builder()
                .title("Lịch Trình Đã Bị Xóa")
                .description("Đã xóa khỏi hệ thống")
                .location("Hà Nội")
                .totalDays(1)
                .budget(BigDecimal.ZERO)
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.DELETED)
                .reuseCount(0)
                .user(sourceOwner)
                .build());

        day1 = itineraryDayRepository.save(ItineraryDay.builder()
                .itinerary(publicItinerary)
                .dayNumber(1)
                .title("Ngày 1: Trung tâm Quận 1")
                .date(LocalDate.of(2026, 12, 1))
                .build());

        day2 = itineraryDayRepository.save(ItineraryDay.builder()
                .itinerary(publicItinerary)
                .dayNumber(2)
                .title("Ngày 2: Ẩm thực và Mua sắm")
                .date(LocalDate.of(2026, 12, 2))
                .build());

        activity1 = activityRepository.save(Activity.builder()
                .itineraryDay(day1)
                .place(canonicalPlace1)
                .name("Thăm Nhà thờ Đức Bà")
                .description("Chụp ảnh và tham quan kiến trúc cổ")
                .locationName("Nhà thờ Đức Bà")
                .locationAddress("Số 1 Công xã Paris, Bến Nghé, Quận 1")
                .customLocationName("Nhà thờ Đức Bà")
                .customAddress("Số 1 Công xã Paris, Bến Nghé, Quận 1")
                .latitude(new BigDecimal("10.7798000"))
                .longitude(new BigDecimal("106.6990000"))
                .placeId("place-ndb-01")
                .locationProvider("LOCATION_IQ")
                .imageUrl("https://example.com/ndb.jpg")
                .startTime(LocalTime.of(8, 30))
                .endTime(LocalTime.of(10, 0))
                .cost(BigDecimal.ZERO)
                .displayOrder(1)
                .build());

        activity2 = activityRepository.save(Activity.builder()
                .itineraryDay(day2)
                .place(canonicalPlace2)
                .name("Mua sắm tại Chợ Bến Thành")
                .description("Thưởng thức chè và mua quà lưu niệm")
                .locationName("Chợ Bến Thành")
                .locationAddress("Đường Lê Lợi, Bến Thành, Quận 1")
                .customLocationName("Chợ Bến Thành")
                .customAddress("Đường Lê Lợi, Bến Thành, Quận 1")
                .latitude(new BigDecimal("10.7725000"))
                .longitude(new BigDecimal("106.6980000"))
                .placeId("place-cbt-02")
                .locationProvider("LOCATION_IQ")
                .imageUrl("https://example.com/cbt.jpg")
                .startTime(LocalTime.of(14, 0))
                .endTime(LocalTime.of(16, 0))
                .cost(new BigDecimal("500000.00"))
                .displayOrder(1)
                .build());

        itineraryPlaceRepository.save(ItineraryPlace.builder()
                .itinerary(publicItinerary)
                .place(canonicalPlace1)
                .build());

        itineraryPlaceRepository.save(ItineraryPlace.builder()
                .itinerary(publicItinerary)
                .place(canonicalPlace2)
                .build());
    }

    @AfterEach
    void tearDown() {
        cleanupDatabase();
    }

    private void cleanupDatabase() {
        itineraryPlaceRepository.deleteAll();
        activityRepository.deleteAll();
        itineraryDayRepository.deleteAll();
        ratingRepository.deleteAll();
        favoriteRepository.deleteAll();
        savedItineraryRepository.deleteAll();
        itineraryRepository.deleteAll();
        placeRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    @DisplayName("1. Clone public itinerary succeeds (201 Created, owner is cloner, metadata copied, reuse_count incremented)")
    void testClonePublicItinerary_Success() throws Exception {
        long placeCountBefore = placeRepository.count();

        mockMvc.perform(post("/api/itineraries/" + publicItinerary.getItineraryId() + "/clone")
                        .header("Authorization", clonerToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.itineraryId").isNumber())
                .andExpect(jsonPath("$.title").value("Khám phá Sài Gòn Nắng Gió (Bản sao)"))
                .andExpect(jsonPath("$.description").value("Hành trình khám phá các điểm nổi tiếng tại TP.HCM"))
                .andExpect(jsonPath("$.location").value("TP. Hồ Chí Minh"))
                .andExpect(jsonPath("$.coverImage").value("https://example.com/saigon.jpg"))
                .andExpect(jsonPath("$.totalDays").value(2))
                .andExpect(jsonPath("$.theme").value("Văn hóa & Ẩm thực"))
                .andExpect(jsonPath("$.visibility").value("PRIVATE"))
                .andExpect(jsonPath("$.status").value("ACTIVE"))
                .andExpect(jsonPath("$.creator.username").value("cloner_user"))
                .andExpect(jsonPath("$.creator.fullName").value("Người Dùng Nhân Bản"))
                .andExpect(jsonPath("$.viewCount").value(0))
                .andExpect(jsonPath("$.favoriteCount").value(0))
                .andExpect(jsonPath("$.ratingCount").value(0))
                .andExpect(jsonPath("$.commentCount").value(0))
                .andExpect(jsonPath("$.reuseCount").value(0))
                .andExpect(jsonPath("$.originalItineraryId").value(publicItinerary.getItineraryId()))
                .andExpect(jsonPath("$.days", hasSize(2)));

        // Verify original itinerary reuse_count incremented by 1
        Itinerary updatedOriginal = itineraryRepository.findById(publicItinerary.getItineraryId()).orElseThrow();
        assertEquals(1, updatedOriginal.getReuseCount());

        // Verify zero Place entities duplicated
        assertEquals(placeCountBefore, placeRepository.count());
    }

    @Test
    @DisplayName("2. Anonymous clone rejected with 401 Unauthorized")
    void testCloneAnonymous_ReturnsUnauthorized() throws Exception {
        mockMvc.perform(post("/api/itineraries/" + publicItinerary.getItineraryId() + "/clone")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("3. Other user cloning private itinerary rejected with 403 Forbidden")
    void testClonePrivateItinerary_OtherUser_ReturnsForbidden() throws Exception {
        mockMvc.perform(post("/api/itineraries/" + privateItinerary.getItineraryId() + "/clone")
                        .header("Authorization", clonerToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isForbidden());

        // Verify original reuse_count remains 0
        Itinerary freshPrivate = itineraryRepository.findById(privateItinerary.getItineraryId()).orElseThrow();
        assertEquals(0, freshPrivate.getReuseCount());
    }

    @Test
    @DisplayName("4. Owner cloning their own private itinerary succeeds (201 Created)")
    void testClonePrivateItinerary_Owner_Success() throws Exception {
        mockMvc.perform(post("/api/itineraries/" + privateItinerary.getItineraryId() + "/clone")
                        .header("Authorization", sourceOwnerToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.title").value("Hành Trình Bí Mật Của Tôi (Bản sao)"))
                .andExpect(jsonPath("$.creator.username").value("source_owner_user"))
                .andExpect(jsonPath("$.visibility").value("PRIVATE"))
                .andExpect(jsonPath("$.originalItineraryId").value(privateItinerary.getItineraryId()));

        Itinerary freshPrivate = itineraryRepository.findById(privateItinerary.getItineraryId()).orElseThrow();
        assertEquals(1, freshPrivate.getReuseCount());
    }

    @Test
    @DisplayName("5. Clone non-existent itinerary returns 404 Not Found")
    void testCloneNonExistent_ReturnsNotFound() throws Exception {
        mockMvc.perform(post("/api/itineraries/999999/clone")
                        .header("Authorization", clonerToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("6. Clone deleted itinerary returns 404 Not Found")
    void testCloneDeleted_ReturnsNotFound() throws Exception {
        mockMvc.perform(post("/api/itineraries/" + deletedItinerary.getItineraryId() + "/clone")
                        .header("Authorization", clonerToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("7. Banned user attempting to clone is rejected (401 Unauthorized due to locked account)")
    void testCloneBannedUser_ReturnsUnauthorized() throws Exception {
        mockMvc.perform(post("/api/itineraries/" + publicItinerary.getItineraryId() + "/clone")
                        .header("Authorization", bannedToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("8. Days and activities are copied as independent entities with identical contents")
    void testCloneDaysAndActivities_DeepCopy() throws Exception {
        String responseContent = mockMvc.perform(post("/api/itineraries/" + publicItinerary.getItineraryId() + "/clone")
                        .header("Authorization", clonerToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();

        Integer clonedItineraryId = objectMapper.readTree(responseContent).get("itineraryId").asInt();
        assertNotEquals(publicItinerary.getItineraryId(), clonedItineraryId);

        List<ItineraryDay> clonedDays = itineraryDayRepository.findByItinerary_ItineraryIdOrderByDayNumberAsc(clonedItineraryId);
        assertEquals(2, clonedDays.size());

        ItineraryDay cDay1 = clonedDays.get(0);
        ItineraryDay cDay2 = clonedDays.get(1);
        assertNotEquals(day1.getDayId(), cDay1.getDayId());
        assertNotEquals(day2.getDayId(), cDay2.getDayId());
        assertEquals(1, cDay1.getDayNumber());
        assertEquals(2, cDay2.getDayNumber());
        assertEquals("Ngày 1: Trung tâm Quận 1", cDay1.getTitle());
        assertEquals("Ngày 2: Ẩm thực và Mua sắm", cDay2.getTitle());

        List<Activity> cActivitiesDay1 = activityRepository.findByItineraryDay_DayIdOrderByDisplayOrderAsc(cDay1.getDayId());
        assertEquals(1, cActivitiesDay1.size());
        Activity cAct1 = cActivitiesDay1.get(0);
        assertNotEquals(activity1.getActivityId(), cAct1.getActivityId());
        assertEquals("Thăm Nhà thờ Đức Bà", cAct1.getName());
        assertEquals(canonicalPlace1.getPlaceId(), cAct1.getPlace().getPlaceId());

        List<Activity> cActivitiesDay2 = activityRepository.findByItineraryDay_DayIdOrderByDisplayOrderAsc(cDay2.getDayId());
        assertEquals(1, cActivitiesDay2.size());
        Activity cAct2 = cActivitiesDay2.get(0);
        assertNotEquals(activity2.getActivityId(), cAct2.getActivityId());
        assertEquals("Mua sắm tại Chợ Bến Thành", cAct2.getName());
        assertEquals(canonicalPlace2.getPlaceId(), cAct2.getPlace().getPlaceId());
    }

    @Test
    @DisplayName("9. Canonical place associations in itinerary_places are cloned without duplicating Place rows")
    void testCloneItineraryPlaces_PreservedWithoutDuplicatingPlaces() throws Exception {
        long placeCountBefore = placeRepository.count();

        String responseContent = mockMvc.perform(post("/api/itineraries/" + publicItinerary.getItineraryId() + "/clone")
                        .header("Authorization", clonerToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();

        Integer clonedItineraryId = objectMapper.readTree(responseContent).get("itineraryId").asInt();

        // Check places table count remains identical
        assertEquals(placeCountBefore, placeRepository.count());

        // Check itinerary_places entries for cloned itinerary
        List<ItineraryPlace> clonedPlaces = itineraryPlaceRepository.findAllByItineraryIdWithPlace(clonedItineraryId);
        assertEquals(2, clonedPlaces.size());
        assertTrue(clonedPlaces.stream().anyMatch(ip -> ip.getPlace().getPlaceId().equals(canonicalPlace1.getPlaceId())));
        assertTrue(clonedPlaces.stream().anyMatch(ip -> ip.getPlace().getPlaceId().equals(canonicalPlace2.getPlaceId())));
    }

    @Test
    @DisplayName("10. Deleting or modifying cloned itinerary data does not affect the original itinerary")
    void testModifyClone_DoesNotAffectOriginal() throws Exception {
        String responseContent = mockMvc.perform(post("/api/itineraries/" + publicItinerary.getItineraryId() + "/clone")
                        .header("Authorization", clonerToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();

        Integer clonedItineraryId = objectMapper.readTree(responseContent).get("itineraryId").asInt();

        // Delete cloned itinerary
        mockMvc.perform(delete("/api/itineraries/" + clonedItineraryId)
                        .header("Authorization", clonerToken))
                .andExpect(status().isOk());

        // Verify original itinerary is still ACTIVE, has 2 days, 2 activities, 2 saved places
        Itinerary originalAfter = itineraryRepository.findById(publicItinerary.getItineraryId()).orElseThrow();
        assertEquals(ItineraryStatus.ACTIVE, originalAfter.getStatus());
        assertEquals(2, itineraryDayRepository.countByItinerary_ItineraryId(publicItinerary.getItineraryId()));
        assertEquals(2, itineraryPlaceRepository.countByItinerary_ItineraryId(publicItinerary.getItineraryId()));
    }

    @Test
    @DisplayName("11. Cloning multiple times creates distinct independent itineraries and increments reuse_count each time")
    void testCloneMultipleTimes_IncrementsReuseCount() throws Exception {
        // Clone 1
        String res1 = mockMvc.perform(post("/api/itineraries/" + publicItinerary.getItineraryId() + "/clone")
                        .header("Authorization", clonerToken))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        Integer clone1Id = objectMapper.readTree(res1).get("itineraryId").asInt();

        Itinerary orig1 = itineraryRepository.findById(publicItinerary.getItineraryId()).orElseThrow();
        assertEquals(1, orig1.getReuseCount());

        // Clone 2
        String res2 = mockMvc.perform(post("/api/itineraries/" + publicItinerary.getItineraryId() + "/clone")
                        .header("Authorization", clonerToken))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        Integer clone2Id = objectMapper.readTree(res2).get("itineraryId").asInt();

        Itinerary orig2 = itineraryRepository.findById(publicItinerary.getItineraryId()).orElseThrow();
        assertEquals(2, orig2.getReuseCount());

        assertNotEquals(clone1Id, clone2Id);
    }
}

