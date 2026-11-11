package Travel_Planner.Travel_Planner.config;

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

/**
 * Idempotent migration runner for Phase 2.1: Destination Consolidation into Place.
 * Implements an Expand-and-Contract database migration strategy.
 *
 * EXPAND:
 * 1. Adds 'canonical_place_id BIGINT NULL' column to 'activities' table.
 * 2. Adds index and foreign key referencing 'places(place_id)' ON DELETE SET NULL.
 * 3. Safely backfills 'canonical_place_id' for all existing activities linked to 'destinations'.
 * 4. Preserves 100% of activity location snapshots and provider place IDs.
 *
 * CONTRACT:
 * When enabled via 'app.migration.contract-destination=true' (after code and client migration):
 * 1. Drops legacy foreign key and 'destination_id' column from 'activities'.
 * 2. Drops 'destinations' table.
 * 3. Drops legacy 'source_destination_id' from 'places'.
 */
@Component
@Order(4)
public class DestinationConsolidationMigrationRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DestinationConsolidationMigrationRunner.class);
    public static final String MIGRATION_LOCK = "destination_consolidation_lock";

    private final DataSource dataSource;
    private int lockTimeoutSeconds = 5;
    private int maxLockRetries = 3;
    private long retryDelayMs = 500;
    private boolean strictLockRequired = false;

    @Value("${app.migration.contract-destination:false}")
    private boolean contractEnabled = false;

    @Autowired
    public DestinationConsolidationMigrationRunner(JdbcTemplate jdbcTemplate) {
        this.dataSource = jdbcTemplate.getDataSource();
    }

    public DestinationConsolidationMigrationRunner(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    public int getLockTimeoutSeconds() { return lockTimeoutSeconds; }
    public void setLockTimeoutSeconds(int seconds) { this.lockTimeoutSeconds = seconds; }

    public int getMaxLockRetries() { return maxLockRetries; }
    public void setMaxLockRetries(int retries) { this.maxLockRetries = retries; }

    public long getRetryDelayMs() { return retryDelayMs; }
    public void setRetryDelayMs(long delayMs) { this.retryDelayMs = delayMs; }

    public boolean isStrictLockRequired() { return strictLockRequired; }
    public void setStrictLockRequired(boolean strict) { this.strictLockRequired = strict; }

    public boolean isContractEnabled() { return contractEnabled; }
    public void setContractEnabled(boolean enabled) { this.contractEnabled = enabled; }

    @Override
    public void run(ApplicationArguments args) {
        migrateDestinationConsolidation();
    }

    public void migrateDestinationConsolidation() {
        if (dataSource == null) {
            log.warn("--- [DestinationConsolidation] DataSource is null, skipping migration. ---");
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
                    log.warn("--- [DestinationConsolidation] Advisory lock could not be acquired after {} attempts (timeout: {}s each). ---",
                            maxLockRetries, lockTimeoutSeconds);

                    if (!strictLockRequired && isExpandMigrationComplete(conn, meta, catalog)) {
                        log.info("--- [DestinationConsolidation] Lock unavailable, but consolidation schema is independently verified as complete. Proceeding safely. ---");
                        return;
                    }

                    throw new IllegalStateException("Failed to acquire Destination Consolidation migration advisory lock within retry window. Aborting startup.");
                }
            } else {
                log.info("--- [DestinationConsolidation] Database engine '{}' is non-MySQL. Advisory locking skipped safely. ---",
                        meta.getDatabaseProductName());
            }

            try {
                if (!tableExists(meta, catalog, "activities") || !tableExists(meta, catalog, "places")) {
                    log.info("--- [DestinationConsolidation] Required tables ('activities', 'places') not present yet. Skipping migration. ---");
                    return;
                }

                // Step 1: Expand Phase (Idempotent)
                executeExpandPhase(conn, meta, catalog);

                // Step 2: Contract Phase (If enabled)
                if (contractEnabled) {
                    executeContractPhase(conn, meta, catalog);
                }

                logConsolidationSummary(conn, meta, catalog);
            } finally {
                if (lockAcquired && isMySQL) {
                    releaseLockOnConnection(conn);
                }
            }
        } catch (IllegalStateException e) {
            log.error("--- [DestinationConsolidation] FATAL: Application startup aborted: {} ---", e.getMessage());
            throw e;
        } catch (SQLException e) {
            log.error("--- [DestinationConsolidation] Database error during migration: {} (SQLState: {}, ErrorCode: {}) ---",
                    e.getMessage(), e.getSQLState(), e.getErrorCode(), e);
            throw new RuntimeException("Destination consolidation migration failed", e);
        } catch (Exception e) {
            log.error("--- [DestinationConsolidation] Unexpected error during migration: {} ---", e.getMessage(), e);
            throw new RuntimeException("Destination consolidation migration failed", e);
        }
    }

    public void executeExpandPhase(Connection conn, DatabaseMetaData meta, String catalog) throws SQLException {
        boolean isMySQL = isMySQLEngine(meta);

        // 1. Ensure 'canonical_place_id' column exists on 'activities'
        if (!columnExists(meta, catalog, "activities", "canonical_place_id")) {
            log.info("--- [DestinationConsolidation] Adding 'canonical_place_id' column to 'activities' ---");
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("ALTER TABLE activities ADD COLUMN canonical_place_id BIGINT NULL");
            }
        }

        // 2. Ensure foreign key exists
        ensureForeignKey(conn, meta, catalog, "activities", "fk_activities_canonical_place",
                "ALTER TABLE activities ADD CONSTRAINT fk_activities_canonical_place " +
                        "FOREIGN KEY (canonical_place_id) REFERENCES places(place_id) ON DELETE SET NULL");

        // 3. Ensure index exists
        ensureIndex(conn, meta, catalog, "activities", "idx_activities_canonical_place",
                "CREATE INDEX idx_activities_canonical_place ON activities(canonical_place_id)");

        // 4. Backfill canonical_place_id from legacy destination_id if destinations table and column exist
        if (tableExists(meta, catalog, "destinations") && columnExists(meta, catalog, "activities", "destination_id")) {
            backfillCanonicalPlaceIds(conn, isMySQL);
        }
    }

    public void executeContractPhase(Connection conn, DatabaseMetaData meta, String catalog) throws SQLException {
        log.info("--- [DestinationConsolidation] CONTRACT PHASE: Removing legacy Destination schema ---");

        // Pre-condition check: ensure 0 activities remain unmigrated before dropping legacy columns
        if (tableExists(meta, catalog, "destinations") && columnExists(meta, catalog, "activities", "destination_id")) {
            try (Statement stmt = conn.createStatement();
                 ResultSet rs = stmt.executeQuery(
                         "SELECT COUNT(*) FROM activities WHERE destination_id IS NOT NULL AND canonical_place_id IS NULL")) {
                if (rs.next()) {
                    int unmigrated = rs.getInt(1);
                    if (unmigrated > 0) {
                        throw new IllegalStateException("Cannot execute CONTRACT phase: " + unmigrated +
                                " activities still have unmigrated destination_id. Aborting contract to prevent data loss.");
                    }
                }
            }
        }

        // 1. Drop foreign key constraint on activities.destination_id if exists
        dropForeignKeyIfExists(conn, meta, catalog, "activities", "FK2oooqkhm3kxy3yijondygnl9x");

        // 2. Drop foreign key constraint on places.source_destination_id if exists
        dropForeignKeyIfExists(conn, meta, catalog, "places", "fk_places_source_destination");

        // 3. Drop column destination_id from activities
        if (columnExists(meta, catalog, "activities", "destination_id")) {
            log.info("--- [DestinationConsolidation] Dropping column 'activities.destination_id' ---");
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("ALTER TABLE activities DROP COLUMN destination_id");
            }
        }

        // 4. Drop column source_destination_id from places
        if (columnExists(meta, catalog, "places", "source_destination_id")) {
            log.info("--- [DestinationConsolidation] Dropping column 'places.source_destination_id' ---");
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("ALTER TABLE places DROP COLUMN source_destination_id");
            }
        }

        // 5. Drop table destinations
        if (tableExists(meta, catalog, "destinations")) {
            log.info("--- [DestinationConsolidation] Dropping table 'destinations' ---");
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("DROP TABLE destinations");
            }
        }

        log.info("--- [DestinationConsolidation] CONTRACT PHASE: Completed successfully. ---");
    }

    private void backfillCanonicalPlaceIds(Connection conn, boolean isMySQL) throws SQLException {
        // Find count of activities needing backfill
        String countSql = "SELECT COUNT(*) FROM activities a " +
                "JOIN destinations d ON a.destination_id = d.destination_id " +
                "WHERE a.canonical_place_id IS NULL AND a.destination_id IS NOT NULL";

        int needBackfill = 0;
        try (Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(countSql)) {
            if (rs.next()) {
                needBackfill = rs.getInt(1);
            }
        }

        if (needBackfill > 0) {
            log.info("--- [DestinationConsolidation] Found {} activities with legacy destination_id needing canonical_place_id backfill. Backfilling... ---", needBackfill);
            String updateSql;
            if (isMySQL) {
                updateSql = "UPDATE activities a " +
                        "JOIN destinations d ON a.destination_id = d.destination_id " +
                        "SET a.canonical_place_id = d.place_id " +
                        "WHERE a.canonical_place_id IS NULL AND a.destination_id IS NOT NULL";
                try (Statement stmt = conn.createStatement()) {
                    int updated = stmt.executeUpdate(updateSql);
                    log.info("--- [DestinationConsolidation] Successfully backfilled {} activities with canonical_place_id ---", updated);
                }
            } else {
                // ANSI SQL fallback (e.g. H2 for tests)
                updateSql = "UPDATE activities SET canonical_place_id = (" +
                        "SELECT d.place_id FROM destinations d WHERE d.destination_id = activities.destination_id" +
                        ") WHERE canonical_place_id IS NULL AND destination_id IS NOT NULL";
                try (Statement stmt = conn.createStatement()) {
                    int updated = stmt.executeUpdate(updateSql);
                    log.info("--- [DestinationConsolidation] Successfully backfilled {} activities with canonical_place_id (ANSI) ---", updated);
                }
            }
        } else {
            log.info("--- [DestinationConsolidation] All activities already have canonical_place_id mapped (0 backfills needed) ---");
        }
    }

    private void ensureForeignKey(Connection conn, DatabaseMetaData meta, String catalog,
                                  String table, String fkName, String addFkSql) {
        if (!foreignKeyExists(meta, catalog, table, fkName)) {
            log.info("--- [DestinationConsolidation] Creating foreign key '{}' on '{}' ---", fkName, table);
            try (Statement stmt = conn.createStatement()) {
                stmt.execute(addFkSql);
            } catch (SQLException e) {
                log.warn("--- [DestinationConsolidation] Note on FK creation '{}': {} ---", fkName, e.getMessage());
            }
        }
    }

    private void ensureIndex(Connection conn, DatabaseMetaData meta, String catalog,
                             String table, String indexName, String createIndexSql) {
        if (!indexExists(meta, catalog, table, indexName)) {
            log.info("--- [DestinationConsolidation] Creating index '{}' on '{}' ---", indexName, table);
            try (Statement stmt = conn.createStatement()) {
                stmt.execute(createIndexSql);
            } catch (SQLException e) {
                log.warn("--- [DestinationConsolidation] Note on index creation '{}': {} ---", indexName, e.getMessage());
            }
        }
    }

    private void dropForeignKeyIfExists(Connection conn, DatabaseMetaData meta, String catalog,
                                       String table, String fkName) {
        try {
            // Find actual constraint name on destination_id column if fkName does not match
            String actualConstraint = fkName;
            try (ResultSet rs = meta.getImportedKeys(catalog, null, table)) {
                while (rs.next()) {
                    String col = rs.getString("FKCOLUMN_NAME");
                    String pkTable = rs.getString("PKTABLE_NAME");
                    if ("destination_id".equalsIgnoreCase(col) || "destinations".equalsIgnoreCase(pkTable)) {
                        actualConstraint = rs.getString("FK_NAME");
                        break;
                    }
                }
            }

            if (actualConstraint != null) {
                log.info("--- [DestinationConsolidation] Dropping foreign key constraint '{}' from '{}' ---", actualConstraint, table);
                try (Statement stmt = conn.createStatement()) {
                    stmt.execute("ALTER TABLE " + table + " DROP FOREIGN KEY " + actualConstraint);
                }
            }
        } catch (SQLException e) {
            log.warn("--- [DestinationConsolidation] Note on dropping FK constraint: {} ---", e.getMessage());
        }
    }

    private boolean isExpandMigrationComplete(Connection conn, DatabaseMetaData meta, String catalog) {
        try {
            if (!columnExists(meta, catalog, "activities", "canonical_place_id")) {
                return false;
            }
            if (tableExists(meta, catalog, "destinations") && columnExists(meta, catalog, "activities", "destination_id")) {
                try (Statement stmt = conn.createStatement();
                     ResultSet rs = stmt.executeQuery(
                             "SELECT COUNT(*) FROM activities WHERE destination_id IS NOT NULL AND canonical_place_id IS NULL")) {
                    if (rs.next()) {
                        return rs.getInt(1) == 0;
                    }
                }
            }
            return true;
        } catch (Exception e) {
            log.warn("--- [DestinationConsolidation] Error checking invariants: {} ---", e.getMessage());
            return false;
        }
    }

    private void logConsolidationSummary(Connection conn, DatabaseMetaData meta, String catalog) throws SQLException {
        try (Statement stmt = conn.createStatement()) {
            int totalActivities = 0;
            int withCanonicalPlace = 0;
            int withSnapshot = 0;

            try (ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM activities")) {
                if (rs.next()) totalActivities = rs.getInt(1);
            }

            try (ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM activities WHERE canonical_place_id IS NOT NULL")) {
                if (rs.next()) withCanonicalPlace = rs.getInt(1);
            }

            try (ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM activities WHERE location_name IS NOT NULL AND latitude IS NOT NULL AND longitude IS NOT NULL")) {
                if (rs.next()) withSnapshot = rs.getInt(1);
            }

            log.info("--- [DestinationConsolidation] Summary: {} total activities, {} with canonical_place_id, {} with authoritative snapshot ---",
                    totalActivities, withCanonicalPlace, withSnapshot);
        }
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
            log.info("--- [DestinationConsolidation] Attempting to acquire advisory lock (attempt {}/{} with {}s timeout)... ---",
                    attempt, maxLockRetries, lockTimeoutSeconds);
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
                    int result = rs.getInt(1);
                    if (rs.wasNull() || result != 1) {
                        log.warn("--- [DestinationConsolidation] RELEASE_LOCK returned {} (not 1). ---", result);
                    } else {
                        log.info("--- [DestinationConsolidation] Advisory lock successfully released on connection. ---");
                    }
                }
            }
        } catch (SQLException e) {
            log.warn("--- [DestinationConsolidation] Failed to release advisory lock: {} ---", e.getMessage());
        }
    }

    public boolean tableExists(DatabaseMetaData meta, String catalog, String table) {
        try (ResultSet rs = meta.getTables(catalog, null, table, new String[]{"TABLE"})) {
            if (rs.next()) return true;
        } catch (Exception ignored) {}
        try (ResultSet rs = meta.getTables(catalog, null, table.toUpperCase(), new String[]{"TABLE"})) {
            if (rs.next()) return true;
        } catch (Exception ignored) {}
        return false;
    }

    public boolean columnExists(DatabaseMetaData meta, String catalog, String table, String column) {
        try (ResultSet rs = meta.getColumns(catalog, null, table, column)) {
            if (rs.next()) return true;
        } catch (Exception ignored) {}
        try (ResultSet rs = meta.getColumns(catalog, null, table.toUpperCase(), column.toUpperCase())) {
            if (rs.next()) return true;
        } catch (Exception ignored) {}
        return false;
    }

    private boolean indexExists(DatabaseMetaData meta, String catalog, String table, String indexName) {
        try (ResultSet rs = meta.getIndexInfo(catalog, null, table, false, false)) {
            while (rs.next()) {
                String name = rs.getString("INDEX_NAME");
                if (indexName.equalsIgnoreCase(name)) return true;
            }
        } catch (Exception ignored) {}
        return false;
    }

    private boolean foreignKeyExists(DatabaseMetaData meta, String catalog, String table, String fkName) {
        try (ResultSet rs = meta.getImportedKeys(catalog, null, table)) {
            while (rs.next()) {
                String name = rs.getString("FK_NAME");
                if (fkName.equalsIgnoreCase(name)) return true;
            }
        } catch (Exception ignored) {}
        return false;
    }
}
