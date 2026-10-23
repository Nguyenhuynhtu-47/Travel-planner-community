package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.model.Activity;
import Travel_Planner.Travel_Planner.model.Follow;
import Travel_Planner.Travel_Planner.model.Itinerary;
import Travel_Planner.Travel_Planner.model.ItineraryDay;
import Travel_Planner.Travel_Planner.model.Rating;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.DestinationStatus;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.seeder.DataSeeder;
import Travel_Planner.Travel_Planner.seeder.SeedResult;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
class DataSeederTest {

    @Autowired
    private DataSeeder dataSeeder;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private DestinationRepository destinationRepository;

    @Autowired
    private ItineraryRepository itineraryRepository;

    @Autowired
    private ItineraryDayRepository itineraryDayRepository;

    @Autowired
    private ActivityRepository activityRepository;

    @Autowired
    private RatingRepository ratingRepository;

    @Autowired
    private CommentRepository commentRepository;

    @Autowired
    private FavoriteRepository favoriteRepository;

    @Autowired
    private SavedItineraryRepository savedItineraryRepository;

    @Autowired
    private FollowRepository followRepository;

    @Autowired
    private ItineraryShareRepository itineraryShareRepository;

    @Autowired
    private OfflineDownloadRepository offlineDownloadRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @BeforeEach
    void setUp() {
        cleanDatabase();
    }

    @org.junit.jupiter.api.AfterEach
    void tearDown() {
        cleanDatabase();
    }

    private void cleanDatabase() {
        // Clean test database tables in reverse foreign-key order
        offlineDownloadRepository.deleteAll();
        itineraryShareRepository.deleteAll();
        followRepository.deleteAll();
        savedItineraryRepository.deleteAll();
        favoriteRepository.deleteAll();
        commentRepository.deleteAll();
        ratingRepository.deleteAll();
        activityRepository.deleteAll();
        itineraryDayRepository.deleteAll();
        itineraryRepository.deleteAll();
        destinationRepository.deleteAll();
        userRepository.deleteAll();
    }


    @Test
    @DisplayName("DataSeeder should seed realistic data across all 12 tables and satisfy target thresholds")
    void shouldSeedAllTablesSuccessfully() {
        SeedResult result = dataSeeder.seedData();
        assertNotNull(result);

        // 1. Users: 8-12 test users (we created 10)
        long usersCount = userRepository.count();
        assertTrue(usersCount >= 8 && usersCount <= 12, "Users count should be between 8 and 12, actual: " + usersCount);
        assertTrue(userRepository.existsByUsername("admin_master"));
        assertTrue(userRepository.existsByUsername("traveler_viet"));
        assertTrue(userRepository.existsByUsername("inactive_user"));
        assertTrue(userRepository.existsByUsername("banned_spammer"));

        // Verify password hashing (never plaintext)
        User admin = userRepository.findByUsername("admin_master").orElseThrow();
        assertNotEquals("Password123!", admin.getPassword());
        assertTrue(passwordEncoder.matches("Password123!", admin.getPassword()));
        assertEquals(Role.ADMIN, admin.getRole());
        assertEquals(UserStatus.ACTIVE, admin.getStatus());

        User inactive = userRepository.findByUsername("inactive_user").orElseThrow();
        assertEquals(UserStatus.INACTIVE, inactive.getStatus());

        User banned = userRepository.findByUsername("banned_spammer").orElseThrow();
        assertEquals(UserStatus.BANNED, banned.getStatus());

        // 2. Destinations: 15-25 realistic destinations in Vietnam (we created 20)
        long destCount = destinationRepository.count();
        assertTrue(destCount >= 15 && destCount <= 25, "Destinations count should be between 15 and 25, actual: " + destCount);
        assertTrue(destinationRepository.existsByName("Hồ Hoàn Kiếm & Phố Cổ Hà Nội"));
        assertTrue(destinationRepository.existsByName("Vịnh Hạ Long"));
        assertTrue(destinationRepository.existsByName("Đỉnh Fansipan - Nóc Nhà Đông Dương"));
        assertTrue(destinationRepository.existsByName("Quần thể danh thắng Tràng An"));
        assertTrue(destinationRepository.existsByName("Bà Nà Hills & Cầu Vàng"));
        assertTrue(destinationRepository.existsByName("Hồ Xuân Hương & Quảng Trường Lâm Viên"));
        assertTrue(destinationRepository.existsByName("Bãi Sao Phú Quốc"));
        assertTrue(destinationRepository.existsByName("Chợ Nổi Cái Răng"));

        // 3. Itineraries: 15-20 itineraries (we created 16)
        long itinCount = itineraryRepository.count();
        assertTrue(itinCount >= 15 && itinCount <= 20, "Itineraries count should be between 15 and 20, actual: " + itinCount);

        // Check original_itinerary_id derivation
        Itinerary derived = itineraryRepository.findAll().stream()
                .filter(i -> i.getOriginalItinerary() != null)
                .findFirst()
                .orElse(null);
        assertNotNull(derived, "There should be at least one derived itinerary with originalItinerary populated");
        assertEquals("Trekking Sa Pa - Chinh Phục Đỉnh Fansipan 3N2Đ", derived.getOriginalItinerary().getTitle());

        // Check visibility and status distributions
        long publicActiveCount = itineraryRepository.findAll().stream()
                .filter(i -> i.getVisibility() == Visibility.PUBLIC && i.getStatus() == ItineraryStatus.ACTIVE)
                .count();
        assertTrue(publicActiveCount >= 10, "There should be sufficient public active itineraries for Explore");

        long privateCount = itineraryRepository.findAll().stream()
                .filter(i -> i.getVisibility() == Visibility.PRIVATE)
                .count();
        assertTrue(privateCount >= 2, "There should be at least 2 private itineraries to test access controls");

        // 4. Days and Activities
        long daysCount = itineraryDayRepository.count();
        assertTrue(daysCount >= 30, "Should have seeded days for multi-day itineraries, actual: " + daysCount);

        long actCount = activityRepository.count();
        assertTrue(actCount >= 50, "Should have seeded multiple activities per day, actual: " + actCount);

        // Verify activity display_order uniqueness per day
        List<Activity> activities = activityRepository.findAll();
        Set<String> dayOrderPairs = new HashSet<>();
        for (Activity act : activities) {
            assertNotNull(act.getDestination(), "Every activity must link to a valid destination");
            assertNotNull(act.getItineraryDay(), "Every activity must belong to a day");
            String key = act.getItineraryDay().getDayId() + "_" + act.getDisplayOrder();
            assertTrue(dayOrderPairs.add(key), "Duplicate display_order detected for day: " + key);
        }

        // 5. Social Interactions
        assertTrue(commentRepository.count() >= 10, "Comments should be >= 10");
        assertTrue(ratingRepository.count() >= 15, "Ratings should be >= 15");
        assertTrue(favoriteRepository.count() >= 10, "Favorites should be >= 10");
        assertTrue(savedItineraryRepository.count() >= 5, "Saved itineraries should be >= 5");
        assertTrue(followRepository.count() >= 5, "Follows should be >= 5");
        assertTrue(itineraryShareRepository.count() >= 3, "Itinerary shares should be >= 3");
        assertTrue(offlineDownloadRepository.count() >= 5, "Offline downloads should be >= 5");

        // Verify no self-follows
        for (Follow f : followRepository.findAll()) {
            assertNotEquals(f.getFollower().getUserId(), f.getFollowing().getUserId(), "Self-following is not permitted");
        }

        // Verify ratings uniqueness per (user, itinerary)
        Set<String> ratingPairs = new HashSet<>();
        for (Rating r : ratingRepository.findAll()) {
            String pair = r.getUser().getUserId() + "_" + r.getItinerary().getItineraryId();
            assertTrue(ratingPairs.add(pair), "Duplicate rating detected: " + pair);
            assertTrue(r.getScore() >= 1 && r.getScore() <= 5, "Rating score should be between 1 and 5");
        }
    }

