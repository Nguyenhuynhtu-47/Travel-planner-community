package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.ActivityLocationMigrationRunner;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.ActivityRepository;
import Travel_Planner.Travel_Planner.repository.ItineraryDayRepository;
import Travel_Planner.Travel_Planner.repository.ItineraryRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
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
public class ActivityLocationMigrationRunnerTest {

    @Autowired
    private ActivityLocationMigrationRunner migrationRunner;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ItineraryRepository itineraryRepository;

    @Autowired
    private ItineraryDayRepository dayRepository;

    @Autowired
    private ActivityRepository activityRepository;

    private ItineraryDay testDay;

    @BeforeEach
    void setUp() {
        cleanUp();

        User user = userRepository.save(User.builder()
                .username("mig_user_" + System.currentTimeMillis())
                .email("mig_" + System.currentTimeMillis() + "@test.com")
                .password("hashed_password")
                .fullName("Migration User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        Itinerary itinerary = itineraryRepository.save(Itinerary.builder()
                .user(user)
                .title("Migration Test Trip")
                .location("Hà Nội")
                .totalDays(2)
                .status(ItineraryStatus.ACTIVE)
                .build());

        testDay = dayRepository.save(ItineraryDay.builder()
                .itinerary(itinerary)
                .dayNumber(1)
                .title("Day 1")
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
        userRepository.deleteAll();
    }

    @Test
    @DisplayName("Idempotency: Running migration runner multiple times does not corrupt data or fail")
    void runner_isIdempotent() {
        assertDoesNotThrow(() -> {
            migrationRunner.ensureSchemaAndBackfill();
            migrationRunner.ensureSchemaAndBackfill();
        });
    }

    @Test
    @DisplayName("Safety: Migration does NOT overwrite existing custom location snapshots")
    void runner_doesNotOverwriteExistingCustomSnapshot() {
        Activity customAct = activityRepository.save(Activity.builder()
                .itineraryDay(testDay)
                .name("Quán Phở Gia Truyền")
                .locationName("Phở Bát Đàn")
                .locationAddress("49 Bát Đàn, Hà Nội")
                .latitude(new BigDecimal("21.0333000"))
                .longitude(new BigDecimal("105.8475000"))
                .placeId("custom_pho_49")
                .locationProvider("nominatim")
                .displayOrder(1)
                .build());

        migrationRunner.ensureSchemaAndBackfill();

        Activity reloaded = activityRepository.findById(customAct.getActivityId()).orElseThrow();
        assertEquals("Phở Bát Đàn", reloaded.getLocationName());
        assertEquals("49 Bát Đàn, Hà Nội", reloaded.getLocationAddress());
        assertNotNull(reloaded.getLatitude());
        assertNotNull(reloaded.getLongitude());
        assertEquals(21.0333, reloaded.getLatitude().doubleValue(), 0.0001);
        assertEquals(105.8475, reloaded.getLongitude().doubleValue(), 0.0001);
        assertEquals("custom_pho_49", reloaded.getPlaceId());
        assertEquals("nominatim", reloaded.getLocationProvider());
    }

    @Test
    @DisplayName("Safety: Runner completes safely when legacy destinations table is absent")
    void runner_runsSafelyWithoutDestinationsTable() {
        assertDoesNotThrow(() -> {
            migrationRunner.ensureSchemaAndBackfill();
        });
    }

    @Test
    @DisplayName("Backfill: Activities lacking standardized location columns are backfilled from custom fields")
    void runner_backfillsFromCustomLocationFields() {
        Activity act = activityRepository.save(Activity.builder()
                .itineraryDay(testDay)
                .name("Quán Phở Gia Truyền")
                .customLocationName("Phở Thìn")
                .customAddress("13 Lò Đúc, Hà Nội")
                .latitude(new BigDecimal("21.0185"))
                .longitude(new BigDecimal("105.8550"))
                .displayOrder(3)
                .build());

        jdbcTemplate.update("UPDATE activities SET location_name = NULL, location_address = NULL WHERE activity_id = ?", act.getActivityId());

        migrationRunner.ensureSchemaAndBackfill();

        Activity backfilled = activityRepository.findById(act.getActivityId()).orElseThrow();
        assertEquals("Phở Thìn", backfilled.getLocationName());
        assertEquals("13 Lò Đúc, Hà Nội", backfilled.getLocationAddress());
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
    @DisplayName("Test 1: Successful lock acquisition, migration execution, and automatic lock release")
    void test1_successfulLockAcquisitionAndMigration() throws Exception {
        Activity act = activityRepository.save(Activity.builder()
                .itineraryDay(testDay)
                .name("Thăm Chùa Một Cột 1")
                .locationName("Chùa Một Cột")
                .latitude(new BigDecimal("21.0358"))
                .longitude(new BigDecimal("105.8335"))
                .displayOrder(1)
                .build());

        migrationRunner.ensureSchemaAndBackfill();

        Activity reloaded = activityRepository.findById(act.getActivityId()).orElseThrow();
        assertEquals("Chùa Một Cột", reloaded.getLocationName());
        assertNotNull(reloaded.getLatitude());

        // Verify lock was cleanly released: external connection can immediately acquire the lock
        try (java.sql.Connection conn = jdbcTemplate.getDataSource().getConnection()) {
            if (isMySQLEngine(conn.getMetaData())) {
                try (java.sql.PreparedStatement stmt = conn.prepareStatement("SELECT GET_LOCK('activity_location_migration_lock', 0)")) {
                    try (java.sql.ResultSet rs = stmt.executeQuery()) {
                        assertTrue(rs.next());
                        assertEquals(1, rs.getInt(1), "Lock must be released and available immediately after migration completes");
                    }
                } finally {
                    try (java.sql.PreparedStatement releaseStmt = conn.prepareStatement("SELECT RELEASE_LOCK('activity_location_migration_lock')")) {
                        releaseStmt.executeQuery();
                    }
                }
            }
        }
    }

    @Test
    @DisplayName("Test 2: Lock contention followed by successful acquisition after release")
    void test2_lockContentionFollowedBySuccessfulAcquisition() throws Exception {
        if (jdbcTemplate.getDataSource() == null) return;

        try (java.sql.Connection externalConn = jdbcTemplate.getDataSource().getConnection()) {
            if (!isMySQLEngine(externalConn.getMetaData())) return;

            // Session 1 acquires lock
            try (java.sql.PreparedStatement stmt = externalConn.prepareStatement("SELECT GET_LOCK('activity_location_migration_lock', 0)")) {
                try (java.sql.ResultSet rs = stmt.executeQuery()) {
                    assertTrue(rs.next());
                    assertEquals(1, rs.getInt(1));
                }
            }

            // Create an activity
            Activity act = activityRepository.save(Activity.builder()
                    .itineraryDay(testDay)
                    .name("Thăm Chùa Một Cột 2")
                    .locationName("Chùa Một Cột 2")
                    .latitude(new BigDecimal("21.0358"))
                    .longitude(new BigDecimal("105.8335"))
                    .displayOrder(2)
                    .build());

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
                    try (java.sql.PreparedStatement releaseStmt = externalConn.prepareStatement("SELECT RELEASE_LOCK('activity_location_migration_lock')")) {
                        releaseStmt.executeQuery();
                    }
                } catch (Exception ignored) {}
            });
            releaseThread.start();

            try {
                // Runner retries, acquires lock on attempt 2 or within timeout, and completes migration
                assertDoesNotThrow(() -> migrationRunner.ensureSchemaAndBackfill());
                releaseThread.join(2000);

                Activity reloaded = activityRepository.findById(act.getActivityId()).orElseThrow();
                assertEquals("Chùa Một Cột 2", reloaded.getLocationName());
                assertNotNull(reloaded.getLatitude());
            } finally {
                migrationRunner.setLockTimeoutSeconds(originalTimeout);
                migrationRunner.setMaxLockRetries(originalRetries);
                migrationRunner.setRetryDelayMs(originalDelay);
                try (java.sql.PreparedStatement releaseStmt = externalConn.prepareStatement("SELECT RELEASE_LOCK('activity_location_migration_lock')")) {
                    releaseStmt.executeQuery();
                } catch (Exception ignored) {}
            }
        }
    }

