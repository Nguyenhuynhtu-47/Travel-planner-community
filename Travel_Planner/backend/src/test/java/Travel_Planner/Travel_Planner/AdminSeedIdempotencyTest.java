package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.seeder.DataSeeder;
import Travel_Planner.Travel_Planner.seeder.SeedResult;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
public class AdminSeedIdempotencyTest {

    @Autowired
    private DataSeeder dataSeeder;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PlaceRepository placeRepository;

    @Autowired
    private PlaceProviderMappingRepository placeProviderMappingRepository;

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
    private ItineraryPlaceRepository itineraryPlaceRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired(required = false)
    private org.springframework.jdbc.core.JdbcTemplate jdbcTemplate;

    @BeforeEach
    void setUp() {
        cleanDatabase();
    }

    @AfterEach
    void tearDown() {
        cleanDatabase();
    }

    private void cleanDatabase() {
        if (jdbcTemplate != null) {
            try {
                jdbcTemplate.execute("SET FOREIGN_KEY_CHECKS = 0");
                jdbcTemplate.execute("DELETE FROM post_reports");
                jdbcTemplate.execute("DELETE FROM post_media");
                jdbcTemplate.execute("DELETE FROM post_comments");
                jdbcTemplate.execute("DELETE FROM post_likes");
                jdbcTemplate.execute("DELETE FROM posts");
                jdbcTemplate.execute("DELETE FROM media_assets");
            } catch (Exception ignored) {
            } finally {
                try {
                    jdbcTemplate.execute("SET FOREIGN_KEY_CHECKS = 1");
                } catch (Exception ignored) {}
            }
        }
        offlineDownloadRepository.deleteAll();
        itineraryShareRepository.deleteAll();
        followRepository.deleteAll();
        savedItineraryRepository.deleteAll();
        favoriteRepository.deleteAll();
        commentRepository.deleteAll();
        ratingRepository.deleteAll();
        itineraryPlaceRepository.deleteAll();
        activityRepository.deleteAll();
        itineraryDayRepository.deleteAll();
        itineraryRepository.deleteAll();
        placeProviderMappingRepository.deleteAll();
        placeRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    @DisplayName("Scenario 1: Fresh database without admin seeds admin_master successfully")
    void testSeedAdminWhenDatabaseEmpty() {
        assertEquals(0, userRepository.count());

        SeedResult result = dataSeeder.seedData();
        assertNotNull(result);

        User admin = userRepository.findByUsername("admin_master").orElse(null);
        assertNotNull(admin, "admin_master should be created on clean database");
        assertEquals("nam.admin", admin.getHandle());
        assertEquals("admin@travelplanner.local", admin.getEmail());
        assertEquals(Role.ADMIN, admin.getRole());
        assertEquals(UserStatus.ACTIVE, admin.getStatus());
        assertTrue(passwordEncoder.matches("Password123!", admin.getPassword()));
    }

    @Test
    @DisplayName("Scenario 2: Database already has nam.admin - backend seeds safely without duplicate handle exception and preserves existing admin credentials")
    void testSeedAdminWhenNamAdminAlreadyExists() {
        // Pre-create the realistic production admin account as found in MySQL (user_id 578)
        User existingAdmin = userRepository.save(User.builder()
                .username("admin")
                .handle("nam.admin")
                .email("admin@gmail.com")
                .password(passwordEncoder.encode("123456"))
                .role(Role.ADMIN)
                .status(UserStatus.ACTIVE)
                .fullName("Nguyễn Hoàng Nam (Admin)")
                .phone("0901234567")
                .address("Quận 1, TP. Hồ Chí Minh")
                .avatar("https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&q=80")
                .bio("Quản trị viên hệ thống Travel Planner.")
                .build());

        assertNotNull(existingAdmin.getUserId());
        assertEquals(1, userRepository.count());

        // Run seedData - must NOT throw DataIntegrityViolationException: Duplicate entry 'nam.admin'
        assertDoesNotThrow(() -> {
            SeedResult result = dataSeeder.seedData();
            assertNotNull(result);
        });

        // Verify existing admin is 100% preserved
        User preservedAdmin = userRepository.findById(existingAdmin.getUserId()).orElse(null);
        assertNotNull(preservedAdmin);
        assertEquals("admin", preservedAdmin.getUsername(), "Username must remain 'admin'");
        assertEquals("nam.admin", preservedAdmin.getHandle(), "Handle must remain 'nam.admin'");
        assertEquals("admin@gmail.com", preservedAdmin.getEmail(), "Email must remain 'admin@gmail.com'");
        assertEquals(Role.ADMIN, preservedAdmin.getRole(), "Role must remain ADMIN");
        assertEquals(UserStatus.ACTIVE, preservedAdmin.getStatus(), "Status must remain ACTIVE");
        assertTrue(passwordEncoder.matches("123456", preservedAdmin.getPassword()), "Original password '123456' must NOT be overwritten");

        // Verify no duplicate admin was inserted
        assertFalse(userRepository.existsByUsername("admin_master"), "Should NOT insert duplicate 'admin_master' when 'nam.admin' is already claimed");
    }

    @Test
    @DisplayName("Scenario 3: Multiple consecutive startup runs never produce duplicates")
    void testMultipleStartupRunsIdempotency() {
        // Run 1
        SeedResult r1 = dataSeeder.seedData();
        assertNotNull(r1);
        long users1 = userRepository.count();
        long places1 = placeRepository.count();
        long itins1 = itineraryRepository.count();

        // Run 2
        SeedResult r2 = dataSeeder.seedData();
        assertNotNull(r2);
        assertEquals(users1, userRepository.count());
        assertEquals(places1, placeRepository.count());
        assertEquals(itins1, itineraryRepository.count());

        // Run 3
        SeedResult r3 = dataSeeder.seedData();
        assertNotNull(r3);
        assertEquals(users1, userRepository.count());
        assertEquals(places1, placeRepository.count());
        assertEquals(itins1, itineraryRepository.count());
    }

    @Test
    @DisplayName("Scenario 4: Inconsistent existing data (different users for handle and username) is handled safely without crashing")
    void testInconsistentDataHandledSafely() {
        // User A owns handle "nam.admin"
        User userA = userRepository.save(User.builder()
                .username("user_a")
                .handle("nam.admin")
                .email("usera@example.com")
                .password(passwordEncoder.encode("PasswordA1!"))
                .role(Role.ADMIN)
                .status(UserStatus.ACTIVE)
                .fullName("User A")
                .build());

        // User B owns username "admin_master" with different handle
        User userB = userRepository.save(User.builder()
                .username("admin_master")
                .handle("user.b.handle")
                .email("userb@example.com")
                .password(passwordEncoder.encode("PasswordB1!"))
                .role(Role.ADMIN)
                .status(UserStatus.ACTIVE)
                .fullName("User B")
                .build());

        assertEquals(2, userRepository.count());

        // Run seedData - must NOT throw DataIntegrityViolationException
        assertDoesNotThrow(() -> {
            dataSeeder.seedData();
        });

        // User A and User B must be preserved
        User checkA = userRepository.findById(userA.getUserId()).orElse(null);
        assertNotNull(checkA);
        assertEquals("nam.admin", checkA.getHandle());
        assertTrue(passwordEncoder.matches("PasswordA1!", checkA.getPassword()));

        User checkB = userRepository.findById(userB.getUserId()).orElse(null);
        assertNotNull(checkB);
        assertEquals("admin_master", checkB.getUsername());
        assertTrue(passwordEncoder.matches("PasswordB1!", checkB.getPassword()));
    }
}
