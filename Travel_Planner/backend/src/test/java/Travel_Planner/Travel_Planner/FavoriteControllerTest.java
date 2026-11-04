package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.model.Favorite;
import Travel_Planner.Travel_Planner.model.Itinerary;
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
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
class FavoriteControllerTest {

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
                .username("author_fav")
                .password(passwordEncoder.encode("Password123!"))
                .email("author_fav@example.com")
                .fullName("Author Fav")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        regularUser = userRepository.save(User.builder()
                .username("regular_fav")
                .password(passwordEncoder.encode("Password123!"))
                .email("regular_fav@example.com")
                .fullName("Regular User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        userToken = jwtTokenProvider.generateToken(regularUser);
        authorToken = jwtTokenProvider.generateToken(authorUser);

        publicItinerary = itineraryRepository.save(Itinerary.builder()
                .title("Hành trình Sapa 2N1Đ")
                .location("Sapa")
                .theme("Khám phá")
                .description("Ngắm mây Fansipan")
                .coverImage("https://example.com/sapa.jpg")
                .budget(new BigDecimal("1800000"))
                .totalDays(2)
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .user(authorUser)
                .viewCount(5)
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
    @DisplayName("1. Add favorite first time returns 201 Created and increments counter")
    void addFavorite_Success_Returns201AndIncrementsCounter() throws Exception {
        mockMvc.perform(post("/api/itineraries/{id}/favorites", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.favorited").value(true))
                .andExpect(jsonPath("$.favoriteCount").value(1));

        Itinerary updated = itineraryRepository.findById(publicItinerary.getItineraryId()).orElseThrow();
        assertEquals(1, updated.getFavoriteCount());
    }

    @Test
    @DisplayName("2. Add favorite when already favorited returns 200 OK without incrementing counter")
    void addFavorite_AlreadyFavorited_Returns200Idempotent() throws Exception {
        // Initial favorite
        mockMvc.perform(post("/api/itineraries/{id}/favorites", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isCreated());

        // Duplicate favorite
        mockMvc.perform(post("/api/itineraries/{id}/favorites", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.favorited").value(true))
                .andExpect(jsonPath("$.favoriteCount").value(1));

        assertEquals(1, favoriteRepository.countByItinerary_ItineraryId(publicItinerary.getItineraryId()));
    }

    @Test
    @DisplayName("3. Author cannot favorite own itinerary returns 400 Bad Request")
    void addFavorite_SelfFavorite_Returns400() throws Exception {
        mockMvc.perform(post("/api/itineraries/{id}/favorites", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + authorToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Bạn không thể tự thêm lịch trình của mình vào danh sách yêu thích"));
    }

    @Test
    @DisplayName("4. Favoriting private itinerary returns 404 Not Found")
    void addFavorite_PrivateItinerary_Returns404() throws Exception {
        Itinerary privateItin = itineraryRepository.save(Itinerary.builder()
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

        mockMvc.perform(post("/api/itineraries/{id}/favorites", privateItin.getItineraryId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("5. Favoriting deleted itinerary returns 404 Not Found")
    void addFavorite_DeletedItinerary_Returns404() throws Exception {
        Itinerary deletedItin = itineraryRepository.save(Itinerary.builder()
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

        mockMvc.perform(post("/api/itineraries/{id}/favorites", deletedItin.getItineraryId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("6. Remove favorite returns 200 OK and decrements counter")
    void removeFavorite_Success_Returns200AndDecrementsCounter() throws Exception {
        favoriteRepository.save(Favorite.builder()
                .user(regularUser)
                .itinerary(publicItinerary)
                .createdAt(LocalDateTime.now())
                .build());
        publicItinerary.setFavoriteCount(1);
        itineraryRepository.save(publicItinerary);

        mockMvc.perform(delete("/api/itineraries/{id}/favorites", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.favorited").value(false))
                .andExpect(jsonPath("$.favoriteCount").value(0));

        Itinerary updated = itineraryRepository.findById(publicItinerary.getItineraryId()).orElseThrow();
        assertEquals(0, updated.getFavoriteCount());
    }

    @Test
    @DisplayName("7. Remove favorite when not favorited returns 200 OK without negative counter")
    void removeFavorite_NotFavorited_Returns200Idempotent() throws Exception {
        mockMvc.perform(delete("/api/itineraries/{id}/favorites", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.favorited").value(false))
                .andExpect(jsonPath("$.favoriteCount").value(0));
    }

    @Test
    @DisplayName("8. Get user favorites returns paginated list sorted by createdAt DESC")
    void getUserFavorites_Success_ReturnsPaginatedList() throws Exception {
        favoriteRepository.save(Favorite.builder()
                .user(regularUser)
                .itinerary(publicItinerary)
                .createdAt(LocalDateTime.now())
                .build());

        mockMvc.perform(get("/api/user/favorites?page=0&size=10")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].itineraryId").value(publicItinerary.getItineraryId()))
                .andExpect(jsonPath("$.totalElements").value(1));
    }

    @Test
    @DisplayName("9. User favorites silently filters out deleted or hidden itineraries")
    void getUserFavorites_ExcludesDeletedItineraries() throws Exception {
        Itinerary deletedItin = itineraryRepository.save(Itinerary.builder()
                .title("Deleted favorited trip")
                .location("Deleted")
                .budget(BigDecimal.ZERO)
                .totalDays(1)
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.DELETED)
                .user(authorUser)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build());

        favoriteRepository.save(Favorite.builder()
                .user(regularUser)
                .itinerary(deletedItin)
                .createdAt(LocalDateTime.now())
                .build());

        // Favorite record exists in DB (data preservation)
        assertEquals(1, favoriteRepository.findByUser_UserIdOrderByCreatedAtDesc(regularUser.getUserId()).size());

        // But is silently omitted in the public favorited list
        mockMvc.perform(get("/api/user/favorites")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(0)))
                .andExpect(jsonPath("$.totalElements").value(0));
    }

    @Test
    @DisplayName("10. Unauthenticated access to favorites returns 401")
    void favorite_Unauthenticated_Returns401() throws Exception {
        mockMvc.perform(post("/api/itineraries/{id}/favorites", publicItinerary.getItineraryId()))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get("/api/user/favorites"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("11. Concurrent duplicate favorites handled idempotently without counter drift")
    void concurrentFavorite_HandledIdempotentlyWithoutCounterDrift() throws Exception {
        // Request 1
        mockMvc.perform(post("/api/itineraries/{id}/favorites", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isCreated());

        // Duplicate Request 2
        mockMvc.perform(post("/api/itineraries/{id}/favorites", publicItinerary.getItineraryId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.favorited").value(true))
                .andExpect(jsonPath("$.favoriteCount").value(1));

        assertEquals(1, favoriteRepository.countByItinerary_ItineraryId(publicItinerary.getItineraryId()));
    }
}
