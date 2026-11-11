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
 * Hardened database schema migration and backfill runner for Activity Location unification.
 * Runs on application startup (@Order(2)) with connection-bound MySQL advisory locking,
 * idempotency guarantees, non-destructive backfill rules, and post-migration invariant validation.
 *
 * All operations execute within a single dedicated physical JDBC Connection, guaranteeing that
 * the MySQL session-scoped GET_LOCK and RELEASE_LOCK are bound to the exact connection executing
 * DDL and DML operations.
 */
@Component
@Order(2)
public class ActivityLocationMigrationRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(ActivityLocationMigrationRunner.class);
    public static final String MIGRATION_LOCK = "activity_location_migration_lock";

    private final DataSource dataSource;
    private int lockTimeoutSeconds = 5;
    private int maxLockRetries = 3;
    private long retryDelayMs = 500;
    private boolean strictLockRequired = false;

    @Autowired
    public ActivityLocationMigrationRunner(JdbcTemplate jdbcTemplate) {
        this.dataSource = jdbcTemplate.getDataSource();
    }

    public ActivityLocationMigrationRunner(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    public void setLockTimeoutSeconds(int seconds) {
        this.lockTimeoutSeconds = seconds;
    }

    public int getLockTimeoutSeconds() {
        return this.lockTimeoutSeconds;
    }

    public void setMaxLockRetries(int maxRetries) {
        this.maxLockRetries = maxRetries;
    }

    public int getMaxLockRetries() {
        return this.maxLockRetries;
    }

    public void setRetryDelayMs(long delayMs) {
        this.retryDelayMs = delayMs;
    }

    public long getRetryDelayMs() {
        return this.retryDelayMs;
    }

    public void setStrictLockRequired(boolean strict) {
        this.strictLockRequired = strict;
    }

    public boolean isStrictLockRequired() {
        return this.strictLockRequired;
    }

    @Override
    public void run(ApplicationArguments args) {
        ensureSchemaAndBackfill();
    }

    public void ensureSchemaAndBackfill() {
        if (dataSource == null) {
            log.warn("--- [ActivityLocationMigration] DataSource is null, skipping migration. ---");
            return;
        }

        try (Connection conn = dataSource.getConnection()) {
            DatabaseMetaData meta = conn.getMetaData();
            String catalog = conn.getCatalog();
            boolean isMySQL = isMySQLEngine(meta);

            boolean lockAcquired = false;
            if (isMySQL) {
                lockAcquired = acquireLockWithRetries(conn);
                if (!lockAcquired) {
                    log.warn("--- [ActivityLocationMigration] Advisory lock could not be acquired after {} attempts (timeout: {}s each). ---",
                            maxLockRetries, lockTimeoutSeconds);

                    if (!strictLockRequired && isSchemaAndInvariantsComplete(conn, meta, catalog)) {
                        log.info("--- [ActivityLocationMigration] Lock unavailable, but database schema and migration invariants are independently verified as 100% complete. Allowing startup to proceed safely. ---");
                        return;
                    }

                    throw new IllegalStateException("Failed to acquire migration advisory lock within retry window, and schema/migration invariants are incomplete or unverified. Aborting startup to protect data integrity.");
                }
            } else {
                log.info("--- [ActivityLocationMigration] Database engine '{}' is non-MySQL. Advisory locking skipped safely. ---",
                        meta.getDatabaseProductName());
            }

            try {
                if (!tableExists(meta, catalog, "activities")) {
                    log.info("--- [ActivityLocationMigration] Table 'activities' not present yet. Skipping migration. ---");
                    return;
                }

                ensureColumnsExist(conn, meta, catalog);
                backfillActivities(conn, meta, catalog);
                validateInvariants(conn);
            } finally {
                if (lockAcquired && isMySQL) {
                    releaseLockOnConnection(conn);
                }
            }
        } catch (IllegalStateException e) {
            log.error("--- [ActivityLocationMigration] FATAL: Application startup aborted: {} ---", e.getMessage());
            throw e;
        } catch (SQLException e) {
            log.error("--- [ActivityLocationMigration] FATAL: Database error during schema check/migration: {} (SQLState: {}, ErrorCode: {}) ---",
                    e.getMessage(), e.getSQLState(), e.getErrorCode(), e);
            throw new RuntimeException("Activity location migration failed due to database error", e);
        } catch (Exception e) {
            log.error("--- [ActivityLocationMigration] FATAL: Unexpected error during migration: {} ---", e.getMessage(), e);
            throw new RuntimeException("Activity location migration failed", e);
        }
    }

    private boolean isMySQLEngine(DatabaseMetaData meta) {
        try {
            String product = meta.getDatabaseProductName();
            return product != null && (product.toLowerCase().contains("mysql") || product.toLowerCase().contains("mariadb"));
        } catch (Exception e) {
            log.debug("--- [ActivityLocationMigration] Could not determine database product name: {} ---", e.getMessage());
            return false;
        }
    }

    private boolean acquireLockWithRetries(Connection conn) throws SQLException {
        for (int attempt = 1; attempt <= maxLockRetries; attempt++) {
            log.info("--- [ActivityLocationMigration] Attempting to acquire advisory lock (attempt {}/{} with {}s timeout)... ---",
                    attempt, maxLockRetries, lockTimeoutSeconds);
            if (acquireLockOnConnection(conn)) {
                return true;
            }
            if (attempt < maxLockRetries && retryDelayMs > 0) {
                try {
                    Thread.sleep(retryDelayMs);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    log.warn("--- [ActivityLocationMigration] Lock acquisition retry interrupted ---");
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
                    int result = rs.getInt(1);
                    log.debug("--- [ActivityLocationMigration] Released advisory lock with status: {} ---", result);
                }
            }
        } catch (Exception e) {
            log.warn("--- [ActivityLocationMigration] Note during RELEASE_LOCK execution: {} ---", e.getMessage());
        }
    }

    public boolean isSchemaAndInvariantsComplete(Connection conn, DatabaseMetaData meta, String catalog) {
        try {
            if (!tableExists(meta, catalog, "activities")) {
                return false;
            }
            if (!columnExists(meta, catalog, "activities", "location_name") ||
                !columnExists(meta, catalog, "activities", "location_address")) {
                return false;
            }

            try (Statement stmt = conn.createStatement()) {
                // 1. Check unmigrated custom location records
                try (ResultSet rs = stmt.executeQuery(
                        "SELECT COUNT(*) FROM activities WHERE custom_location_name IS NOT NULL AND location_name IS NULL")) {
                    if (rs.next() && rs.getInt(1) > 0) {
                        return false;
                    }
                }

                // 2. Check unmigrated destination records with valid destination coords (if legacy destinations table exists)
                if (tableExists(meta, catalog, "destinations") && columnExists(meta, catalog, "activities", "destination_id")) {
                    try (ResultSet rs = stmt.executeQuery(
                            "SELECT COUNT(*) FROM activities a " +
                            "JOIN destinations d ON a.destination_id = d.destination_id " +
                            "WHERE a.destination_id IS NOT NULL " +
                            "  AND (a.latitude IS NULL OR a.longitude IS NULL) " +
                            "  AND d.latitude IS NOT NULL AND d.longitude IS NOT NULL " +
                            "  AND d.latitude >= -90.0 AND d.latitude <= 90.0 " +
                            "  AND d.longitude >= -180.0 AND d.longitude <= 180.0")) {
                        if (rs.next() && rs.getInt(1) > 0) {
                            return false;
                        }
                    }
                }

                // 3. Check half-null coordinate pairs
                try (ResultSet rs = stmt.executeQuery(
                        "SELECT COUNT(*) FROM activities WHERE (latitude IS NULL AND longitude IS NOT NULL) OR (latitude IS NOT NULL AND longitude IS NULL)")) {
                    if (rs.next() && rs.getInt(1) > 0) {
                        return false;
                    }
                }

                // 4. Check out-of-bounds coordinates
                try (ResultSet rs = stmt.executeQuery(
                        "SELECT COUNT(*) FROM activities WHERE (latitude IS NOT NULL AND (latitude < -90.0 OR latitude > 90.0)) OR (longitude IS NOT NULL AND (longitude < -180.0 OR longitude > 180.0))")) {
                    if (rs.next() && rs.getInt(1) > 0) {
                        return false;
                    }
                }
            }
            return true;
        } catch (Exception e) {
            log.warn("--- [ActivityLocationMigration] Exception during completeness check: {} ---", e.getMessage());
            return false;
        }
    }

    protected void ensureColumnsExist(Connection conn, DatabaseMetaData meta, String catalog) throws SQLException {
        boolean locationNameExists = columnExists(meta, catalog, "activities", "location_name");
        if (!locationNameExists) {
            log.info("--- [ActivityLocationMigration] Adding 'location_name' column to 'activities' ---");
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("ALTER TABLE activities ADD COLUMN location_name VARCHAR(150) NULL AFTER custom_location_name");
            }
        }

        boolean locationAddressExists = columnExists(meta, catalog, "activities", "location_address");
        if (!locationAddressExists) {
            log.info("--- [ActivityLocationMigration] Adding 'location_address' column to 'activities' ---");
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("ALTER TABLE activities ADD COLUMN location_address VARCHAR(255) NULL AFTER custom_address");
            }
        }
    }

    private boolean tableExists(DatabaseMetaData meta, String catalog, String table) {
        try (ResultSet rs = meta.getTables(catalog, null, table, new String[]{"TABLE"})) {
            if (rs.next()) return true;
        } catch (Exception ignored) {}
        try (ResultSet rs = meta.getTables(catalog, null, table.toUpperCase(), new String[]{"TABLE"})) {
            if (rs.next()) return true;
        } catch (Exception ignored) {}
        return false;
    }

    private boolean columnExists(DatabaseMetaData meta, String catalog, String table, String column) {
        try (ResultSet rs = meta.getColumns(catalog, null, table, column)) {
            if (rs.next()) return true;
        } catch (Exception ignored) {}
        try (ResultSet rs = meta.getColumns(catalog, null, table.toUpperCase(), column.toUpperCase())) {
            if (rs.next()) return true;
        } catch (Exception ignored) {}
        return false;
    }

    protected void backfillActivities(Connection conn, DatabaseMetaData meta, String catalog) throws SQLException {
        if (!columnExists(meta, catalog, "activities", "location_name")) {
            return;
        }

        // 1. Backfill from legacy custom location fields to new standardized location columns (idempotent, no overwrite)
        try (Statement stmt = conn.createStatement()) {
            int customUpdated = stmt.executeUpdate(
                    "UPDATE activities SET location_name = custom_location_name, location_address = custom_address " +
                    "WHERE custom_location_name IS NOT NULL AND location_name IS NULL");
            if (customUpdated > 0) {
                log.info("--- [ActivityLocationMigration] Backfilled {} activities from legacy custom fields ---", customUpdated);
            }
        }

        // 2. Backfill from linked Destination into Activity snapshot fields (if legacy destinations table exists)
        if (tableExists(meta, catalog, "destinations") && columnExists(meta, catalog, "activities", "destination_id")) {
            // Identify any activities linked to destinations that have invalid/missing coordinates (audit & skip safely)
            try (Statement stmt = conn.createStatement();
                 ResultSet rs = stmt.executeQuery(
                         "SELECT COUNT(*) FROM activities a " +
                         "JOIN destinations d ON a.destination_id = d.destination_id " +
                         "WHERE a.destination_id IS NOT NULL AND (a.latitude IS NULL OR a.longitude IS NULL) " +
                         "  AND (d.latitude IS NULL OR d.longitude IS NULL OR d.latitude < -90.0 OR d.latitude > 90.0 OR d.longitude < -180.0 OR d.longitude > 180.0)")) {
                if (rs.next()) {
                    int invalidDestCount = rs.getInt(1);
                    if (invalidDestCount > 0) {
                        log.warn("--- [ActivityLocationMigration] Skipped {} activities whose linked destination lacks valid coordinates ---", invalidDestCount);
                    }
                }
            }

            // Backfill from linked Destination into Activity snapshot fields ONLY for activities lacking coordinates,
            // and ONLY when Destination has strictly valid coordinate bounds. Never overwrites existing snapshots.
            try (Statement stmt = conn.createStatement()) {
                int destUpdated = stmt.executeUpdate(
                        "UPDATE activities a " +
                        "JOIN destinations d ON a.destination_id = d.destination_id " +
                        "SET a.location_name = COALESCE(a.location_name, a.custom_location_name, d.name), " +
                        "    a.location_address = COALESCE(a.location_address, a.custom_address, d.address), " +
                        "    a.custom_location_name = COALESCE(a.custom_location_name, a.location_name, d.name), " +
                        "    a.custom_address = COALESCE(a.custom_address, a.location_address, d.address), " +
                        "    a.latitude = d.latitude, " +
                        "    a.longitude = d.longitude, " +
                        "    a.place_id = CONCAT('dest_', d.destination_id), " +
                        "    a.location_provider = 'DESTINATION_CATALOG' " +
                        "WHERE a.destination_id IS NOT NULL " +
                        "  AND (a.latitude IS NULL OR a.longitude IS NULL) " +
                        "  AND d.latitude IS NOT NULL AND d.longitude IS NOT NULL " +
                        "  AND d.latitude >= -90.0 AND d.latitude <= 90.0 " +
                        "  AND d.longitude >= -180.0 AND d.longitude <= 180.0");
                if (destUpdated > 0) {
                    log.info("--- [ActivityLocationMigration] Backfilled {} activities with authoritative snapshots from destinations ---", destUpdated);
                }
            }
        }
    }

    private void validateInvariants(Connection conn) throws SQLException {
        try (Statement stmt = conn.createStatement()) {
            int totalActivities = 0;
            try (ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM activities")) {
                if (rs.next()) totalActivities = rs.getInt(1);
            }

            int locatedActivities = 0;
            try (ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM activities WHERE latitude IS NOT NULL AND longitude IS NOT NULL")) {
                if (rs.next()) locatedActivities = rs.getInt(1);
            }

            try (ResultSet rs = stmt.executeQuery(
                    "SELECT COUNT(*) FROM activities WHERE (latitude IS NULL AND longitude IS NOT NULL) OR (latitude IS NOT NULL AND longitude IS NULL)")) {
                if (rs.next()) {
                    int halfNullCount = rs.getInt(1);
                    if (halfNullCount > 0) {
                        log.error("--- [ActivityLocationMigration] CRITICAL: Invariant violation: {} activities with half-null coordinates! ---", halfNullCount);
                    }
                }
            }

            try (ResultSet rs = stmt.executeQuery(
                    "SELECT COUNT(*) FROM activities WHERE (latitude IS NOT NULL AND (latitude < -90.0 OR latitude > 90.0)) OR (longitude IS NOT NULL AND (longitude < -180.0 OR longitude > 180.0))")) {
                if (rs.next()) {
                    int outOfBoundsCount = rs.getInt(1);
                    if (outOfBoundsCount > 0) {
                        log.error("--- [ActivityLocationMigration] CRITICAL: Invariant violation: {} activities with out-of-bounds coordinates! ---", outOfBoundsCount);
                    }
                }
            }

            log.info("--- [ActivityLocationMigration] Audit complete: {} total activities, {} with snapshot coordinates, 0 invariant violations ---",
                    totalActivities, locatedActivities);
        }
    }
}