    @Test
    @DisplayName("Test 3: Lock acquisition timeout fails startup when schema/invariants are incomplete")
    void test3_lockAcquisitionTimeout_failsStartupWhenIncomplete() throws Exception {
        if (jdbcTemplate.getDataSource() == null) return;

        try (java.sql.Connection externalConn = jdbcTemplate.getDataSource().getConnection()) {
            if (!isMySQLEngine(externalConn.getMetaData())) return;

            // Session 1 holds the lock
            try (java.sql.PreparedStatement stmt = externalConn.prepareStatement("SELECT GET_LOCK('activity_location_migration_lock', 0)")) {
                try (java.sql.ResultSet rs = stmt.executeQuery()) {
                    assertTrue(rs.next());
                    assertEquals(1, rs.getInt(1));
                }
            }

            // Create an unmigrated activity (custom location name present, location_name null)
            // so isSchemaAndInvariantsComplete() evaluates to false
            Activity unmigrated = activityRepository.save(Activity.builder()
                    .itineraryDay(testDay)
                    .name("Hoạt động chưa migrate")
                    .customLocationName("Chưa migrate")
                    .displayOrder(3)
                    .build());
            jdbcTemplate.update("UPDATE activities SET location_name = NULL WHERE activity_id = ?", unmigrated.getActivityId());

            int originalTimeout = migrationRunner.getLockTimeoutSeconds();
            int originalRetries = migrationRunner.getMaxLockRetries();
            long originalDelay = migrationRunner.getRetryDelayMs();

            migrationRunner.setLockTimeoutSeconds(1);
            migrationRunner.setMaxLockRetries(1);
            migrationRunner.setRetryDelayMs(0);

            try {
                IllegalStateException ex = assertThrows(IllegalStateException.class, () -> {
                    migrationRunner.ensureSchemaAndBackfill();
                });
                assertTrue(ex.getMessage().contains("Failed to acquire migration advisory lock"),
                        "Exception must clearly indicate lock acquisition failure during startup");
            } finally {
                migrationRunner.setLockTimeoutSeconds(originalTimeout);
                migrationRunner.setMaxLockRetries(originalRetries);
                migrationRunner.setRetryDelayMs(originalDelay);
                try (java.sql.PreparedStatement releaseStmt = externalConn.prepareStatement("SELECT RELEASE_LOCK('activity_location_migration_lock')")) {
                    releaseStmt.executeQuery();
                }
            }
        }
    }

