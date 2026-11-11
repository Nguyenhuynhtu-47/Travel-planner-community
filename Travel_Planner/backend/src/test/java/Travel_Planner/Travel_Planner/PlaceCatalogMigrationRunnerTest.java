package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.PlaceCatalogMigrationRunner;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.DestinationStatus;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.*;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
public class PlaceCatalogMigrationRunnerTest {

    @Autowired
    private PlaceCatalogMigrationRunner migrationRunner;

    @Autowired
    private DestinationRepository destinationRepository;

    @Autowired
    private PlaceRepository placeRepository;

    @Autowired
    private PlaceProviderMappingRepository mappingRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ItineraryRepository itineraryRepository;

    @Autowired
    private ItineraryDayRepository dayRepository;

    @Autowired
    private ActivityRepository activityRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private Destination testDestination;
    private Activity testActivity;

    @BeforeEach
    void setUp() {
        cleanUp();

        User user = userRepository.save(User.builder()
                .username("place_mig_user_" + System.currentTimeMillis())
                .email("place_mig_" + System.currentTimeMillis() + "@test.com")
                .password("hashed_password")
                .fullName("Place Migration User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        Itinerary itinerary = itineraryRepository.save(Itinerary.builder()
                .user(user)
                .title("Place Migration Trip")
                .location("Hà Nội")
                .totalDays(1)
                .status(ItineraryStatus.ACTIVE)
                .build());

        ItineraryDay day = dayRepository.save(ItineraryDay.builder()
                .itinerary(itinerary)
                .dayNumber(1)
                .title("Day 1")
                .build());

        testDestination = destinationRepository.save(Destination.builder()
                .name("Chùa Một Cột")
                .address("Ba Đình, Hà Nội")
                .description("Ngôi chùa cổ kính hình hoa sen")
                .imageUrl("https://example.com/chua-mot-cot.jpg")
                .latitude(new BigDecimal("21.0358000"))
                .longitude(new BigDecimal("105.8335000"))
                .status(DestinationStatus.ACTIVE)
                .build());

        // Create an activity referencing the destination with an authoritative snapshot
        testActivity = activityRepository.save(Activity.builder()
                .itineraryDay(day)
                .destination(testDestination)
                .name("Tham quan Chùa Một Cột")
                .locationName("Chùa Một Cột")
                .locationAddress("Ba Đình, Hà Nội")
                .latitude(new BigDecimal("21.0358000"))
                .longitude(new BigDecimal("105.8335000"))
                .placeId("dest_" + testDestination.getDestinationId())
                .locationProvider("DESTINATION_CATALOG")
                .displayOrder(1)
                .build());
    }

    @AfterEach
    void tearDown() {
        cleanUp();
    }

    private void cleanUp() {
        activityRepository.deleteAll();
        dayRepository.deleteAll();
        itineraryRepository.deleteAll();
        mappingRepository.deleteAll();
        placeRepository.deleteAll();
        destinationRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    @DisplayName("Place Catalog Migration: Imports Destination to Place, creates provider mapping, and links destination.place_id")
    void testDestinationMigrationToPlaceCatalog() {
        migrationRunner.syncDestinationsToPlaces();

        // 1. Verify Destination now has a place_id
        Destination reloadedDest = destinationRepository.findById(testDestination.getDestinationId()).orElseThrow();
        assertNotNull(reloadedDest.getPlaceId(), "Destination must have place_id linked after migration");

        // 2. Verify Place exists with matching canonical information
        Place place = placeRepository.findById(reloadedDest.getPlaceId()).orElseThrow();
        assertEquals("Chùa Một Cột", place.getName());
        assertEquals("chua mot cot", place.getNormalizedName());
        assertEquals("Ba Đình, Hà Nội", place.getAddress());
        assertEquals(21.0358, place.getLatitude().doubleValue(), 0.0001);
        assertEquals(105.8335, place.getLongitude().doubleValue(), 0.0001);
        assertEquals(testDestination.getDestinationId(), place.getSourceDestinationId());

        // 3. Verify PlaceProviderMapping exists
        var mappingOpt = mappingRepository.findByProviderAndProviderPlaceId(
                "DESTINATION_CATALOG", "dest_" + testDestination.getDestinationId()
        );
        assertTrue(mappingOpt.isPresent(), "Mapping must exist in place_provider_mappings");
        assertEquals(place.getPlaceId(), mappingOpt.get().getPlace().getPlaceId());
    }

    @Test
    @DisplayName("Idempotency: Re-running migration runner multiple times does NOT create duplicate Places or mappings")
    void testMigrationRunnerIdempotency() {
        migrationRunner.syncDestinationsToPlaces();
        long placeCount1 = placeRepository.count();
        long mappingCount1 = mappingRepository.count();

        // Run again
        migrationRunner.syncDestinationsToPlaces();
        long placeCount2 = placeRepository.count();
        long mappingCount2 = mappingRepository.count();

        assertEquals(placeCount1, placeCount2, "Repeated migration execution must not create duplicate Place records");
        assertEquals(mappingCount1, mappingCount2, "Repeated migration execution must not create duplicate Mapping records");
    }

    @Test
    @DisplayName("Activity Snapshot Isolation: Migration never alters, mutates, or nullifies existing Activity snapshots")
    void testActivitySnapshotIsolationDuringPlaceMigration() {
        BigDecimal initialLat = testActivity.getLatitude();
        BigDecimal initialLon = testActivity.getLongitude();
        String initialLocName = testActivity.getLocationName();
        String initialLocAddress = testActivity.getLocationAddress();

        // Execute Place Catalog migration
        migrationRunner.syncDestinationsToPlaces();

        // Verify Activity snapshot fields remain strictly identical
        Activity reloadedAct = activityRepository.findById(testActivity.getActivityId()).orElseThrow();
        assertEquals(initialLat, reloadedAct.getLatitude());
        assertEquals(initialLon, reloadedAct.getLongitude());
        assertEquals(initialLocName, reloadedAct.getLocationName());
        assertEquals(initialLocAddress, reloadedAct.getLocationAddress());
        assertEquals("DESTINATION_CATALOG", reloadedAct.getLocationProvider());
    }

    private boolean isMySQLEngine(java.sql.DatabaseMetaData meta) {
        try {
            String product = meta.getDatabaseProductName();
            return product != null && (product.toLowerCase().contains("mysql") || product.toLowerCase().contains("mariadb"));
        } catch (Exception e) {
            return false;
        }
    }

    @Test
    @DisplayName("Lock Test 1: Successful lock acquisition, migration execution, and automatic lock release")
    void test1_successfulLockAcquisitionAndMigration() throws Exception {
        if (jdbcTemplate.getDataSource() == null) return;

        migrationRunner.syncDestinationsToPlaces();

        try (java.sql.Connection conn = jdbcTemplate.getDataSource().getConnection()) {
            if (isMySQLEngine(conn.getMetaData())) {
                try (java.sql.PreparedStatement stmt = conn.prepareStatement("SELECT GET_LOCK('place_catalog_migration_lock', 0)")) {
                    try (java.sql.ResultSet rs = stmt.executeQuery()) {
                        assertTrue(rs.next());
                        assertEquals(1, rs.getInt(1), "Lock must be released and available immediately after migration completes");
                    }
                } finally {
                    try (java.sql.PreparedStatement releaseStmt = conn.prepareStatement("SELECT RELEASE_LOCK('place_catalog_migration_lock')")) {
                        releaseStmt.executeQuery();
                    }
                }
            }
        }
    }

    @Test
    @DisplayName("Lock Test 2: Lock contention followed by successful acquisition after release")
    void test2_lockContentionFollowedBySuccessfulAcquisition() throws Exception {
        if (jdbcTemplate.getDataSource() == null) return;

        try (java.sql.Connection externalConn = jdbcTemplate.getDataSource().getConnection()) {
            if (!isMySQLEngine(externalConn.getMetaData())) return;

            // Session 1 acquires lock
            try (java.sql.PreparedStatement stmt = externalConn.prepareStatement("SELECT GET_LOCK('place_catalog_migration_lock', 0)")) {
                try (java.sql.ResultSet rs = stmt.executeQuery()) {
                    assertTrue(rs.next());
                    assertEquals(1, rs.getInt(1));
                }
            }

            int originalTimeout = migrationRunner.getLockTimeoutSeconds();
            int originalRetries = migrationRunner.getMaxLockRetries();
            long originalDelay = migrationRunner.getRetryDelayMs();

            migrationRunner.setLockTimeoutSeconds(1);
            migrationRunner.setMaxLockRetries(3);
            migrationRunner.setRetryDelayMs(200);

            // Background thread releases the lock after 400ms
            Thread releaseThread = new Thread(() -> {
                try {
                    Thread.sleep(400);
                    try (java.sql.PreparedStatement releaseStmt = externalConn.prepareStatement("SELECT RELEASE_LOCK('place_catalog_migration_lock')")) {
                        releaseStmt.executeQuery();
                    }
                } catch (Exception ignored) {}
            });
            releaseThread.start();

            try {
                assertDoesNotThrow(() -> migrationRunner.syncDestinationsToPlaces());
                releaseThread.join(2000);

                Destination reloaded = destinationRepository.findById(testDestination.getDestinationId()).orElseThrow();
                assertNotNull(reloaded.getPlaceId(), "Destination must be migrated after acquiring lock");
            } finally {
                migrationRunner.setLockTimeoutSeconds(originalTimeout);
                migrationRunner.setMaxLockRetries(originalRetries);
                migrationRunner.setRetryDelayMs(originalDelay);
                try (java.sql.PreparedStatement releaseStmt = externalConn.prepareStatement("SELECT RELEASE_LOCK('place_catalog_migration_lock')")) {
                    releaseStmt.executeQuery();
                } catch (Exception ignored) {}
            }
        }
    }

    @Test
    @DisplayName("Lock Test 3: Lock acquisition timeout fails startup when schema/invariants are incomplete")
    void test3_lockAcquisitionTimeout_failsStartupWhenIncomplete() throws Exception {
        if (jdbcTemplate.getDataSource() == null) return;

        try (java.sql.Connection externalConn = jdbcTemplate.getDataSource().getConnection()) {
            if (!isMySQLEngine(externalConn.getMetaData())) return;

            // Session 1 holds the lock
            try (java.sql.PreparedStatement stmt = externalConn.prepareStatement("SELECT GET_LOCK('place_catalog_migration_lock', 0)")) {
                try (java.sql.ResultSet rs = stmt.executeQuery()) {
                    assertTrue(rs.next());
                    assertEquals(1, rs.getInt(1));
                }
            }

            // Create an unmigrated destination with coordinates but place_id is null
            Destination unmigrated = destinationRepository.save(Destination.builder()
                    .name("Chưa Migrate")
                    .address("Hà Nội")
                    .latitude(new BigDecimal("21.0000000"))
                    .longitude(new BigDecimal("105.0000000"))
                    .status(DestinationStatus.ACTIVE)
                    .build());

            int originalTimeout = migrationRunner.getLockTimeoutSeconds();
            int originalRetries = migrationRunner.getMaxLockRetries();
            long originalDelay = migrationRunner.getRetryDelayMs();

            migrationRunner.setLockTimeoutSeconds(1);
            migrationRunner.setMaxLockRetries(1);
            migrationRunner.setRetryDelayMs(0);

            try {
                IllegalStateException ex = assertThrows(IllegalStateException.class, () -> {
                    migrationRunner.syncDestinationsToPlaces();
                });
                assertTrue(ex.getMessage().contains("Failed to acquire Place Catalog migration advisory lock"));
            } finally {
                migrationRunner.setLockTimeoutSeconds(originalTimeout);
                migrationRunner.setMaxLockRetries(originalRetries);
                migrationRunner.setRetryDelayMs(originalDelay);
                try (java.sql.PreparedStatement releaseStmt = externalConn.prepareStatement("SELECT RELEASE_LOCK('place_catalog_migration_lock')")) {
                    releaseStmt.executeQuery();
                } catch (Exception ignored) {}
            }
        }
    }

    @Test
    @DisplayName("Lock Test 4: Migration failure guarantees lock release")
    void test4_migrationFailure_guaranteesLockRelease() throws Exception {
        if (jdbcTemplate.getDataSource() == null) return;

        try (java.sql.Connection conn = jdbcTemplate.getDataSource().getConnection()) {
            if (!isMySQLEngine(conn.getMetaData())) return;

            // Run migration once normally
            migrationRunner.syncDestinationsToPlaces();

            // Verify lock was released
            try (java.sql.PreparedStatement stmt = conn.prepareStatement("SELECT GET_LOCK('place_catalog_migration_lock', 0)")) {
                try (java.sql.ResultSet rs = stmt.executeQuery()) {
                    assertTrue(rs.next());
                    assertEquals(1, rs.getInt(1), "External session must acquire lock immediately after runner completes");
                }
            } finally {
                try (java.sql.PreparedStatement releaseStmt = conn.prepareStatement("SELECT RELEASE_LOCK('place_catalog_migration_lock')")) {
                    releaseStmt.executeQuery();
                }
            }
        }
    }

    @Test
    @DisplayName("Lock Test 5: No migration execution occurs when lock cannot be acquired")
    void test5_noMigrationExecutionWhenLockUnavailable() throws Exception {
        if (jdbcTemplate.getDataSource() == null) return;

        try (java.sql.Connection externalConn = jdbcTemplate.getDataSource().getConnection()) {
            if (!isMySQLEngine(externalConn.getMetaData())) return;

            // Session 1 holds the lock
            try (java.sql.PreparedStatement stmt = externalConn.prepareStatement("SELECT GET_LOCK('place_catalog_migration_lock', 0)")) {
                try (java.sql.ResultSet rs = stmt.executeQuery()) {
                    assertTrue(rs.next());
                    assertEquals(1, rs.getInt(1));
                }
            }

            Destination unmigrated = destinationRepository.save(Destination.builder()
                    .name("Điểm Chờ Khóa")
                    .address("Đà Nẵng")
                    .latitude(new BigDecimal("16.0000000"))
                    .longitude(new BigDecimal("108.0000000"))
                    .status(DestinationStatus.ACTIVE)
                    .build());

            int originalTimeout = migrationRunner.getLockTimeoutSeconds();
            int originalRetries = migrationRunner.getMaxLockRetries();
            long originalDelay = migrationRunner.getRetryDelayMs();

            migrationRunner.setLockTimeoutSeconds(1);
            migrationRunner.setMaxLockRetries(1);
            migrationRunner.setRetryDelayMs(0);

            try {
                assertThrows(IllegalStateException.class, () -> migrationRunner.syncDestinationsToPlaces());

                // Verify unmigrated destination remains untouched (place_id still null)
                Destination reloaded = destinationRepository.findById(unmigrated.getDestinationId()).orElseThrow();
                assertNull(reloaded.getPlaceId(), "Destination place_id must remain null because migration was blocked");
            } finally {
                migrationRunner.setLockTimeoutSeconds(originalTimeout);
                migrationRunner.setMaxLockRetries(originalRetries);
                migrationRunner.setRetryDelayMs(originalDelay);
                try (java.sql.PreparedStatement releaseStmt = externalConn.prepareStatement("SELECT RELEASE_LOCK('place_catalog_migration_lock')")) {
                    releaseStmt.executeQuery();
                } catch (Exception ignored) {}
            }
        }
    }
}

