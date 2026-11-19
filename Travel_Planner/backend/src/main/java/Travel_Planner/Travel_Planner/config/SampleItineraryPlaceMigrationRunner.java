package Travel_Planner.Travel_Planner.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.sql.*;

/**
 * Migration & backfill runner for Sample/Template Itinerary Places.
 * Ensures that all itineraries whose activities have valid linked places (canonical_place_id)
 * also have corresponding rows in 'itinerary_places' so that places appear accurately in the Overview tab.
 *
 * Runs on startup with Order(5), uses connection-bound MySQL advisory locking,
 * guarantees idempotency, and never duplicates existing place associations.
 */
@Component
@Order(5)
public class SampleItineraryPlaceMigrationRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(SampleItineraryPlaceMigrationRunner.class);
    public static final String MIGRATION_LOCK = "sample_itinerary_place_migration_lock";

    private final DataSource dataSource;
    private int lockTimeoutSeconds = 5;
    private int maxLockRetries = 3;
    private long retryDelayMs = 500;
    private boolean strictLockRequired = false;

    @Autowired
    public SampleItineraryPlaceMigrationRunner(JdbcTemplate jdbcTemplate) {
        this.dataSource = jdbcTemplate.getDataSource();
    }

    public SampleItineraryPlaceMigrationRunner(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    public void setLockTimeoutSeconds(int seconds) {
        this.lockTimeoutSeconds = seconds;
    }

    public void setMaxLockRetries(int retries) {
        this.maxLockRetries = retries;
    }

    public void setRetryDelayMs(long delayMs) {
        this.retryDelayMs = delayMs;
    }

    public void setStrictLockRequired(boolean strict) {
        this.strictLockRequired = strict;
    }

    @Override
    public void run(ApplicationArguments args) {
        backfillSampleItineraryPlaces();
    }

    public int backfillSampleItineraryPlaces() {
        if (dataSource == null) {
            log.warn("--- [SampleItineraryPlaceMigration] DataSource is null, skipping migration. ---");
            return 0;
        }

        try (Connection conn = dataSource.getConnection()) {
            DatabaseMetaData meta = conn.getMetaData();
            String catalog = conn.getCatalog();
            boolean isMySQL = isMySQLEngine(meta);

            boolean lockAcquired = false;
            if (isMySQL) {
                lockAcquired = acquireLockWithRetries(conn);
                if (!lockAcquired) {
                    log.warn("--- [SampleItineraryPlaceMigration] Advisory lock could not be acquired after {} attempts. ---",
                            maxLockRetries);
                    if (!strictLockRequired) {
                        log.info("--- [SampleItineraryPlaceMigration] Strict lock not required, proceeding safely. ---");
                    } else {
                        throw new IllegalStateException("Failed to acquire advisory lock for Sample Itinerary Place migration.");
                    }
                }
            }

            try {
                if (!tableExists(meta, catalog, "itinerary_places") ||
                    !tableExists(meta, catalog, "activities") ||
                    !tableExists(meta, catalog, "itinerary_days") ||
                    !tableExists(meta, catalog, "places")) {
                    log.info("--- [SampleItineraryPlaceMigration] Required tables not present yet. Skipping backfill. ---");
                    return 0;
                }

                return executeBackfill(conn);
            } finally {
                if (lockAcquired && isMySQL) {
                    releaseLockOnConnection(conn);
                }
            }
        } catch (SQLException e) {
            log.error("--- [SampleItineraryPlaceMigration] Database error during backfill: {} ---", e.getMessage(), e);
            throw new RuntimeException("Sample itinerary place migration failed", e);
        } catch (Exception e) {
            log.error("--- [SampleItineraryPlaceMigration] Unexpected error during backfill: {} ---", e.getMessage(), e);
            throw new RuntimeException("Sample itinerary place migration failed", e);
        }
    }

    private int executeBackfill(Connection conn) throws SQLException {
        // Query how many missing itinerary-place pairs exist
        String countSql = "SELECT COUNT(DISTINCT CONCAT(d.itinerary_id, '_', a.canonical_place_id)) " +
                "FROM activities a " +
                "JOIN itinerary_days d ON a.day_id = d.day_id " +
                "WHERE a.canonical_place_id IS NOT NULL " +
                "  AND NOT EXISTS (" +
                "    SELECT 1 FROM itinerary_places ip " +
                "    WHERE ip.itinerary_id = d.itinerary_id " +
                "      AND ip.place_id = a.canonical_place_id" +
                "  )";

        int missingCount = 0;
        try (Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(countSql)) {
            if (rs.next()) {
                missingCount = rs.getInt(1);
            }
        }

        if (missingCount == 0) {
            log.info("--- [SampleItineraryPlaceMigration] All activities with linked places already have itinerary_places entries (0 missing). ---");
            return 0;
        }

        log.info("--- [SampleItineraryPlaceMigration] Found {} missing itinerary_places associations. Backfilling now... ---", missingCount);

        String insertSql = "INSERT INTO itinerary_places (itinerary_id, place_id, saved_at) " +
                "SELECT DISTINCT d.itinerary_id, a.canonical_place_id, NOW() " +
                "FROM activities a " +
                "JOIN itinerary_days d ON a.day_id = d.day_id " +
                "WHERE a.canonical_place_id IS NOT NULL " +
                "  AND NOT EXISTS (" +
                "    SELECT 1 FROM itinerary_places ip " +
                "    WHERE ip.itinerary_id = d.itinerary_id " +
                "      AND ip.place_id = a.canonical_place_id" +
                "  )";

        int inserted = 0;
        try (Statement stmt = conn.createStatement()) {
            inserted = stmt.executeUpdate(insertSql);
        }

        log.info("--- [SampleItineraryPlaceMigration] Successfully backfilled {} itinerary_places entries! ---", inserted);
        return inserted;
    }

    private boolean isMySQLEngine(DatabaseMetaData meta) {
        try {
            String product = meta.getDatabaseProductName();
            return product != null && (product.toLowerCase().contains("mysql") || product.toLowerCase().contains("mariadb"));
        } catch (Exception e) {
            return false;
        }
    }

    private boolean acquireLockWithRetries(Connection conn) throws SQLException {
        for (int attempt = 1; attempt <= maxLockRetries; attempt++) {
            if (acquireLockOnConnection(conn)) {
                return true;
            }
            if (attempt < maxLockRetries && retryDelayMs > 0) {
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

    private boolean acquireLockOnConnection(Connection conn) throws SQLException {
        try (PreparedStatement stmt = conn.prepareStatement("SELECT GET_LOCK(?, ?)")) {
            stmt.setString(1, MIGRATION_LOCK);
            stmt.setInt(2, lockTimeoutSeconds);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    int result = rs.getInt(1);
                    return !rs.wasNull() && result == 1;
                }
            }
        }
        return false;
    }

    private void releaseLockOnConnection(Connection conn) {
        try (PreparedStatement stmt = conn.prepareStatement("SELECT RELEASE_LOCK(?)")) {
            stmt.setString(1, MIGRATION_LOCK);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    rs.getInt(1);
                }
            }
        } catch (Exception ignored) {
        }
    }

    private boolean tableExists(DatabaseMetaData meta, String catalog, String tableName) {
        try (ResultSet rs = meta.getTables(catalog, null, tableName, new String[]{"TABLE"})) {
            if (rs.next()) return true;
        } catch (Exception ignored) {}
        try (ResultSet rs = meta.getTables(catalog, null, tableName.toUpperCase(), new String[]{"TABLE"})) {
            if (rs.next()) return true;
        } catch (Exception ignored) {}
        try (ResultSet rs = meta.getTables(catalog, null, tableName.toLowerCase(), new String[]{"TABLE"})) {
            if (rs.next()) return true;
        } catch (Exception ignored) {}
        return false;
    }
}