    @Test
    @DisplayName("DataSeeder should be idempotent: running multiple times preserves exact row counts without duplicates")
    void shouldBeIdempotentOnRepeatedRuns() {
        // Run 1
        dataSeeder.seedData();
        long users1 = userRepository.count();
        long dest1 = destinationRepository.count();
        long itin1 = itineraryRepository.count();
        long days1 = itineraryDayRepository.count();
        long act1 = activityRepository.count();
        long comments1 = commentRepository.count();
        long ratings1 = ratingRepository.count();
        long favorites1 = favoriteRepository.count();
        long saved1 = savedItineraryRepository.count();
        long follows1 = followRepository.count();
        long shares1 = itineraryShareRepository.count();
        long downloads1 = offlineDownloadRepository.count();

        // Run 2
        dataSeeder.seedData();

        assertEquals(users1, userRepository.count(), "Users count must remain identical on second run");
        assertEquals(dest1, destinationRepository.count(), "Destinations count must remain identical on second run");
        assertEquals(itin1, itineraryRepository.count(), "Itineraries count must remain identical on second run");
        assertEquals(days1, itineraryDayRepository.count(), "Days count must remain identical on second run");
        assertEquals(act1, activityRepository.count(), "Activities count must remain identical on second run");
        assertEquals(comments1, commentRepository.count(), "Comments count must remain identical on second run");
        assertEquals(ratings1, ratingRepository.count(), "Ratings count must remain identical on second run");
        assertEquals(favorites1, favoriteRepository.count(), "Favorites count must remain identical on second run");
        assertEquals(saved1, savedItineraryRepository.count(), "Saved itineraries count must remain identical on second run");
        assertEquals(follows1, followRepository.count(), "Follows count must remain identical on second run");
        assertEquals(shares1, itineraryShareRepository.count(), "Shares count must remain identical on second run");
        assertEquals(downloads1, offlineDownloadRepository.count(), "Downloads count must remain identical on second run");
    }

    @Test
    @DisplayName("DataSeeder should preserve pre-existing users without overwriting or deleting them")
    void shouldPreservePreExistingUser() {
        User existingUser = userRepository.save(User.builder()
                .username("custom_preexisting_user")
                .password(passwordEncoder.encode("SecretPass123!"))
                .email("preexisting@example.com")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .fullName("Custom Pre-existing User")
                .build());

        dataSeeder.seedData();

        User retrieved = userRepository.findByUsername("custom_preexisting_user").orElse(null);
        assertNotNull(retrieved, "Pre-existing user must still exist in database");
        assertEquals("preexisting@example.com", retrieved.getEmail());
        assertTrue(passwordEncoder.matches("SecretPass123!", retrieved.getPassword()));
    }
}
