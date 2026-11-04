package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.model.Itinerary;
import Travel_Planner.Travel_Planner.model.SavedItinerary;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;
import Travel_Planner.Travel_Planner.repository.FavoriteRepository;
import Travel_Planner.Travel_Planner.repository.ItineraryRepository;
import Travel_Planner.Travel_Planner.repository.RatingRepository;
import Travel_Planner.Travel_Planner.repository.SavedItineraryRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
class SavedItineraryControllerTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ItineraryRepository itineraryRepository;

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

    private MockMvc mockMvc;

    private User authorUser;
    private User regularUser;
    private String userToken;
    private String authorToken;
    private Itinerary publicItinerary;

    @BeforeEach
    void setUp() {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        favoriteRepository.deleteAll();
        savedItineraryRepository.deleteAll();
        ratingRepository.deleteAll();
        itineraryRepository.deleteAll();
        userRepository.deleteAll();

        authorUser = userRepository.save(User.builder()
                .username("author_save")
                .password(passwordEncoder.encode("Password123!"))
                .email("author_save@example.com")
                .fullName("Author Save")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        regularUser = userRepository.save(User.builder()
                .username("regular_save")
                .password(passwordEncoder.encode("Password123!"))
                .email("regular_save@example.com")
                .fullName("Regular User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        userToken = jwtTokenProvider.generateToken(regularUser);
        authorToken = jwtTokenProvider.generateToken(authorUser);

        publicItinerary = itineraryRepository.save(Itinerary.builder()
                .title("Khám phá Huế 3N2Đ")
                .location("Huế")
                .theme("Văn hóa")
                .description("Di tích cố đô Huế")
                .coverImage("https://example.com/hue.jpg")
                .budget(new BigDecimal("2000000"))
                .totalDays(3)
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .user(authorUser)
                .viewCount(12)
                .favoriteCount(0)
                .ratingCount(0)
                .commentCount(0)
                .reuseCount(0)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build());
    }

    @AfterEach
    void tearDown() {
        favoriteRepository.deleteAll();
        savedItineraryRepository.deleteAll();
        ratingRepository.deleteAll();
        itineraryRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    @DisplayName("1. User saves itinerary successfully returns 201 Created")
    void saveItinerary_Success_Returns201() throws Exception {
        mockMvc.perform(post("/api/itineraries/{id}/save", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.saved").value(true))
                .andExpect(jsonPath("$.itineraryId").value(publicItinerary.getItineraryId()))
                .andExpect(jsonPath("$.saveId").isNumber());

        assertTrue(savedItineraryRepository.existsByUser_UserIdAndItinerary_ItineraryId(
                regularUser.getUserId(), publicItinerary.getItineraryId()));
    }

    @Test
    @DisplayName("2. Duplicate save returns 200 OK idempotent")
    void saveItinerary_AlreadySaved_Returns200Idempotent() throws Exception {
        mockMvc.perform(post("/api/itineraries/{id}/save", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/api/itineraries/{id}/save", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.saved").value(true));

        assertEquals(1, savedItineraryRepository.countByItinerary_ItineraryId(publicItinerary.getItineraryId()));
    }

    @Test
    @DisplayName("3. Author can save own public itinerary returning 201 Created")
    void saveItinerary_OwnItinerary_Success_Returns201() throws Exception {
        mockMvc.perform(post("/api/itineraries/{id}/save", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + authorToken))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.saved").value(true));
    }

    @Test
    @DisplayName("4. Author saving own private or hidden itinerary returns 400 Bad Request")
    void saveItinerary_OwnItinerary_PrivateOrHidden_Returns400() throws Exception {
        Itinerary privateItin = itineraryRepository.save(Itinerary.builder()
                .title("Bản thảo riêng tư")
                .location("Bản thảo")
                .budget(BigDecimal.ZERO)
                .totalDays(1)
                .visibility(Visibility.PRIVATE)
                .status(ItineraryStatus.ACTIVE)
                .user(authorUser)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build());

        mockMvc.perform(post("/api/itineraries/{id}/save", privateItin.getItineraryId())
                        .header("Authorization", "Bearer " + authorToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Chỉ có thể lưu các lịch trình đang ở trạng thái công khai (PUBLIC). Vui lòng công khai lịch trình trước khi lưu vào Bộ sưu tập."));
    }

    @Test
    @DisplayName("5. Non-author saving private itinerary returns 404 Not Found")
    void saveItinerary_PrivateItinerary_OtherUser_Returns404() throws Exception {
        Itinerary privateItin = itineraryRepository.save(Itinerary.builder()
                .title("Lịch trình riêng tư")
                .location("Private")
                .budget(BigDecimal.ZERO)
                .totalDays(1)
                .visibility(Visibility.PRIVATE)
                .status(ItineraryStatus.ACTIVE)
                .user(authorUser)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build());

        mockMvc.perform(post("/api/itineraries/{id}/save", privateItin.getItineraryId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("6. Saving deleted itinerary returns 404 Not Found")
    void saveItinerary_DeletedItinerary_Returns404() throws Exception {
        Itinerary deletedItin = itineraryRepository.save(Itinerary.builder()
                .title("Lịch trình đã xóa")
                .location("Deleted")
                .budget(BigDecimal.ZERO)
                .totalDays(1)
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.DELETED)
                .user(authorUser)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build());

        mockMvc.perform(post("/api/itineraries/{id}/save", deletedItin.getItineraryId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("7. Unsave itinerary removes record and returns 200 OK")
    void unsaveItinerary_Success_Returns200() throws Exception {
        savedItineraryRepository.save(SavedItinerary.builder()
                .user(regularUser)
                .itinerary(publicItinerary)
                .createdAt(LocalDateTime.now())
                .build());

        mockMvc.perform(delete("/api/itineraries/{id}/save", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.saved").value(false));

        assertEquals(0, savedItineraryRepository.countByItinerary_ItineraryId(publicItinerary.getItineraryId()));
    }

    @Test
    @DisplayName("8. Unsave itinerary when not saved returns 200 OK idempotent")
    void unsaveItinerary_NotSaved_Returns200Idempotent() throws Exception {
        mockMvc.perform(delete("/api/itineraries/{id}/save", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.saved").value(false));
    }

    @Test
    @DisplayName("9. Get user saved itineraries returns paginated list")
    void getSavedItineraries_Success_ReturnsPaginatedList() throws Exception {
        savedItineraryRepository.save(SavedItinerary.builder()
                .user(regularUser)
                .itinerary(publicItinerary)
                .createdAt(LocalDateTime.now())
                .build());

        mockMvc.perform(get("/api/user/saved-itineraries?page=0&size=10")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].itineraryId").value(publicItinerary.getItineraryId()))
                .andExpect(jsonPath("$.totalElements").value(1));
    }

    @Test
    @DisplayName("10. Saved list silently filters out deleted or private itineraries")
    void getSavedItineraries_SilentFilter_HidesUnavailableItineraries() throws Exception {
        Itinerary deletedItin = itineraryRepository.save(Itinerary.builder()
                .title("Lịch trình đã xóa sau khi lưu")
                .location("Deleted")
                .budget(BigDecimal.ZERO)
                .totalDays(1)
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.DELETED)
                .user(authorUser)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build());

        savedItineraryRepository.save(SavedItinerary.builder()
                .user(regularUser)
                .itinerary(deletedItin)
                .createdAt(LocalDateTime.now())
                .build());

        mockMvc.perform(get("/api/user/saved-itineraries")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(0)))
                .andExpect(jsonPath("$.totalElements").value(0));
    }

    @Test
    @DisplayName("11. Restoring soft-deleted itinerary makes it reappear in saved list without re-saving")
    void getSavedItineraries_Preservation_RestoredItineraryReappears() throws Exception {
        Itinerary itin = itineraryRepository.save(Itinerary.builder()
                .title("Lịch trình tạm ẩn")
                .location("Ẩn")
                .budget(BigDecimal.ZERO)
                .totalDays(1)
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.DELETED)
                .user(authorUser)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build());

        savedItineraryRepository.save(SavedItinerary.builder()
                .user(regularUser)
                .itinerary(itin)
                .createdAt(LocalDateTime.now())
                .build());

        // While deleted: not visible
        mockMvc.perform(get("/api/user/saved-itineraries")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(0)));

        // Admin or author restores it
        itin.setStatus(ItineraryStatus.ACTIVE);
        itineraryRepository.save(itin);

        // Reappears automatically
        mockMvc.perform(get("/api/user/saved-itineraries")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].itineraryId").value(itin.getItineraryId()));
    }

    @Test
    @DisplayName("12. Unauthenticated save returns 401 Unauthorized")
    void saveItinerary_Unauthenticated_Returns401() throws Exception {
        mockMvc.perform(post("/api/itineraries/{id}/save", publicItinerary.getItineraryId()))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get("/api/user/saved-itineraries"))
                .andExpect(status().isUnauthorized());
    }
}
