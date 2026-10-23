package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.model.Itinerary;
import Travel_Planner.Travel_Planner.model.Rating;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;
import Travel_Planner.Travel_Planner.repository.ItineraryRepository;
import Travel_Planner.Travel_Planner.repository.RatingRepository;
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
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
class ItineraryControllerTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ItineraryRepository itineraryRepository;

    @Autowired
    private RatingRepository ratingRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    private MockMvc mockMvc;

    private User activeUser;
    private User bannedUser;

    @BeforeEach
    void setUp() {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        ratingRepository.deleteAll();
        itineraryRepository.deleteAll();
        userRepository.deleteAll();

        activeUser = userRepository.save(User.builder()
                .username("traveler1")
                .password(passwordEncoder.encode("Password123!"))
                .email("traveler1@example.com")
                .fullName("Nguyen Van A")
                .avatar("https://example.com/avatar1.jpg")
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
    }

    @AfterEach
    void tearDown() {
        ratingRepository.deleteAll();
        itineraryRepository.deleteAll();
        userRepository.deleteAll();
    }

    private Itinerary createItinerary(String title, String location, String theme, String description,
                                      BigDecimal budget, Integer totalDays, Visibility visibility,
                                      ItineraryStatus status, User owner) {
        return itineraryRepository.save(Itinerary.builder()
                .title(title)
                .location(location)
                .theme(theme)
                .description(description)
                .coverImage("https://example.com/cover.jpg")
                .budget(budget)
                .totalDays(totalDays)
                .visibility(visibility)
                .status(status)
                .viewCount(100)
                .favoriteCount(20)
                .ratingCount(2)
                .user(owner)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build());
    }

    @Test
    @DisplayName("1. Public discovery without authentication (Guest) returns 200 OK")
    void testPublicDiscoveryAsGuest() throws Exception {
        createItinerary("Chuyen di Da Lat", "Da Lat", "Nghi duong", "Mo ta",
                new BigDecimal("2000000.00"), 3, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);

        mockMvc.perform(get("/api/itineraries")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].title").value("Chuyen di Da Lat"))
                .andExpect(jsonPath("$.content[0].location").value("Da Lat"))
                .andExpect(jsonPath("$.content[0].creator.username").value("traveler1"))
                .andExpect(jsonPath("$.pageNumber").value(0))
                .andExpect(jsonPath("$.pageSize").value(10))
                .andExpect(jsonPath("$.totalElements").value(1));
    }

    @Test
    @DisplayName("2. Public discovery with valid authenticated user token returns 200 OK")
    void testPublicDiscoveryAsAuthenticatedUser() throws Exception {
        createItinerary("Chuyen di Ha Noi", "Ha Noi", "Am thuc", "Pho va bun cha",
                new BigDecimal("3000000.00"), 4, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);

        String token = jwtTokenProvider.generateToken(activeUser);

        mockMvc.perform(get("/api/itineraries")
                        .header("Authorization", "Bearer " + token)
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].title").value("Chuyen di Ha Noi"));
    }

    @Test
    @DisplayName("3. Exclusion of private itineraries")
    void testExclusionOfPrivateItineraries() throws Exception {
        createItinerary("Public Trip", "Da Nang", "Bien", "Desc",
                new BigDecimal("1500000.00"), 2, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);
        createItinerary("Private Trip", "Da Nang", "Bien", "Desc",
                new BigDecimal("1500000.00"), 2, Visibility.PRIVATE, ItineraryStatus.ACTIVE, activeUser);

        mockMvc.perform(get("/api/itineraries"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Public Trip"));
    }

    @Test
    @DisplayName("4. Exclusion of hidden and deleted itineraries")
    void testExclusionOfHiddenAndDeletedItineraries() throws Exception {
        createItinerary("Active Trip", "Phu Quoc", "Nghi duong", "Desc",
                new BigDecimal("5000000.00"), 5, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);
        createItinerary("Hidden Trip", "Phu Quoc", "Nghi duong", "Desc",
                new BigDecimal("5000000.00"), 5, Visibility.PUBLIC, ItineraryStatus.HIDDEN, activeUser);
        createItinerary("Deleted Trip", "Phu Quoc", "Nghi duong", "Desc",
                new BigDecimal("5000000.00"), 5, Visibility.PUBLIC, ItineraryStatus.DELETED, activeUser);

        mockMvc.perform(get("/api/itineraries"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Active Trip"));
    }

    @Test
    @DisplayName("5. Exclusion of itineraries owned by banned users")
    void testExclusionOfBannedUserItineraries() throws Exception {
        createItinerary("Safe Trip", "Nha Trang", "Bien", "Desc",
                new BigDecimal("2000000.00"), 3, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);
        createItinerary("Spam Trip", "Nha Trang", "Bien", "Desc",
                new BigDecimal("2000000.00"), 3, Visibility.PUBLIC, ItineraryStatus.ACTIVE, bannedUser);

        mockMvc.perform(get("/api/itineraries"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Safe Trip"));
    }

    @Test
    @DisplayName("6. Keyword search across title, location, theme, and description")
    void testKeywordSearchAcrossFields() throws Exception {
        createItinerary("Sapa Mua Lua Chin", "Lao Cai", "Kham pha", "Ruong bac thang dep",
                new BigDecimal("2000000.00"), 3, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);
        createItinerary("Vung Tau Cuoi Tuan", "Ba Ria", "Nghi duong", "Tam bien an hai san",
                new BigDecimal("1000000.00"), 2, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);

        // Search matching title
        mockMvc.perform(get("/api/itineraries").param("keyword", "Sapa"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Sapa Mua Lua Chin"));

        // Search matching location
        mockMvc.perform(get("/api/itineraries").param("keyword", "Lao Cai"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1));

        // Search matching theme
        mockMvc.perform(get("/api/itineraries").param("keyword", "Kham pha"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1));

        // Search matching description
        mockMvc.perform(get("/api/itineraries").param("keyword", "hai san"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Vung Tau Cuoi Tuan"));
    }

    @Test
    @DisplayName("7. Empty and whitespace keyword returns all eligible public itineraries")
    void testEmptyAndWhitespaceKeyword() throws Exception {
        createItinerary("Trip 1", "Loc 1", "Theme 1", "Desc 1",
                new BigDecimal("1000000.00"), 2, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);
        createItinerary("Trip 2", "Loc 2", "Theme 2", "Desc 2",
                new BigDecimal("2000000.00"), 3, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);

        mockMvc.perform(get("/api/itineraries").param("keyword", "   "))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(2));
    }

    @Test
    @DisplayName("8. Individual filters: location, theme, budget range, days range")
    void testIndividualFilters() throws Exception {
        createItinerary("Trip A", "Hue", "Van hoa", "Desc",
                new BigDecimal("1500000.00"), 2, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);
        createItinerary("Trip B", "Hoi An", "Am thuc", "Desc",
                new BigDecimal("3500000.00"), 4, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);

        // Location filter
        mockMvc.perform(get("/api/itineraries").param("location", "Hue"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Trip A"));

        // Theme filter
        mockMvc.perform(get("/api/itineraries").param("theme", "Am thuc"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Trip B"));

        // Budget range filter
        mockMvc.perform(get("/api/itineraries")
                        .param("minBudget", "1000000")
                        .param("maxBudget", "2000000"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Trip A"));

        // Days range filter
        mockMvc.perform(get("/api/itineraries")
                        .param("minDays", "3")
                        .param("maxDays", "5"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Trip B"));
    }

    @Test
    @DisplayName("9. Multi-filter combination uses logical AND")
    void testMultiFilterCombination() throws Exception {
        createItinerary("Target Trip", "Da Lat", "Nghi duong", "Desc",
                new BigDecimal("2500000.00"), 3, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);
        createItinerary("Other Trip", "Da Lat", "Phuot", "Desc",
                new BigDecimal("1500000.00"), 3, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);

        mockMvc.perform(get("/api/itineraries")
                        .param("location", "Da Lat")
                        .param("theme", "Nghi duong")
                        .param("minBudget", "2000000")
                        .param("minDays", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Target Trip"));
    }

    @Test
    @DisplayName("10. Invalid filter values return 400 Bad Request")
    void testInvalidFilterValidation() throws Exception {
        // minBudget < 0
        mockMvc.perform(get("/api/itineraries").param("minBudget", "-100"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message").value("Ngân sách tối thiểu không được nhỏ hơn 0"));

        // minBudget > maxBudget
        mockMvc.perform(get("/api/itineraries")
                        .param("minBudget", "5000000")
                        .param("maxBudget", "1000000"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message").value("Ngân sách tối đa phải lớn hơn hoặc bằng ngân sách tối thiểu"));

        // minDays < 1
        mockMvc.perform(get("/api/itineraries").param("minDays", "0"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message").value("Số ngày tối thiểu phải lớn hơn hoặc bằng 1"));

        // minDays > maxDays
        mockMvc.perform(get("/api/itineraries")
                        .param("minDays", "5")
                        .param("maxDays", "2"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message").value("Số ngày tối đa phải lớn hơn hoặc bằng số ngày tối thiểu"));
    }

    @Test
    @DisplayName("11. Sorting by budget, totalDays, and fallback for invalid sort fields")
    void testSorting() throws Exception {
        createItinerary("Cheap Trip", "Loc A", "Theme", "Desc",
                new BigDecimal("1000000.00"), 5, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);
        createItinerary("Expensive Trip", "Loc B", "Theme", "Desc",
                new BigDecimal("5000000.00"), 1, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);

        // Budget asc
        mockMvc.perform(get("/api/itineraries").param("sort", "budget,asc"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].title").value("Cheap Trip"))
                .andExpect(jsonPath("$.content[1].title").value("Expensive Trip"));

        // Budget desc
        mockMvc.perform(get("/api/itineraries").param("sort", "budget,desc"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].title").value("Expensive Trip"))
                .andExpect(jsonPath("$.content[1].title").value("Cheap Trip"));

        // Total days asc
        mockMvc.perform(get("/api/itineraries").param("sort", "totalDays,asc"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].title").value("Expensive Trip"))
                .andExpect(jsonPath("$.content[1].title").value("Cheap Trip"));

        // Invalid sort field falls back to default sorting (createdAt,desc) without error
        mockMvc.perform(get("/api/itineraries").param("sort", "unsupportedProperty,asc"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(2));
    }

    @Test
    @DisplayName("12. Pagination boundaries: default size, size > 50 capped at 50")
    void testPaginationBoundaries() throws Exception {
        createItinerary("Trip 1", "Loc", "Theme", "Desc",
                new BigDecimal("1000000.00"), 2, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);

        // Size > 50 is normalized to 50
        mockMvc.perform(get("/api/itineraries").param("size", "100"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.pageSize").value(50));

        // Negative page normalized to 0
        mockMvc.perform(get("/api/itineraries").param("page", "-5"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.pageNumber").value(0));
    }

    @Test
    @DisplayName("13. DTO contains creator summary without leaking sensitive user fields")
    void testDtoDoesNotLeakSensitiveFields() throws Exception {
        createItinerary("Sample Trip", "Da Nang", "Bien", "Desc",
                new BigDecimal("2000000.00"), 3, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);

        mockMvc.perform(get("/api/itineraries"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].creator.userId").value(activeUser.getUserId()))
                .andExpect(jsonPath("$.content[0].creator.username").value("traveler1"))
                .andExpect(jsonPath("$.content[0].creator.fullName").value("Nguyen Van A"))
                .andExpect(jsonPath("$.content[0].creator.avatar").value("https://example.com/avatar1.jpg"))
                .andExpect(jsonPath("$.content[0].creator.password").doesNotExist())
                .andExpect(jsonPath("$.content[0].creator.email").doesNotExist())
                .andExpect(jsonPath("$.content[0].creator.phone").doesNotExist());
    }

    @Test
    @DisplayName("14. Efficient average rating calculation from Rating table")
    void testAverageRatingCalculation() throws Exception {
        Itinerary itinerary = createItinerary("Rated Trip", "Hue", "Van hoa", "Desc",
                new BigDecimal("1500000.00"), 2, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);

        User reviewer = userRepository.save(User.builder()
                .username("reviewer1")
                .password(passwordEncoder.encode("Password123!"))
                .email("reviewer1@example.com")
                .fullName("Reviewer One")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        // Add 2 ratings: 4 and 5 -> average is 4.5
        ratingRepository.save(Rating.builder()
                .user(activeUser)
                .itinerary(itinerary)
                .score(4)
                .build());

        ratingRepository.save(Rating.builder()
                .user(reviewer)
                .itinerary(itinerary)
                .score(5)
                .build());

        mockMvc.perform(get("/api/itineraries"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].averageRating").value(4.5));
    }

    @Test
    @DisplayName("15. Security regression check: Mutating operations still require authentication")
    void testSecurityRegression() throws Exception {
        // Health check is public
        mockMvc.perform(get("/api/health"))
                .andExpect(status().isOk());

        // POST /api/itineraries without token should be 401 Unauthorized
        mockMvc.perform(post("/api/itineraries")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isUnauthorized());

        // Protected profile endpoint still requires authentication
        mockMvc.perform(get("/api/user/profile"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("16. Filter by minRating and validate minRating boundaries")
    void testMinRatingFilterAndValidation() throws Exception {
        Itinerary highRated = createItinerary("High Rated", "Loc", "Theme", "Desc",
                new BigDecimal("1000000.00"), 2, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);
        Itinerary lowRated = createItinerary("Low Rated", "Loc", "Theme", "Desc",
                new BigDecimal("1000000.00"), 2, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);
        createItinerary("Unrated", "Loc", "Theme", "Desc",
                new BigDecimal("1000000.00"), 2, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);

        // highRated gets score 5 -> avg 5.0
        ratingRepository.save(Rating.builder().user(activeUser).itinerary(highRated).score(5).build());
        // lowRated gets score 2 -> avg 2.0
        ratingRepository.save(Rating.builder().user(activeUser).itinerary(lowRated).score(2).build());

        // Filter minRating = 4.0 -> only highRated
        mockMvc.perform(get("/api/itineraries").param("minRating", "4.0"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("High Rated"));

        // Filter minRating = 2.0 -> highRated and lowRated
        mockMvc.perform(get("/api/itineraries").param("minRating", "2.0"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(2));

        // Invalid minRating < 1.0 -> 400
        mockMvc.perform(get("/api/itineraries").param("minRating", "0.5"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Điểm đánh giá tối thiểu phải từ 1.0 đến 5.0"));

        // Invalid minRating > 5.0 -> 400
        mockMvc.perform(get("/api/itineraries").param("minRating", "5.5"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Điểm đánh giá tối thiểu phải từ 1.0 đến 5.0"));
    }

    @Test
    @DisplayName("17. SQL LIKE wildcard characters (% and _) are properly escaped")
    void testWildcardCharacterEscaping() throws Exception {
        createItinerary("Giam 50% Chi Phi", "Loc", "Theme", "Desc",
                new BigDecimal("1000000.00"), 2, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);
        createItinerary("Normal Trip Without Percent", "Loc", "Theme", "Desc",
                new BigDecimal("1000000.00"), 2, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);

        // Searching for "%" should match only the itinerary with literal "%", not all itineraries
        mockMvc.perform(get("/api/itineraries").param("keyword", "%"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Giam 50% Chi Phi"));

        // Searching for "_" should match literal underscore, not any single character
        createItinerary("Trip_With_Underscore", "Loc", "Theme", "Desc",
                new BigDecimal("1000000.00"), 2, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);

        mockMvc.perform(get("/api/itineraries").param("keyword", "_"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Trip_With_Underscore"));
    }

    @Test
    @DisplayName("18. Vietnamese search behavior with diacritics and case-insensitivity")
    void testVietnameseSearch() throws Exception {
        createItinerary("Đà Lạt Thành Phố Sương Mù", "Đà Lạt", "Nghỉ dưỡng", "Thưởng thức bánh tráng nướng",
                new BigDecimal("2000000.00"), 3, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);

        // Case-insensitive accented search in title: "đà lạt" matches "Đà Lạt Thành Phố Sương Mù"
        mockMvc.perform(get("/api/itineraries").param("keyword", "đà lạt"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Đà Lạt Thành Phố Sương Mù"));

        // Exact uppercase accented search
        mockMvc.perform(get("/api/itineraries").param("keyword", "Đà Lạt"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1));

        // Description search in Vietnamese with diacritics
        mockMvc.perform(get("/api/itineraries").param("keyword", "bánh tráng"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1));

        // Location filter in Vietnamese with diacritics
        mockMvc.perform(get("/api/itineraries").param("location", "Đà Lạt"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1));
    }

    @Test
    @DisplayName("19. Invalid or expired Bearer token still allows guest discovery but rejects protected routes")
    void testInvalidTokenHandling() throws Exception {
        String invalidToken = "Bearer invalid.malformed.token";

        // Public discovery should succeed for guest even with stale/invalid token
        mockMvc.perform(get("/api/itineraries")
                        .header("Authorization", invalidToken))
                .andExpect(status().isOk());

        // Protected endpoint must reject invalid token with 401 Unauthorized
        mockMvc.perform(get("/api/user/profile")
                        .header("Authorization", invalidToken))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("20. Tighter security: unauthenticated GET on sub-paths requires authentication")
    void testFutureSubPathsRequireAuthentication() throws Exception {
        // GET /api/itineraries/internal-subpath without token is rejected
        mockMvc.perform(get("/api/itineraries/my-drafts"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("21. Stable sorting across pages with identical property values")
    void testStablePaginationSorting() throws Exception {
        // Create 3 trips with identical budgets
        Itinerary trip1 = createItinerary("Trip Identical Budget 1", "Loc", "Theme", "Desc",
                new BigDecimal("1000000.00"), 2, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);
        Itinerary trip2 = createItinerary("Trip Identical Budget 2", "Loc", "Theme", "Desc",
                new BigDecimal("1000000.00"), 2, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);
        Itinerary trip3 = createItinerary("Trip Identical Budget 3", "Loc", "Theme", "Desc",
                new BigDecimal("1000000.00"), 2, Visibility.PUBLIC, ItineraryStatus.ACTIVE, activeUser);

        // Page 0, size 2
        mockMvc.perform(get("/api/itineraries")
                        .param("sort", "budget,asc")
                        .param("page", "0")
                        .param("size", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(2)))
                .andExpect(jsonPath("$.pageNumber").value(0))
                .andExpect(jsonPath("$.totalElements").value(3))
                .andExpect(jsonPath("$.last").value(false));

        // Page 1, size 2
        mockMvc.perform(get("/api/itineraries")
                        .param("sort", "budget,asc")
                        .param("page", "1")
                        .param("size", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.pageNumber").value(1))
                .andExpect(jsonPath("$.last").value(true));
    }
}
