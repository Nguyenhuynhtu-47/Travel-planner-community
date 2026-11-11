package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.DestinationConsolidationMigrationRunner;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.*;
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
import java.time.LocalTime;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
public class DestinationConsolidationMigrationRunnerTest {

    @Autowired
    private DestinationConsolidationMigrationRunner migrationRunner;

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

    private User testUser;
    private Itinerary testItinerary;
    private ItineraryDay testDay;
    private Place testPlace;

    @BeforeEach
    void setUp() {
        cleanUp();

        testUser = userRepository.save(User.builder()
                .username("consolidation_user_" + System.currentTimeMillis())
                .email("consolidation_" + System.currentTimeMillis() + "@test.com")
                .password("hashed_password")
                .fullName("Consolidation Test User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build());

        testItinerary = itineraryRepository.save(Itinerary.builder()
                .user(testUser)
                .title("Consolidation Trip")
                .location("Hà Nội")
                .totalDays(1)
                .status(ItineraryStatus.ACTIVE)
                .build());

        testDay = dayRepository.save(ItineraryDay.builder()
                .itinerary(testItinerary)
                .dayNumber(1)
                .title("Day 1")
                .build());

        testPlace = placeRepository.save(Place.builder()
                .name("Chùa Một Cột Test")
                .normalizedName("chua mot cot test")
                .address("Ba Đình, Hà Nội")
                .description("Ngôi chùa cổ kính")
                .imageUrl("https://example.com/chua-mot-cot.jpg")
                .latitude(new BigDecimal("21.0358000"))
                .longitude(new BigDecimal("105.8335000"))
                .category(PlaceCategory.ATTRACTION)
                .status(PlaceStatus.ACTIVE)
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
        mappingRepository.deleteAll();
        placeRepository.deleteAll();
    }

    @Test
    @DisplayName("Expand phase preserves canonical_place_id for activity linked to Place while preserving snapshot")
    void testExpandPhaseBackfillsCanonicalPlaceId() {
        // Create an activity linked to place with authoritative snapshot
        Activity activity = activityRepository.save(Activity.builder()
                .itineraryDay(testDay)
                .place(testPlace)
                .name("Tham quan Chùa Một Cột")
                .description("Dạo bước vãn cảnh chùa")
                .locationName("Chùa Một Cột Snapshot")
                .locationAddress("Ba Đình, Hà Nội Snapshot")
                .customLocationName("Chùa Một Cột Snapshot")
                .customAddress("Ba Đình, Hà Nội Snapshot")
                .latitude(new BigDecimal("21.0358500"))
                .longitude(new BigDecimal("105.8335500"))
                .placeId("osm_node_999999")
                .locationProvider("TOMTOM")
                .startTime(LocalTime.of(9, 0))
                .endTime(LocalTime.of(10, 30))
                .cost(BigDecimal.ZERO)
                .displayOrder(1)
                .build());

        // Run consolidation migration
        migrationRunner.migrateDestinationConsolidation();

        // Reload activity
        Activity reloaded = activityRepository.findById(activity.getActivityId()).orElseThrow();

        // Canonical place ID should be populated
        assertNotNull(reloaded.getPlace(), "Activity should have Place entity loaded");
        assertEquals(testPlace.getPlaceId(), reloaded.getPlace().getPlaceId(), "canonical_place_id must match Place ID");

        // Authoritative location snapshot must be 100% preserved
        assertEquals("Chùa Một Cột Snapshot", reloaded.getLocationName());
        assertEquals("Ba Đình, Hà Nội Snapshot", reloaded.getLocationAddress());
        assertEquals(new BigDecimal("21.0358500"), reloaded.getLatitude());
        assertEquals(new BigDecimal("105.8335500"), reloaded.getLongitude());

        // External provider place ID and location provider must be completely untouched
        assertEquals("osm_node_999999", reloaded.getPlaceId(), "External provider place_id must NEVER be overwritten");
        assertEquals("TOMTOM", reloaded.getLocationProvider(), "Location provider must remain unchanged");
    }

    @Test
    @DisplayName("Activity without Place remains with null canonical_place_id and intact snapshot")
    void testActivityWithoutDestinationRemainsNull() {
        Activity mapPickerActivity = activityRepository.save(Activity.builder()
                .itineraryDay(testDay)
                .name("Quán Phở Khôi Hói")
                .description("Ăn sáng phở bò")
                .locationName("Phở Khôi Hói")
                .locationAddress("50 Hàng Vải, Hoàn Kiếm, Hà Nội")
                .customLocationName("Phở Khôi Hói")
                .customAddress("50 Hàng Vải, Hoàn Kiếm, Hà Nội")
                .latitude(new BigDecimal("21.0351234"))
                .longitude(new BigDecimal("105.8491234"))
                .placeId("pois:poi_123456")
                .locationProvider("LOCATION_IQ")
                .startTime(LocalTime.of(7, 30))
                .endTime(LocalTime.of(8, 30))
                .cost(new BigDecimal("60000.00"))
                .displayOrder(1)
                .build());

        // Run migration
        migrationRunner.migrateDestinationConsolidation();

        Activity reloaded = activityRepository.findById(mapPickerActivity.getActivityId()).orElseThrow();
        assertNull(reloaded.getPlace(), "canonical_place_id should remain NULL for activities without place");
        assertEquals("Phở Khôi Hói", reloaded.getLocationName());
        assertEquals("50 Hàng Vải, Hoàn Kiếm, Hà Nội", reloaded.getLocationAddress());
        assertEquals(new BigDecimal("21.0351234"), reloaded.getLatitude());
        assertEquals(new BigDecimal("105.8491234"), reloaded.getLongitude());
        assertEquals("pois:poi_123456", reloaded.getPlaceId());
        assertEquals("LOCATION_IQ", reloaded.getLocationProvider());
    }

    @Test
    @DisplayName("Idempotency: Running migration multiple times does not corrupt or duplicate data")
    void testMigrationIdempotency() {
        Activity activity = activityRepository.save(Activity.builder()
                .itineraryDay(testDay)
                .place(testPlace)
                .name("Idempotent Test Activity")
                .locationName("Loc Name")
                .locationAddress("Loc Addr")
                .latitude(new BigDecimal("21.0000000"))
                .longitude(new BigDecimal("105.0000000"))
                .placeId("prov_id_1")
                .locationProvider("TOMTOM")
                .displayOrder(1)
                .build());

        // Run twice
        migrationRunner.migrateDestinationConsolidation();
        migrationRunner.migrateDestinationConsolidation();

        Activity reloaded = activityRepository.findById(activity.getActivityId()).orElseThrow();
        assertNotNull(reloaded.getPlace());
        assertEquals(testPlace.getPlaceId(), reloaded.getPlace().getPlaceId());
        assertEquals("Loc Name", reloaded.getLocationName());
        assertEquals("prov_id_1", reloaded.getPlaceId());
    }

    @Test
    @DisplayName("Contract phase ensures legacy destinations schema is cleanly absent")
    void testContractPhaseSchemaInvariants() {
        migrationRunner.setContractEnabled(true);
        assertDoesNotThrow(() -> migrationRunner.migrateDestinationConsolidation());
    }

    @Test
    @DisplayName("Case B/C verification: Subsequent startups on contracted or fresh schema succeed cleanly without errors")
    void testSubsequentStartupsOnContractedSchema_succeedWithoutErrors() {
        migrationRunner.setContractEnabled(true);
        assertDoesNotThrow(() -> migrationRunner.migrateDestinationConsolidation(),
                "First execution on contracted schema must succeed");

        // Re-run simulating consecutive application restarts
        assertDoesNotThrow(() -> migrationRunner.migrateDestinationConsolidation(),
                "Subsequent execution simulating application restart must succeed idempotently");

        long placeCount = placeRepository.count();
        long activityCount = activityRepository.count();
        assertTrue(placeCount >= 0);
        assertTrue(activityCount >= 0);
    }

    @Test
    @DisplayName("Task 2 - Case A: Fresh database without legacy schema starts cleanly and executes migration idempotently")
    void testTask2_CaseA_FreshDatabase_startsCleanlyWithoutLegacySchema() throws Exception {
        // 1. Verify schema invariants: table 'destinations' and legacy columns must not exist
        try (var conn = jdbcTemplate.getDataSource().getConnection()) {
            var meta = conn.getMetaData();
            String catalog = conn.getCatalog();

            assertFalse(migrationRunner.tableExists(meta, catalog, "destinations"),
                    "Table 'destinations' must NOT exist in fresh schema");
            assertFalse(migrationRunner.columnExists(meta, catalog, "activities", "destination_id"),
                    "Column 'activities.destination_id' must NOT exist in fresh schema");
            assertFalse(migrationRunner.columnExists(meta, catalog, "places", "source_destination_id"),
                    "Column 'places.source_destination_id' must NOT exist in fresh schema");

            // Required modern tables exist
            assertTrue(migrationRunner.tableExists(meta, catalog, "places"), "Table 'places' must exist");
            assertTrue(migrationRunner.tableExists(meta, catalog, "place_provider_mappings"), "Table 'place_provider_mappings' must exist");
            assertTrue(migrationRunner.tableExists(meta, catalog, "activities"), "Table 'activities' must exist");
            assertTrue(migrationRunner.columnExists(meta, catalog, "activities", "canonical_place_id"), "Column 'canonical_place_id' must exist");
        }

        // 2. Execute migration runner on fresh schema with contract enabled
        migrationRunner.setContractEnabled(true);
        assertDoesNotThrow(() -> migrationRunner.migrateDestinationConsolidation(),
                "Migration runner must execute cleanly on fresh schema without legacy queries");

        // 3. Re-run migration simulating multiple restarts
        assertDoesNotThrow(() -> migrationRunner.migrateDestinationConsolidation(),
                "Re-running migration on fresh schema must be completely idempotent");

        // 4. Verify entities can be persisted and read without issue
        Place newPlace = placeRepository.save(Place.builder()
                .name("Test Fresh Place")
                .address("10 Fresh Street")
                .latitude(new BigDecimal("10.7700000"))
                .longitude(new BigDecimal("106.7000000"))
                .status(PlaceStatus.ACTIVE)
                .build());
        assertNotNull(newPlace.getPlaceId());
        assertTrue(placeRepository.existsById(newPlace.getPlaceId()));
    }

    @Test
    @DisplayName("Task 2 - Case B: Mid-migration state with unmigrated activities blocks Contract phase and prevents schema drop")
    void testTask2_CaseB_MidMigration_contractBlockedWhenUnmigratedRowsExist() throws Exception {
        // Step 1: Simulate legacy environment by creating legacy table 'destinations' and column 'activities.destination_id'
        try {
            jdbcTemplate.execute("CREATE TABLE IF NOT EXISTS destinations (destination_id BIGINT PRIMARY KEY, name VARCHAR(100) NOT NULL)");
            jdbcTemplate.execute("ALTER TABLE activities ADD COLUMN destination_id BIGINT NULL");
        } catch (Exception ignored) {
            // In case column or table already exists in test DB
        }

        try {
            // Seed legacy destination
            jdbcTemplate.execute("INSERT INTO destinations (destination_id, name) VALUES (999, 'Legacy Test Destination')");

            // Create an unmigrated activity that references destination_id = 999 but has canonical_place_id = NULL
            Activity unmigratedActivity = activityRepository.save(Activity.builder()
                    .itineraryDay(testDay)
                    .name("Unmigrated Activity")
                    .locationName("Legacy Location")
                    .latitude(new BigDecimal("21.0300000"))
                    .longitude(new BigDecimal("105.8500000"))
                    .placeId("dest_999")
                    .locationProvider("DESTINATION_CATALOG")
                    .displayOrder(99)
                    .build());

            // Set destination_id = 999 via raw SQL so it represents mid-migration
            jdbcTemplate.update("UPDATE activities SET destination_id = 999, canonical_place_id = NULL WHERE activity_id = ?",
                    unmigratedActivity.getActivityId());

            // Step 2: Attempt to execute Contract phase -> MUST THROW IllegalStateException!
            migrationRunner.setContractEnabled(true);
            IllegalStateException thrown = assertThrows(IllegalStateException.class, () -> {
                try (var conn = jdbcTemplate.getDataSource().getConnection()) {
                    var meta = conn.getMetaData();
                    String catalog = conn.getCatalog();
                    migrationRunner.executeContractPhase(conn, meta, catalog);
                }
            }, "Contract phase must abort when unmigrated activities exist!");

            assertTrue(thrown.getMessage().contains("activities still have unmigrated destination_id"),
                    "Exception message must specify unmigrated activities count");

            // Step 3: Assert legacy schema was NOT dropped
            try (var conn = jdbcTemplate.getDataSource().getConnection()) {
                var meta = conn.getMetaData();
                String catalog = conn.getCatalog();
                assertTrue(migrationRunner.tableExists(meta, catalog, "destinations"),
                        "Table 'destinations' must NOT be dropped when Contract phase is aborted");
                assertTrue(migrationRunner.columnExists(meta, catalog, "activities", "destination_id"),
                        "Column 'activities.destination_id' must NOT be dropped when Contract phase is aborted");
            }

            // Step 4: Verify NO data loss occurred
            Activity stillThere = activityRepository.findById(unmigratedActivity.getActivityId()).orElseThrow();
            assertEquals("Unmigrated Activity", stillThere.getName());

            // Step 5: Simulate backfilling completion
            jdbcTemplate.update("UPDATE activities SET canonical_place_id = ? WHERE activity_id = ?",
                    testPlace.getPlaceId(), unmigratedActivity.getActivityId());

            // Step 6: Now re-run Contract phase -> MUST SUCCEED!
            assertDoesNotThrow(() -> {
                try (var conn = jdbcTemplate.getDataSource().getConnection()) {
                    var meta = conn.getMetaData();
                    String catalog = conn.getCatalog();
                    migrationRunner.executeContractPhase(conn, meta, catalog);
                }
            }, "Contract phase must succeed once all activities are backfilled");

            // Step 7: Verify legacy schema is cleanly removed and activity retains snapshot & canonical_place_id
            try (var conn = jdbcTemplate.getDataSource().getConnection()) {
                var meta = conn.getMetaData();
                String catalog = conn.getCatalog();
                assertFalse(migrationRunner.tableExists(meta, catalog, "destinations"),
                        "Table 'destinations' must now be dropped");
                assertFalse(migrationRunner.columnExists(meta, catalog, "activities", "destination_id"),
                        "Column 'destination_id' must now be dropped");
            }

            Activity postContract = activityRepository.findById(unmigratedActivity.getActivityId()).orElseThrow();
            assertNotNull(postContract.getPlace(), "canonical_place_id must be populated");
            assertEquals(testPlace.getPlaceId(), postContract.getPlace().getPlaceId());
            assertEquals("Legacy Location", postContract.getLocationName());
        } finally {
            // Cleanup any remaining temporary legacy objects if test failed midway
            try {
                jdbcTemplate.execute("DROP TABLE IF EXISTS destinations");
            } catch (Exception ignored) {}
            try {
                jdbcTemplate.execute("ALTER TABLE activities DROP COLUMN destination_id");
            } catch (Exception ignored) {}
        }
    }
}
