package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.SavePlaceToItineraryRequest;
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
import java.util.Optional;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
class ItineraryPlaceTest {

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

    private Place activePlace1;
    private Place activePlace2;
    private Place hiddenPlace;

    private Itinerary publicItinerary;
    private Itinerary privateItinerary;

    @BeforeEach
    void setUp() {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        cleanupDatabase();

        ownerUser = userRepository.save(User.builder()
                .username("itinerary_place_owner")
                .password(passwordEncoder.encode("Password123!"))
                .email("itinerary_place_owner@example.com")
                .fullName("Chủ Lịch Trình")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        otherUser = userRepository.save(User.builder()
                .username("itinerary_place_other")
                .password(passwordEncoder.encode("Password123!"))
                .email("itinerary_place_other@example.com")
                .fullName("Người Dùng Khác")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        ownerToken = "Bearer " + jwtTokenProvider.generateToken(ownerUser);
        otherToken = "Bearer " + jwtTokenProvider.generateToken(otherUser);

        activePlace1 = placeRepository.save(Place.builder()
                .name("Chợ Bến Thành")
                .address("Đường Lê Lợi, Phường Bến Thành, Quận 1, TP. Hồ Chí Minh")
                .description("Khu chợ biểu tượng của Sài Gòn")
                .category(PlaceCategory.SHOPPING)
                .latitude(new BigDecimal("10.7725"))
                .longitude(new BigDecimal("106.6980"))
                .status(PlaceStatus.ACTIVE)
                .build());

        activePlace2 = placeRepository.save(Place.builder()
                .name("Nhà thờ Đức Bà")
                .address("Số 1 Công xã Paris, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh")
                .description("Nhà thờ chính tòa cổ kính")
                .category(PlaceCategory.ATTRACTION)
                .latitude(new BigDecimal("10.7798"))
                .longitude(new BigDecimal("106.6990"))
                .status(PlaceStatus.ACTIVE)
                .build());

        hiddenPlace = placeRepository.save(Place.builder()
                .name("Địa điểm đã đóng cửa")
                .address("Quận 1, TP. Hồ Chí Minh")
                .description("Không còn hoạt động")
                .category(PlaceCategory.OTHER)
                .latitude(new BigDecimal("10.7700"))
                .longitude(new BigDecimal("106.6900"))
                .status(PlaceStatus.HIDDEN)
                .build());

        publicItinerary = itineraryRepository.save(Itinerary.builder()
                .title("Khám phá Sài Gòn Công Khai")
                .description("Hành trình dạo quanh Sài Gòn")
                .location("TP. Hồ Chí Minh")
                .user(ownerUser)
                .status(ItineraryStatus.ACTIVE)
                .visibility(Visibility.PUBLIC)
                .totalDays(2)
                .build());

        privateItinerary = itineraryRepository.save(Itinerary.builder()
                .title("Hành Trình Bí Mật Riêng Tư")
                .description("Chỉ chủ sở hữu được xem")
                .location("TP. Hồ Chí Minh")
                .user(ownerUser)
                .status(ItineraryStatus.ACTIVE)
                .visibility(Visibility.PRIVATE)
                .totalDays(1)
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
        itineraryRepository.deleteAll();
        placeRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    @DisplayName("1. Save place to itinerary successfully (201 Created)")
    void testSavePlace_Success() throws Exception {
        SavePlaceToItineraryRequest req = SavePlaceToItineraryRequest.builder()
                .placeId(activePlace1.getPlaceId())
                .build();

        mockMvc.perform(post("/api/itineraries/" + publicItinerary.getItineraryId() + "/places")
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.itineraryId").value(publicItinerary.getItineraryId()))
                .andExpect(jsonPath("$.place.placeId").value(activePlace1.getPlaceId()))
                .andExpect(jsonPath("$.place.name").value("Chợ Bến Thành"))
                .andExpect(jsonPath("$.savedAt").isNotEmpty());

        assertTrue(itineraryPlaceRepository.existsByItinerary_ItineraryIdAndPlace_PlaceId(
                publicItinerary.getItineraryId(), activePlace1.getPlaceId()));
    }

    @Test
    @DisplayName("2. Get saved places in itinerary with pagination (200 OK)")
    void testGetSavedPlaces_Success() throws Exception {
        savePlaceDirectly(publicItinerary, activePlace1);
        savePlaceDirectly(publicItinerary, activePlace2);

        mockMvc.perform(get("/api/itineraries/" + publicItinerary.getItineraryId() + "/places")
                        .param("page", "0")
                        .param("size", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(2))
                .andExpect(jsonPath("$.content", hasSize(2)));
    }

    @Test
    @DisplayName("3. Get all saved places in itinerary unpaginated (200 OK)")
    void testGetAllSavedPlaces_Success() throws Exception {
        savePlaceDirectly(publicItinerary, activePlace1);
        savePlaceDirectly(publicItinerary, activePlace2);

        mockMvc.perform(get("/api/itineraries/" + publicItinerary.getItineraryId() + "/places/all"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(2)))
                .andExpect(jsonPath("$[0].place.placeId").exists());
    }

    @Test
    @DisplayName("4. Remove place from itinerary association successfully (200 OK)")
    void testRemovePlace_Success() throws Exception {
        savePlaceDirectly(publicItinerary, activePlace1);
        assertTrue(itineraryPlaceRepository.existsByItinerary_ItineraryIdAndPlace_PlaceId(
                publicItinerary.getItineraryId(), activePlace1.getPlaceId()));

        mockMvc.perform(delete("/api/itineraries/" + publicItinerary.getItineraryId() + "/places/" + activePlace1.getPlaceId())
                        .header("Authorization", ownerToken))
                .andExpect(status().isOk());

        assertFalse(itineraryPlaceRepository.existsByItinerary_ItineraryIdAndPlace_PlaceId(
                publicItinerary.getItineraryId(), activePlace1.getPlaceId()));
    }

    @Test
    @DisplayName("5. Save duplicate place into same itinerary rejected with 409 Conflict")
    void testSavePlace_DuplicateConflict_Throws409() throws Exception {
        savePlaceDirectly(publicItinerary, activePlace1);

        SavePlaceToItineraryRequest req = SavePlaceToItineraryRequest.builder()
                .placeId(activePlace1.getPlaceId())
                .build();

        mockMvc.perform(post("/api/itineraries/" + publicItinerary.getItineraryId() + "/places")
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isConflict());
    }

    @Test
    @DisplayName("6. Same place can be saved into multiple different itineraries independently")
    void testSamePlaceInMultipleItineraries() throws Exception {
        Itinerary anotherItinerary = itineraryRepository.save(Itinerary.builder()
                .title("Lịch trình thứ hai")
                .description("Hành trình khác")
                .location("TP. Hồ Chí Minh")
                .user(ownerUser)
                .status(ItineraryStatus.ACTIVE)
                .visibility(Visibility.PUBLIC)
                .totalDays(1)
                .build());

        SavePlaceToItineraryRequest req = SavePlaceToItineraryRequest.builder()
                .placeId(activePlace1.getPlaceId())
                .build();

        mockMvc.perform(post("/api/itineraries/" + publicItinerary.getItineraryId() + "/places")
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/api/itineraries/" + anotherItinerary.getItineraryId() + "/places")
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isCreated());

        assertTrue(itineraryPlaceRepository.existsByItinerary_ItineraryIdAndPlace_PlaceId(
                publicItinerary.getItineraryId(), activePlace1.getPlaceId()));
        assertTrue(itineraryPlaceRepository.existsByItinerary_ItineraryIdAndPlace_PlaceId(
                anotherItinerary.getItineraryId(), activePlace1.getPlaceId()));
    }

    @Test
    @DisplayName("7. An itinerary can save multiple distinct places")
    void testItineraryMultiplePlaces() throws Exception {
        savePlaceDirectly(publicItinerary, activePlace1);
        savePlaceDirectly(publicItinerary, activePlace2);

        assertEquals(2, itineraryPlaceRepository.countByItinerary_ItineraryId(publicItinerary.getItineraryId()));
    }

    @Test
    @DisplayName("8. Non-owner cannot save place to itinerary (403 Forbidden)")
    void testSavePlace_Unauthorized_NonOwner_Throws403() throws Exception {
        SavePlaceToItineraryRequest req = SavePlaceToItineraryRequest.builder()
                .placeId(activePlace1.getPlaceId())
                .build();

        mockMvc.perform(post("/api/itineraries/" + publicItinerary.getItineraryId() + "/places")
                        .header("Authorization", otherToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("9. Non-owner cannot remove place from itinerary (403 Forbidden)")
    void testRemovePlace_Unauthorized_NonOwner_Throws403() throws Exception {
        savePlaceDirectly(publicItinerary, activePlace1);

        mockMvc.perform(delete("/api/itineraries/" + publicItinerary.getItineraryId() + "/places/" + activePlace1.getPlaceId())
                        .header("Authorization", otherToken))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("10. Anonymous request cannot add place to itinerary (401 Unauthorized)")
    void testSavePlace_Anonymous_Throws401() throws Exception {
        SavePlaceToItineraryRequest req = SavePlaceToItineraryRequest.builder()
                .placeId(activePlace1.getPlaceId())
                .build();

        mockMvc.perform(post("/api/itineraries/" + publicItinerary.getItineraryId() + "/places")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("11. Anonymous request cannot remove place from itinerary (401 Unauthorized)")
    void testRemovePlace_Anonymous_Throws401() throws Exception {
        mockMvc.perform(delete("/api/itineraries/" + publicItinerary.getItineraryId() + "/places/" + activePlace1.getPlaceId()))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("12. Saving to non-existent itinerary returns 404 Not Found")
    void testSavePlace_ItineraryNotFound_Throws404() throws Exception {
        SavePlaceToItineraryRequest req = SavePlaceToItineraryRequest.builder()
                .placeId(activePlace1.getPlaceId())
                .build();

        mockMvc.perform(post("/api/itineraries/999999/places")
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("13. Saving non-existent place returns 404 Not Found")
    void testSavePlace_PlaceNotFound_Throws404() throws Exception {
        SavePlaceToItineraryRequest req = SavePlaceToItineraryRequest.builder()
                .placeId(999999L)
                .build();

        mockMvc.perform(post("/api/itineraries/" + publicItinerary.getItineraryId() + "/places")
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("14. Saving inactive or hidden place returns 400 Bad Request")
    void testSavePlace_PlaceInactiveOrHidden_Throws400() throws Exception {
        SavePlaceToItineraryRequest req = SavePlaceToItineraryRequest.builder()
                .placeId(hiddenPlace.getPlaceId())
                .build();

        mockMvc.perform(post("/api/itineraries/" + publicItinerary.getItineraryId() + "/places")
                        .header("Authorization", ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("15. Removing a place not saved in itinerary returns 404 Not Found")
    void testRemovePlace_NotSaved_Throws404() throws Exception {
        mockMvc.perform(delete("/api/itineraries/" + publicItinerary.getItineraryId() + "/places/" + activePlace2.getPlaceId())
                        .header("Authorization", ownerToken))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("16. Deleting itinerary place association does NOT delete the Place entity")
    void testDeleteItineraryPlace_DoesNotDeletePlaceEntity() throws Exception {
        savePlaceDirectly(publicItinerary, activePlace1);

        mockMvc.perform(delete("/api/itineraries/" + publicItinerary.getItineraryId() + "/places/" + activePlace1.getPlaceId())
                        .header("Authorization", ownerToken))
                .andExpect(status().isOk());

        // Verify Place entity still exists in the database
        Optional<Place> placeAfterDelete = placeRepository.findById(activePlace1.getPlaceId());
        assertTrue(placeAfterDelete.isPresent(), "Bản ghi Place vẫn phải tồn tại sau khi gỡ khỏi lịch trình");
        assertEquals(PlaceStatus.ACTIVE, placeAfterDelete.get().getStatus());
    }

    @Test
    @DisplayName("17. Deleting itinerary place association does NOT delete or alter any Activity or its canonical_place_id")
    void testDeleteItineraryPlace_DoesNotAlterActivity() throws Exception {
        // Create an ItineraryDay and an Activity referencing activePlace1
        ItineraryDay day = itineraryDayRepository.save(ItineraryDay.builder()
                .itinerary(publicItinerary)
                .dayNumber(1)
                .date(LocalDate.now())
                .build());

        Activity activity = activityRepository.save(Activity.builder()
                .itineraryDay(day)
                .place(activePlace1)
                .name("Tham quan Chợ Bến Thành")
                .description("Mua sắm đặc sản")
                .startTime(LocalTime.of(9, 0))
                .endTime(LocalTime.of(11, 0))
                .cost(new BigDecimal("100000.00"))
                .displayOrder(1)
                .build());

        // Save activePlace1 to itinerary places
        savePlaceDirectly(publicItinerary, activePlace1);

        // Remove activePlace1 from itinerary places
        mockMvc.perform(delete("/api/itineraries/" + publicItinerary.getItineraryId() + "/places/" + activePlace1.getPlaceId())
                        .header("Authorization", ownerToken))
                .andExpect(status().isOk());

        // Verify activity still exists and still points to activePlace1
        Optional<Activity> activityAfter = activityRepository.findById(activity.getActivityId());
        assertTrue(activityAfter.isPresent(), "Activity vẫn phải tồn tại sau khi gỡ địa điểm lưu");
        assertNotNull(activityAfter.get().getPlace(), "canonical_place_id của Activity không được bị ảnh hưởng");
        assertEquals(activePlace1.getPlaceId(), activityAfter.get().getPlace().getPlaceId());
    }

    @Test
    @DisplayName("18. Removing saved place from Itinerary A does NOT affect Itinerary B")
    void testDeleteItineraryPlace_DoesNotAffectOtherItineraries() throws Exception {
        Itinerary itineraryB = itineraryRepository.save(Itinerary.builder()
                .title("Lịch trình B")
                .description("Hành trình của người dùng khác")
                .location("TP. Hồ Chí Minh")
                .user(otherUser)
                .status(ItineraryStatus.ACTIVE)
                .visibility(Visibility.PUBLIC)
                .totalDays(1)
                .build());

        savePlaceDirectly(publicItinerary, activePlace1);
        savePlaceDirectly(itineraryB, activePlace1);

        // Delete from Itinerary A
        mockMvc.perform(delete("/api/itineraries/" + publicItinerary.getItineraryId() + "/places/" + activePlace1.getPlaceId())
                        .header("Authorization", ownerToken))
                .andExpect(status().isOk());

        // Association in Itinerary A is deleted
        assertFalse(itineraryPlaceRepository.existsByItinerary_ItineraryIdAndPlace_PlaceId(
                publicItinerary.getItineraryId(), activePlace1.getPlaceId()));

        // Association in Itinerary B remains fully intact!
        assertTrue(itineraryPlaceRepository.existsByItinerary_ItineraryIdAndPlace_PlaceId(
                itineraryB.getItineraryId(), activePlace1.getPlaceId()));
    }

    @Test
    @DisplayName("19. Private itinerary saved places access control: owner can view, non-owner and anonymous are forbidden")
    void testGetSavedPlaces_PrivateItineraryAccessControl() throws Exception {
        savePlaceDirectly(privateItinerary, activePlace1);

        // Owner can view
        mockMvc.perform(get("/api/itineraries/" + privateItinerary.getItineraryId() + "/places")
                        .header("Authorization", ownerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1));

        // Non-owner gets 403 Forbidden
        mockMvc.perform(get("/api/itineraries/" + privateItinerary.getItineraryId() + "/places")
                        .header("Authorization", otherToken))
                .andExpect(status().isForbidden());

        // Anonymous gets 403 Forbidden
        mockMvc.perform(get("/api/itineraries/" + privateItinerary.getItineraryId() + "/places"))
                .andExpect(status().isForbidden());
    }

    private void savePlaceDirectly(Itinerary itinerary, Place place) {
        itineraryPlaceRepository.save(ItineraryPlace.builder()
                .itinerary(itinerary)
                .place(place)
                .build());
    }
}
