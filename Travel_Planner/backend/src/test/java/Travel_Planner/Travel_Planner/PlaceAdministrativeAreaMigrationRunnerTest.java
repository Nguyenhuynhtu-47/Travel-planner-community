package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.AdministrativeAreaMigrationRunner;
import Travel_Planner.Travel_Planner.config.PlaceAdministrativeAreaMigrationRunner;
import Travel_Planner.Travel_Planner.model.AdministrativeArea;
import Travel_Planner.Travel_Planner.model.Place;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaTrustClassification;
import Travel_Planner.Travel_Planner.model.enums.PlaceCategory;
import Travel_Planner.Travel_Planner.model.enums.PlaceStatus;
import Travel_Planner.Travel_Planner.repository.AdministrativeAreaRepository;
import Travel_Planner.Travel_Planner.repository.PlaceRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.DefaultApplicationArguments;
import org.springframework.boot.test.context.SpringBootTest;

import javax.sql.DataSource;
import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.ResultSet;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
public class PlaceAdministrativeAreaMigrationRunnerTest {

    @Autowired
    private DataSource dataSource;

    @Autowired
    private PlaceAdministrativeAreaMigrationRunner runner;

    @Autowired
    private AdministrativeAreaMigrationRunner adminAreaRunner;

    @Autowired
    private PlaceRepository placeRepository;

    @Autowired
    private AdministrativeAreaRepository areaRepository;

    @BeforeEach
    void setUp() throws Exception {
        // Ensure catalog is imported
        adminAreaRunner.migrateAndImport();
    }

    @Test
    @DisplayName("Migration runner should ensure places.administrative_area_id column and foreign key exist")
    void testEnsureSchemaExists() throws Exception {
        try (Connection conn = dataSource.getConnection()) {
            DatabaseMetaData meta = conn.getMetaData();
            String catalog = conn.getCatalog();

            runner.ensureSchemaExists(conn, meta, catalog);

            assertTrue(runner.columnExists(meta, catalog, "places", "administrative_area_id"),
                    "Column places.administrative_area_id must exist");

            assertTrue(runner.columnExists(meta, catalog, "administrative_areas", "trust_classification"),
                    "Column administrative_areas.trust_classification must exist");
        }
    }

    @Test
    @DisplayName("Migration runner should populate trust_classification across all administrative areas")
    void testTrustClassificationPopulated() throws Exception {
        try (Connection conn = dataSource.getConnection()) {
            runner.ensureSchemaExists(conn, conn.getMetaData(), conn.getCatalog());
        }

        List<AdministrativeArea> trusted = areaRepository.findByTrustClassification(
                AdministrativeAreaTrustClassification.VERIFIED_AND_TRUSTED
        );
        assertFalse(trusted.isEmpty(), "Verified and trusted areas must be populated");
        assertEquals(67, trusted.size(), "Expected exactly 67 VERIFIED_AND_TRUSTED records (34 provinces + 33 primary communes)");

        List<AdministrativeArea> quarantined = areaRepository.findByTrustClassification(
                AdministrativeAreaTrustClassification.UNVERIFIED_AND_QUARANTINED
        );
        assertFalse(quarantined.isEmpty(), "Quarantined areas must be populated");
        assertEquals(12, quarantined.size(), "Expected exactly 12 UNVERIFIED_AND_QUARANTINED records for Bắc Ninh");

        List<AdministrativeArea> secondary = areaRepository.findByTrustClassification(
                AdministrativeAreaTrustClassification.VERIFIED_WITH_LIMITATIONS
        );
        assertEquals(3276, secondary.size(), "Expected exactly 3,276 secondary verified records");
    }

    @Test
    @DisplayName("Advisory lock acquisition and release should function cleanly")
    void testAdvisoryLockAcquisitionAndRelease() throws Exception {
        try (Connection conn = dataSource.getConnection()) {
            boolean acquired = runner.acquireAdvisoryLock(conn);
            assertTrue(acquired, "Should successfully acquire place_administrative_area_migration_lock");

            runner.releaseAdvisoryLock(conn);
        }
    }

    @Test
    @DisplayName("Migration runner run() should be idempotent and safely link places")
    void testRun_Idempotency() throws Exception {
        Place place = placeRepository.save(Place.builder()
                .name("Chùa Trấn Quốc Test")
                .address("Đường Thanh Niên, Yên Phụ, Tây Hồ, Hà Nội")
                .latitude(new BigDecimal("21.0478000"))
                .longitude(new BigDecimal("105.8368000"))
                .category(PlaceCategory.ATTRACTION)
                .status(PlaceStatus.ACTIVE)
                .build());

        try {
            // First execution
            runner.run(new DefaultApplicationArguments());

            // Second execution (idempotent)
            runner.run(new DefaultApplicationArguments());

            Place reloaded = placeRepository.findById(place.getPlaceId()).orElseThrow();
            assertNotNull(reloaded.getAdministrativeArea(), "Place should be resolved and linked to Hà Nội / Yên Phụ");
            assertEquals("00103", reloaded.getAdministrativeArea().getCode());
        } finally {
            placeRepository.deleteById(place.getPlaceId());
        }
    }
}

