package Travel_Planner.Travel_Planner.config;

import Travel_Planner.Travel_Planner.service.impl.LocationRankingServiceImpl;
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
 * Idempotent migration and synchronization runner for Phase 2: Place Catalog.
 * Seeds and synchronizes curated records from 'destinations' into the canonical 'places' catalog
 * and establishes provider mappings in 'place_provider_mappings' with zero duplication.
 *
 * All operations execute within a single dedicated physical JDBC Connection, guaranteeing that
 * the MySQL session-scoped GET_LOCK and RELEASE_LOCK are bound to the exact connection executing
 * DDL and DML operations.
 */
@Component
@Order(3)
public class PlaceCatalogMigrationRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(PlaceCatalogMigrationRunner.class);
    public static final String MIGRATION_LOCK = "place_catalog_migration_lock";

    private final DataSource dataSource;
    private int lockTimeoutSeconds = 5;
    private int maxLockRetries = 3;
    private long retryDelayMs = 500;
    private boolean strictLockRequired = false;

    @Autowired
    public PlaceCatalogMigrationRunner(JdbcTemplate jdbcTemplate) {
        this.dataSource = jdbcTemplate.getDataSource();
    }

    public PlaceCatalogMigrationRunner(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    public int getLockTimeoutSeconds() { return lockTimeoutSeconds; }
    public int getMaxLockRetries() { return maxLockRetries; }
    public long getRetryDelayMs() { return retryDelayMs; }
    public boolean isStrictLockRequired() { return strictLockRequired; }

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
        syncDestinationsToPlaces();
    }

    public void syncDestinationsToPlaces() {
        if (dataSource == null) {
            log.warn("--- [PlaceCatalogMigration] DataSource is null, skipping sync. ---");
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
                    log.warn("--- [PlaceCatalogMigration] Advisory lock could not be acquired after {} attempts (timeout: {}s each). ---",
                            maxLockRetries, lockTimeoutSeconds);

                    if (!strictLockRequired && isPlaceCatalogComplete(conn, meta, catalog)) {
                        log.info("--- [PlaceCatalogMigration] Lock unavailable, but Place Catalog schema and migration invariants are independently verified as 100% complete. Allowing startup to proceed safely. ---");
                        return;
                    }

                    throw new IllegalStateException("Failed to acquire Place Catalog migration advisory lock within retry window, and schema/migration invariants are incomplete or unverified. Aborting startup to protect data integrity.");
                }
            } else {
                log.info("--- [PlaceCatalogMigration] Database engine '{}' is non-MySQL. Advisory locking skipped safely. ---",
                        meta.getDatabaseProductName());
            }

            try {
                if (!tableExists(meta, catalog, "destinations") || !tableExists(meta, catalog, "places")) {
                    log.info("--- [PlaceCatalogMigration] Required tables ('destinations', 'places') not present yet. Skipping sync. ---");
                    return;
                }

                ensureDestinationPlaceIdColumn(conn, meta, catalog);
                importDestinationsAsCanonicalPlaces(conn);
                logPlaceCatalogSummary(conn);
            } finally {
                if (lockAcquired && isMySQL) {
                    releaseLockOnConnection(conn);
                }
            }
        } catch (IllegalStateException e) {
            log.error("--- [PlaceCatalogMigration] FATAL: Application startup aborted: {} ---", e.getMessage());
            throw e;
        } catch (SQLException e) {
            log.error("--- [PlaceCatalogMigration] Database error during Place Catalog migration: {} (SQLState: {}, ErrorCode: {}) ---",
                    e.getMessage(), e.getSQLState(), e.getErrorCode(), e);
            throw new RuntimeException("Place catalog migration failed", e);
        } catch (Exception e) {
            log.error("--- [PlaceCatalogMigration] Unexpected error during Place Catalog migration: {} ---", e.getMessage(), e);
            throw new RuntimeException("Place catalog migration failed", e);
        }
    }

    private boolean isMySQLEngine(DatabaseMetaData meta) {
        try {
            String product = meta.getDatabaseProductName();
            return product != null && (product.toLowerCase().contains("mysql") || product.toLowerCase().contains("mariadb"));
        } catch (Exception e) {
            log.debug("--- [PlaceCatalogMigration] Could not determine database product name: {} ---", e.getMessage());
            return false;
        }
    }

    private boolean acquireLockWithRetries(Connection conn) throws SQLException {
        for (int attempt = 1; attempt <= maxLockRetries; attempt++) {
            log.info("--- [PlaceCatalogMigration] Attempting to acquire advisory lock (attempt {}/{} with {}s timeout)... ---",
                    attempt, maxLockRetries, lockTimeoutSeconds);
            if (acquireLockOnConnection(conn)) {
                return true;
            }
            if (attempt < maxLockRetries && retryDelayMs > 0) {
                try {
                    Thread.sleep(retryDelayMs);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    log.warn("--- [PlaceCatalogMigration] Lock acquisition retry interrupted ---");
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
                        log.warn("--- [PlaceCatalogMigration] RELEASE_LOCK returned {} (not 1). Lock may not have been held by this connection. ---", result);
                    } else {
                        log.info("--- [PlaceCatalogMigration] Advisory lock successfully released on connection. ---");
                    }
                }
            }
        } catch (SQLException e) {
            log.warn("--- [PlaceCatalogMigration] Failed to release advisory lock: {} ---", e.getMessage());
        }
    }

    private boolean isPlaceCatalogComplete(Connection conn, DatabaseMetaData meta, String catalog) {
        try {
            if (!tableExists(meta, catalog, "destinations") || !tableExists(meta, catalog, "places")
                    || !tableExists(meta, catalog, "place_provider_mappings")) {
                return false;
            }
            if (!columnExists(meta, catalog, "destinations", "place_id")) {
                return false;
            }
            try (Statement stmt = conn.createStatement();
                 ResultSet rs = stmt.executeQuery(
                         "SELECT COUNT(*) FROM destinations WHERE latitude IS NOT NULL AND longitude IS NOT NULL AND place_id IS NULL")) {
                if (rs.next()) {
                    return rs.getInt(1) == 0;
                }
            }
            return true;
        } catch (Exception e) {
            log.warn("--- [PlaceCatalogMigration] Error checking invariants: {} ---", e.getMessage());
            return false;
        }
    }

    private void ensureDestinationPlaceIdColumn(Connection conn, DatabaseMetaData meta, String catalog) throws SQLException {
        if (!columnExists(meta, catalog, "destinations", "place_id")) {
            log.info("--- [PlaceCatalogMigration] Adding 'place_id' column to 'destinations' table ---");
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("ALTER TABLE destinations ADD COLUMN place_id BIGINT NULL");
            }
        }
    }

    private void importDestinationsAsCanonicalPlaces(Connection conn) throws SQLException {
        String queryDestinations = "SELECT destination_id, name, address, description, image_url, latitude, longitude, status " +
                "FROM destinations WHERE latitude IS NOT NULL AND longitude IS NOT NULL";

        String checkMappingSql = "SELECT place_id FROM place_provider_mappings WHERE provider = ? AND provider_place_id = ?";
        String insertPlaceSql = "INSERT INTO places (name, normalized_name, address, description, image_url, " +
                "latitude, longitude, category, status, source_destination_id, created_at, updated_at) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, 'ATTRACTION', ?, ?, NOW(), NOW())";
        String insertMappingSql = "INSERT INTO place_provider_mappings (place_id, provider, provider_place_id, " +
                "provider_type, metadata_json, last_synced_at) VALUES (?, 'DESTINATION_CATALOG', ?, 'destination', ?, NOW())";
        String updateDestSql = "UPDATE destinations SET place_id = ? WHERE destination_id = ?";

        int insertedCount = 0;
        int linkedCount = 0;

        try (Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(queryDestinations);
             PreparedStatement checkMappingStmt = conn.prepareStatement(checkMappingSql);
             PreparedStatement insertPlaceStmt = conn.prepareStatement(insertPlaceSql, Statement.RETURN_GENERATED_KEYS);
             PreparedStatement insertMappingStmt = conn.prepareStatement(insertMappingSql);
             PreparedStatement updateDestStmt = conn.prepareStatement(updateDestSql)) {

            while (rs.next()) {
                int destId = rs.getInt("destination_id");
                String name = rs.getString("name");
                String address = rs.getString("address");
                String description = rs.getString("description");
                String imageUrl = rs.getString("image_url");
                double lat = rs.getDouble("latitude");
                double lon = rs.getDouble("longitude");
                String status = rs.getString("status");

                String providerPlaceId = "dest_" + destId;
                checkMappingStmt.setString(1, "DESTINATION_CATALOG");
                checkMappingStmt.setString(2, providerPlaceId);

                Long existingPlaceId = null;
                try (ResultSet mappingRs = checkMappingStmt.executeQuery()) {
                    if (mappingRs.next()) {
                        existingPlaceId = mappingRs.getLong("place_id");
                    }
                }

                if (existingPlaceId == null) {
                    // Insert new canonical Place
                    String normName = LocationRankingServiceImpl.normalizeText(name);
                    String placeStatus = "HIDDEN".equalsIgnoreCase(status) ? "HIDDEN" : "ACTIVE";

                    insertPlaceStmt.setString(1, name);
                    insertPlaceStmt.setString(2, normName);
                    insertPlaceStmt.setString(3, address != null ? address : "");
                    insertPlaceStmt.setString(4, description);
                    insertPlaceStmt.setString(5, imageUrl);
                    insertPlaceStmt.setDouble(6, lat);
                    insertPlaceStmt.setDouble(7, lon);
                    insertPlaceStmt.setString(8, placeStatus);
                    insertPlaceStmt.setInt(9, destId);

                    insertPlaceStmt.executeUpdate();

                    try (ResultSet generatedKeys = insertPlaceStmt.getGeneratedKeys()) {
                        if (generatedKeys.next()) {
                            long newPlaceId = generatedKeys.getLong(1);

                            // Insert mapping
                            insertMappingStmt.setLong(1, newPlaceId);
                            insertMappingStmt.setString(2, providerPlaceId);
                            insertMappingStmt.setString(3, "{\"destination_id\":" + destId + "}");
                            insertMappingStmt.executeUpdate();

                            // Link destination
                            updateDestStmt.setLong(1, newPlaceId);
                            updateDestStmt.setInt(2, destId);
                            updateDestStmt.executeUpdate();

                            insertedCount++;
                        }
                    }
                } else {
                    // Update destination place_id if needed
                    updateDestStmt.setLong(1, existingPlaceId);
                    updateDestStmt.setInt(2, destId);
                    int updated = updateDestStmt.executeUpdate();
                    if (updated > 0) {
                        linkedCount++;
                    }
                }
            }
        }

        if (insertedCount > 0) {
            log.info("--- [PlaceCatalogMigration] Successfully imported {} curated Destinations into canonical Places ---", insertedCount);
        } else {
            log.info("--- [PlaceCatalogMigration] All Destinations are already synchronized with Place Catalog (0 new imported) ---");
        }
    }

    private void logPlaceCatalogSummary(Connection conn) throws SQLException {
        try (Statement stmt = conn.createStatement()) {
            int totalPlaces = 0;
            try (ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM places")) {
                if (rs.next()) totalPlaces = rs.getInt(1);
            }

            int totalMappings = 0;
            try (ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM place_provider_mappings")) {
                if (rs.next()) totalMappings = rs.getInt(1);
            }

            log.info("--- [PlaceCatalogMigration] Place Catalog status: {} total places, {} provider mappings ---",
                    totalPlaces, totalMappings);
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
}

