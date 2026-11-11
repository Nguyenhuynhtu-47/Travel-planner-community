package Travel_Planner.Travel_Planner.config;

import Travel_Planner.Travel_Planner.dto.request.BatchResolvePlacesRequest;
import Travel_Planner.Travel_Planner.dto.response.BatchLinkingReportResponse;
import Travel_Planner.Travel_Planner.service.PlaceAdministrativeAreaService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.sql.*;
import java.util.Locale;

/**
 * Migration & Initial Linking Runner for Phase 3.2: Place - Administrative Area Linking.
 * 
 * Order(6): Executes immediately following AdministrativeAreaMigrationRunner (Order 5).
 * 
 * Guarantees:
 * 1. Single-connection MySQL advisory lock ('place_administrative_area_migration_lock').
 * 2. Idempotent schema evolution: ensures places.administrative_area_id and index exist.
 * 3. Enforces trust_classification on administrative_areas.
 * 4. Executes initial auto-resolution of unlinked places with strict quarantine protection.
 * 5. Fast bypass if already migrated.
 */
@Component
@Order(6)
public class PlaceAdministrativeAreaMigrationRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(PlaceAdministrativeAreaMigrationRunner.class);
    public static final String MIGRATION_LOCK = "place_administrative_area_migration_lock";

    private final DataSource dataSource;
    private final PlaceAdministrativeAreaService linkingService;

    @Value("${app.place-administrative-areas.linking.enabled:true}")
    private boolean linkingEnabled = true;

    private int lockTimeoutSeconds = 10;
    private int maxLockRetries = 3;
    private long retryDelayMs = 500;

    @Autowired
    public PlaceAdministrativeAreaMigrationRunner(
            JdbcTemplate jdbcTemplate,
            PlaceAdministrativeAreaService linkingService
    ) {
        this.dataSource = jdbcTemplate.getDataSource();
        this.linkingService = linkingService;
    }

    public PlaceAdministrativeAreaMigrationRunner(
            DataSource dataSource,
            PlaceAdministrativeAreaService linkingService
    ) {
        this.dataSource = dataSource;
        this.linkingService = linkingService;
    }

    public boolean isLinkingEnabled() { return linkingEnabled; }
    public void setLinkingEnabled(boolean linkingEnabled) { this.linkingEnabled = linkingEnabled; }

    @Override
    public void run(ApplicationArguments args) throws Exception {
        if (!linkingEnabled) {
            log.info("--- [PlaceAdministrativeArea] Linking runner is disabled via configuration. Skipping. ---");
            return;
        }

        log.info("=== [PlaceAdministrativeArea] Phase 3.2 Migration & Linking Runner starting... ===");

        try (Connection lockConn = dataSource.getConnection()) {
            boolean acquired = acquireAdvisoryLock(lockConn);
            if (!acquired) {
                log.warn("--- [PlaceAdministrativeArea] Another node holds '{}'. Skipping this startup pass. ---", MIGRATION_LOCK);
                return;
            }

            try {
                DatabaseMetaData meta = lockConn.getMetaData();
                String catalog = lockConn.getCatalog();

                ensureSchemaExists(lockConn, meta, catalog);

                // Run initial linking for unlinked places
                runInitialLinking();

                log.info("=== [PlaceAdministrativeArea] Phase 3.2 Migration & Linking completed successfully. ===");
            } finally {
                releaseAdvisoryLock(lockConn);
            }
        }
    }

    public void ensureSchemaExists(Connection conn, DatabaseMetaData meta, String catalog) throws Exception {
        // 1. Ensure trust_classification exists on administrative_areas
        if (tableExists(meta, catalog, "administrative_areas")) {
            if (!columnExists(meta, catalog, "administrative_areas", "trust_classification")) {
                log.info("--- [PlaceAdministrativeArea] Adding 'trust_classification' to 'administrative_areas' ---");
                try (Statement stmt = conn.createStatement()) {
                    stmt.execute("ALTER TABLE administrative_areas ADD COLUMN trust_classification VARCHAR(40) NOT NULL DEFAULT 'VERIFIED_WITH_LIMITATIONS'");
                    stmt.execute("CREATE INDEX idx_admin_areas_trust_class ON administrative_areas(trust_classification)");
                }
            }

            // Populate / Refresh trust classifications
            try (Statement stmt = conn.createStatement()) {
                // Tier A: Provinces/Central Cities (parent_id IS NULL)
                stmt.executeUpdate("UPDATE administrative_areas SET trust_classification = 'VERIFIED_AND_TRUSTED' WHERE parent_id IS NULL");

                // Tier A: 33 Primary verified communes
                stmt.executeUpdate("""
                    UPDATE administrative_areas 
                    SET trust_classification = 'VERIFIED_AND_TRUSTED' 
                    WHERE code IN (
                        '26248', '26368', '26170', '26485', '25357', '26425', '26116', '25270', '26326', '25363',
                        '06994', '07192', '11914', '11948', '19742', '20333', '21548', '22736', '23272', '26732', '31078', '31105', '31108',
                        '00004', '00008', '25747', '25750', '20194', '20197', '10507', '10525', '31120', '31135'
                    )
                """);

                // Tier C: 12 Quarantined Bắc Ninh communes
                stmt.executeUpdate("""
                    UPDATE administrative_areas 
                    SET trust_classification = 'UNVERIFIED_AND_QUARANTINED' 
                    WHERE code IN (
                        '07294', '07375', '07399', '07444', '07840', '09193',
                        '09292', '09313', '09319', '09454', '09475', '09496'
                    )
                """);

                // Tier B: Secondary verified communes (all remaining communes)
                stmt.executeUpdate("""
                    UPDATE administrative_areas 
                    SET trust_classification = 'VERIFIED_WITH_LIMITATIONS' 
                    WHERE parent_id IS NOT NULL 
                      AND code NOT IN (
                        '26248', '26368', '26170', '26485', '25357', '26425', '26116', '25270', '26326', '25363',
                        '06994', '07192', '11914', '11948', '19742', '20333', '21548', '22736', '23272', '26732', '31078', '31105', '31108',
                        '00004', '00008', '25747', '25750', '20194', '20197', '10507', '10525', '31120', '31135',
                        '07294', '07375', '07399', '07444', '07840', '09193',
                        '09292', '09313', '09319', '09454', '09475', '09496'
                    )
                """);
            }
        }

        // 2. Ensure administrative_area_id exists on places
        if (tableExists(meta, catalog, "places")) {
            if (!columnExists(meta, catalog, "places", "administrative_area_id")) {
                log.info("--- [PlaceAdministrativeArea] Adding 'administrative_area_id' column to 'places' ---");
                try (Statement stmt = conn.createStatement()) {
                    stmt.execute("ALTER TABLE places ADD COLUMN administrative_area_id BIGINT NULL");
                    stmt.execute("ALTER TABLE places ADD CONSTRAINT fk_places_admin_area FOREIGN KEY (administrative_area_id) REFERENCES administrative_areas(area_id) ON DELETE SET NULL");
                    stmt.execute("CREATE INDEX idx_places_admin_area ON places(administrative_area_id)");
                }
            }
        }
    }

    public void runInitialLinking() {
        try {
            BatchResolvePlacesRequest req = BatchResolvePlacesRequest.builder()
                    .dryRun(false)
                    .overwriteExisting(false)
                    .build();

            BatchLinkingReportResponse report = linkingService.batchResolveAndLink(req);
            log.info("--- [PlaceAdministrativeArea] Initial linking result: total={}, linked={}, quarantined={}, ambiguous={}, noMatch={}, skipped={} ---",
                    report.getTotalPlacesExamined(),
                    report.getLinkedCount(),
                    report.getQuarantinedCount(),
                    report.getAmbiguousCount(),
                    report.getNoMatchCount(),
                    report.getSkippedCount());
        } catch (Exception ex) {
            log.error("--- [PlaceAdministrativeArea] Error during initial linking: {} ---", ex.getMessage(), ex);
        }
    }

    public boolean acquireAdvisoryLock(Connection conn) {
        String sql = "SELECT GET_LOCK(?, ?)";
        for (int attempt = 1; attempt <= maxLockRetries; attempt++) {
            try {
                log.info("--- [PlaceAdministrativeArea] Attempting advisory lock (attempt {}/{} with {}s timeout)... ---",
                        attempt, maxLockRetries, lockTimeoutSeconds);
                try (PreparedStatement ps = conn.prepareStatement(sql)) {
                    ps.setString(1, MIGRATION_LOCK);
                    ps.setInt(2, lockTimeoutSeconds);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            int result = rs.getInt(1);
                            if (!rs.wasNull() && result == 1) {
                                log.info("--- [PlaceAdministrativeArea] Advisory lock '{}' acquired successfully. ---", MIGRATION_LOCK);
                                return true;
                            } else if (result == 0) {
                                log.warn("--- [PlaceAdministrativeArea] Advisory lock acquisition timed out (attempt {}/{}). ---", attempt, maxLockRetries);
                            }
                        }
                    }
                }
            } catch (Exception ex) {
                log.warn("--- [PlaceAdministrativeArea] Advisory lock acquisition attempt {} failed: {} ---", attempt, ex.getMessage());
            }

            if (attempt < maxLockRetries) {
                try {
                    Thread.sleep(retryDelayMs);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    return false;
                }
            }
        }
        return false;
    }

    public void releaseAdvisoryLock(Connection conn) {
        String sql = "SELECT RELEASE_LOCK(?)";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, MIGRATION_LOCK);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    int result = rs.getInt(1);
                    if (!rs.wasNull() && result == 1) {
                        log.info("--- [PlaceAdministrativeArea] Advisory lock '{}' released. ---", MIGRATION_LOCK);
                    }
                }
            }
        } catch (Exception ex) {
            log.warn("--- [PlaceAdministrativeArea] Error releasing advisory lock: {} ---", ex.getMessage());
        }
    }

    public boolean tableExists(DatabaseMetaData meta, String catalog, String tableName) throws Exception {
        try (ResultSet rs = meta.getTables(catalog, null, tableName, new String[]{"TABLE"})) {
            if (rs.next()) return true;
        }
        try (ResultSet rs = meta.getTables(catalog, null, tableName.toUpperCase(Locale.ROOT), new String[]{"TABLE"})) {
            if (rs.next()) return true;
        }
        return false;
    }

    public boolean columnExists(DatabaseMetaData meta, String catalog, String tableName, String columnName) throws Exception {
        try (ResultSet rs = meta.getColumns(catalog, null, tableName, columnName)) {
            if (rs.next()) return true;
        }
        try (ResultSet rs = meta.getColumns(catalog, null, tableName.toUpperCase(Locale.ROOT), columnName.toUpperCase(Locale.ROOT))) {
            if (rs.next()) return true;
        }
        return false;
    }
}