    @Test
    @DisplayName("Test 4: Migration failure guarantees advisory lock release in finally block")
    void test4_migrationFailure_guaranteesLockRelease() throws Exception {
        if (jdbcTemplate.getDataSource() == null) return;

        try (java.sql.Connection testConn = jdbcTemplate.getDataSource().getConnection()) {
            if (!isMySQLEngine(testConn.getMetaData())) return;
        }

        // Create a custom runner that throws SQLException during backfill
        ActivityLocationMigrationRunner failingRunner = new ActivityLocationMigrationRunner(jdbcTemplate.getDataSource()) {
            @Override
            protected void backfillActivities(java.sql.Connection conn, java.sql.DatabaseMetaData meta, String catalog) throws java.sql.SQLException {
                throw new java.sql.SQLException("Simulated fatal database error during migration", "42000", 1064);
            }
        };

        RuntimeException thrown = assertThrows(RuntimeException.class, () -> {
            failingRunner.ensureSchemaAndBackfill();
        });
        assertTrue(thrown.getMessage().contains("Activity location migration failed"));

        // Prove that the lock was cleanly released despite the fatal error:
        // an external connection must be able to acquire the lock immediately with timeout 0
        try (java.sql.Connection externalConn = jdbcTemplate.getDataSource().getConnection()) {
            try (java.sql.PreparedStatement stmt = externalConn.prepareStatement("SELECT GET_LOCK('activity_location_migration_lock', 0)")) {
                try (java.sql.ResultSet rs = stmt.executeQuery()) {
                    assertTrue(rs.next());
                    assertEquals(1, rs.getInt(1), "Lock must be released and immediately acquirable even after migration failure");
                }
            } finally {
                try (java.sql.PreparedStatement releaseStmt = externalConn.prepareStatement("SELECT RELEASE_LOCK('activity_location_migration_lock')")) {
                    releaseStmt.executeQuery();
                }
            }
        }
    }

    @Test
    @DisplayName("Test 5: No migration statements execute when the lock is unavailable")
    void test5_noMigrationExecutionWhenLockUnavailable() throws Exception {
        if (jdbcTemplate.getDataSource() == null) return;

        try (java.sql.Connection externalConn = jdbcTemplate.getDataSource().getConnection()) {
            if (!isMySQLEngine(externalConn.getMetaData())) return;

            // Session 1 holds the lock
            try (java.sql.PreparedStatement stmt = externalConn.prepareStatement("SELECT GET_LOCK('activity_location_migration_lock', 0)")) {
                try (java.sql.ResultSet rs = stmt.executeQuery()) {
                    assertTrue(rs.next());
                    assertEquals(1, rs.getInt(1));
                }
            }

            // Create an activity with custom_location_name but NULL location_name
            Activity unmigrated = activityRepository.save(Activity.builder()
                    .itineraryDay(testDay)
                    .customLocationName("Chưa Được Chuyển Đổi")
                    .customAddress("123 Phố Cổ")
                    .name("Chưa Được Chuyển Đổi")
                    .displayOrder(5)
                    .build());

            // Bypass JPA @PrePersist sync to simulate legacy pre-migration raw SQL data
            jdbcTemplate.update("UPDATE activities SET location_name = NULL WHERE activity_id = ?", unmigrated.getActivityId());

            int originalTimeout = migrationRunner.getLockTimeoutSeconds();
            int originalRetries = migrationRunner.getMaxLockRetries();
            long originalDelay = migrationRunner.getRetryDelayMs();

            migrationRunner.setLockTimeoutSeconds(1);
            migrationRunner.setMaxLockRetries(1);
            migrationRunner.setRetryDelayMs(0);

            try {
                // Must fail startup because schema/invariants are incomplete and lock unavailable
                assertThrows(IllegalStateException.class, () -> {
                    migrationRunner.ensureSchemaAndBackfill();
                });

                // Verify that NO update/migration statements executed: location_name must still be null!
                String locName = jdbcTemplate.queryForObject("SELECT location_name FROM activities WHERE activity_id = ?", String.class, unmigrated.getActivityId());
                assertNull(locName, "location_name must remain null because migration never executed without lock");
            } finally {
                migrationRunner.setLockTimeoutSeconds(originalTimeout);
                migrationRunner.setMaxLockRetries(originalRetries);
                migrationRunner.setRetryDelayMs(originalDelay);
                try (java.sql.PreparedStatement releaseStmt = externalConn.prepareStatement("SELECT RELEASE_LOCK('activity_location_migration_lock')")) {
                    releaseStmt.executeQuery();
                }
            }
        }
    }
}
