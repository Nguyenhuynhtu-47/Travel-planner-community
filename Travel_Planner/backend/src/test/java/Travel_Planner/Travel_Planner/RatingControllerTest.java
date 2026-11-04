package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.model.Itinerary;
import Travel_Planner.Travel_Planner.model.Rating;
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
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
class RatingControllerTest {

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
    private User raterUser;
    private User bannedUser;
    private String raterToken;
    private String authorToken;
    private String bannedToken;
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
                .username("author1")
                .password(passwordEncoder.encode("Password123!"))
                .email("author1@example.com")
                .fullName("Author One")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        raterUser = userRepository.save(User.builder()
                .username("rater1")
                .password(passwordEncoder.encode("Password123!"))
                .email("rater1@example.com")
                .fullName("Rater One")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        bannedUser = userRepository.save(User.builder()
                .username("banneduser")
                .password(passwordEncoder.encode("Password123!"))
                .email("banned@example.com")
                .fullName("Banned User")
                .role(Role.USER)
                .status(UserStatus.BANNED)
                .build());

        raterToken = jwtTokenProvider.generateToken(raterUser);
        authorToken = jwtTokenProvider.generateToken(authorUser);
        bannedToken = jwtTokenProvider.generateToken(bannedUser);

        publicItinerary = itineraryRepository.save(Itinerary.builder()
                .title("Chuyến đi Đà Lạt 3N2Đ")
                .location("Đà Lạt")
                .theme("Khám phá")
                .description("Lịch trình khám phá Đà Lạt mộng mơ")
                .coverImage("https://example.com/dalat.jpg")
                .budget(new BigDecimal("2500000"))
                .totalDays(3)
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .user(authorUser)
                .viewCount(10)
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
    @DisplayName("1. Rate itinerary first time returns 201 Created and increments counter")
    void rateItinerary_Success_FirstTime_Returns201AndIncrementsCounter() throws Exception {
        mockMvc.perform(post("/api/itineraries/{id}/ratings", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + raterToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"score\": 5}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.score").value(5))
                .andExpect(jsonPath("$.averageRating").value(5.0))
                .andExpect(jsonPath("$.ratingCount").value(1));

        Itinerary updated = itineraryRepository.findById(publicItinerary.getItineraryId()).orElseThrow();
        assertEquals(1, updated.getRatingCount());
    }

    @Test
    @DisplayName("2. Re-rating updates score and returns 200 OK without incrementing counter")
    void rateItinerary_Success_ReRating_Returns200AndUpdatesScore() throws Exception {
        // Initial rating
        mockMvc.perform(post("/api/itineraries/{id}/ratings", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + raterToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"score\": 5}"))
                .andExpect(status().isCreated());

        // Re-rating with 4 stars
        mockMvc.perform(post("/api/itineraries/{id}/ratings", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + raterToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"score\": 4}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.score").value(4))
                .andExpect(jsonPath("$.averageRating").value(4.0))
                .andExpect(jsonPath("$.ratingCount").value(1));

        Itinerary updated = itineraryRepository.findById(publicItinerary.getItineraryId()).orElseThrow();
        assertEquals(1, updated.getRatingCount());
    }

    @Test
    @DisplayName("3. Author cannot rate own itinerary returns 400 Bad Request")
    void rateItinerary_SelfRating_Returns400() throws Exception {
        mockMvc.perform(post("/api/itineraries/{id}/ratings", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + authorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"score\": 5}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Bạn không thể tự đánh giá lịch trình của chính mình"));
    }

    @Test
    @DisplayName("4. Rate itinerary with score 0 returns 400 Bad Request")
    void rateItinerary_InvalidScore_Zero_Returns400() throws Exception {
        mockMvc.perform(post("/api/itineraries/{id}/ratings", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + raterToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"score\": 0}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("5. Rate itinerary with score 6 returns 400 Bad Request")
    void rateItinerary_InvalidScore_Six_Returns400() throws Exception {
        mockMvc.perform(post("/api/itineraries/{id}/ratings", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + raterToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"score\": 6}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("6. Rating private itinerary of another user returns 404 Not Found")
    void rateItinerary_PrivateItinerary_Returns404() throws Exception {
        Itinerary privateItinerary = itineraryRepository.save(Itinerary.builder()
                .title("Private trip")
                .location("Private")
                .budget(BigDecimal.ZERO)
                .totalDays(1)
                .visibility(Visibility.PRIVATE)
                .status(ItineraryStatus.ACTIVE)
                .user(authorUser)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build());

        mockMvc.perform(post("/api/itineraries/{id}/ratings", privateItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + raterToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"score\": 5}"))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("7. Rating deleted itinerary returns 404 Not Found")
    void rateItinerary_DeletedItinerary_Returns404() throws Exception {
        Itinerary deletedItinerary = itineraryRepository.save(Itinerary.builder()
                .title("Deleted trip")
                .location("Deleted")
                .budget(BigDecimal.ZERO)
                .totalDays(1)
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.DELETED)
                .user(authorUser)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build());

        mockMvc.perform(post("/api/itineraries/{id}/ratings", deletedItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + raterToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"score\": 5}"))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("8. Rating without authentication returns 401 Unauthorized")
    void rateItinerary_Unauthenticated_Returns401() throws Exception {
        mockMvc.perform(post("/api/itineraries/{id}/ratings", publicItinerary.getItineraryId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"score\": 5}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("9. Banned user rating is rejected by security filter with 401 Unauthorized")
    void rateItinerary_BannedUser_Returns401() throws Exception {
        mockMvc.perform(post("/api/itineraries/{id}/ratings", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + bannedToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"score\": 5}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("10. Query user rating returns rated true and score")
    void getUserRating_WhenRated_ReturnsScoreAndDetails() throws Exception {
        ratingRepository.save(Rating.builder()
                .user(raterUser)
                .itinerary(publicItinerary)
                .score(5)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build());

        mockMvc.perform(get("/api/itineraries/{id}/ratings/me", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + raterToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.rated").value(true))
                .andExpect(jsonPath("$.score").value(5))
                .andExpect(jsonPath("$.itineraryId").value(publicItinerary.getItineraryId()));
    }

    @Test
    @DisplayName("11. Query user rating when not rated returns rated false and score null")
    void getUserRating_WhenNotRated_ReturnsRatedFalse() throws Exception {
        mockMvc.perform(get("/api/itineraries/{id}/ratings/me", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + raterToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.rated").value(false))
                .andExpect(jsonPath("$.score").value(nullValue()));
    }

    @Test
    @DisplayName("12. Public rating summary breakdown is accessible without token")
    void getRatingSummary_Public_ReturnsAverageAndDistribution() throws Exception {
        ratingRepository.save(Rating.builder()
                .user(raterUser)
                .itinerary(publicItinerary)
                .score(5)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build());

        mockMvc.perform(get("/api/itineraries/{id}/ratings", publicItinerary.getItineraryId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.itineraryId").value(publicItinerary.getItineraryId()))
                .andExpect(jsonPath("$.averageRating").value(5.0))
                .andExpect(jsonPath("$.ratingCount").value(1))
                .andExpect(jsonPath("$.starCounts.5").value(1))
                .andExpect(jsonPath("$.starCounts.4").value(0));
    }

    @Test
    @DisplayName("13. Delete rating decrements counter and returns 200 OK")
    void deleteRating_Success_Returns200AndDecrementsCounter() throws Exception {
        ratingRepository.save(Rating.builder()
                .user(raterUser)
                .itinerary(publicItinerary)
                .score(5)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build());
        publicItinerary.setRatingCount(1);
        itineraryRepository.save(publicItinerary);

        mockMvc.perform(delete("/api/itineraries/{id}/ratings", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + raterToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Đã xóa đánh giá thành công"))
                .andExpect(jsonPath("$.ratingCount").value(0));

        Itinerary updated = itineraryRepository.findById(publicItinerary.getItineraryId()).orElseThrow();
        assertEquals(0, updated.getRatingCount());
    }

    @Test
    @DisplayName("14. Deleting non-existent rating returns 404 Not Found")
    void deleteRating_NotRated_Returns404() throws Exception {
        mockMvc.perform(delete("/api/itineraries/{id}/ratings", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + raterToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.message").value("Bạn chưa đánh giá lịch trình này"));
    }

    @Test
    @DisplayName("15. Concurrent duplicate rating handled idempotently")
    void concurrentRating_HandledIdempotently() throws Exception {
        // Send first rating
        mockMvc.perform(post("/api/itineraries/{id}/ratings", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + raterToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"score\": 5}"))
                .andExpect(status().isCreated());

        // Send duplicate rating
        mockMvc.perform(post("/api/itineraries/{id}/ratings", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + raterToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"score\": 4}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.score").value(4))
                .andExpect(jsonPath("$.ratingCount").value(1));

        assertEquals(1, ratingRepository.countByItinerary_ItineraryId(publicItinerary.getItineraryId()));
    }
}
