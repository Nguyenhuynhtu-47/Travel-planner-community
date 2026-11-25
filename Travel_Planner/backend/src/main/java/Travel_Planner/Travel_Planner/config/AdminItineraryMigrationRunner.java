package Travel_Planner.Travel_Planner.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.HashSet;
import java.util.Set;

/**
 * Idempotent database schema migration runner for Phase 3: Admin Itinerary Moderation.
 *
 * Ensures {@code idx_itineraries_admin_query} index on {@code itineraries(status, visibility, created_at DESC)}
 * exists under a connection-scoped MySQL advisory lock prior to JPA EntityManagerFactory validation.
 *
 * Rollback SQL:
 * DROP INDEX idx_itineraries_admin_query ON itineraries;
 */
@Component("adminItineraryMigrationRunner")
@Order(9)
public class AdminItineraryMigrationRunner implements InitializingBean, ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(AdminItineraryMigrationRunner.class);
    public static final String MIGRATION_LOCK = "admin_itinerary_migration_lock";
    private static final String INDEX_NAME = "idx_itineraries_admin_query";

    private final DataSource dataSource;

    @Autowired
    public AdminItineraryMigrationRunner(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    public AdminItineraryMigrationRunner(JdbcTemplate jdbcTemplate) {
        this.dataSource = jdbcTemplate != null ? jdbcTemplate.getDataSource() : null;
    }

    @Override
    public void afterPropertiesSet() {
        ensureSchemaAndMigration();
    }

    @Override
    public void run(ApplicationArguments args) {
        ensureSchemaAndMigration();
    }

    public void ensureSchemaAndMigration() {
        if (dataSource == null) {
            return;
        }

        try (Connection conn = dataSource.getConnection()) {
            boolean lockAcquired = acquireLock(conn);

            if (!lockAcquired) {
                if (isIndexPresent(conn)) {
                    log.info("--- [AdminItineraryMigration] Migration lock held by another instance, and index is already present. ---");
                    return;
                }
                throw new IllegalStateException("CRITICAL: Failed to acquire migration lock '" + MIGRATION_LOCK
                        + "' and admin itinerary index is missing! Halting startup.");
            }

            try (Statement stmt = conn.createStatement()) {
                if (!tableExists(conn, "itineraries")) {
                    return;
                }
                if (!isIndexPresent(conn)) {
                    stmt.execute("CREATE INDEX " + INDEX_NAME + " ON itineraries (status, visibility, created_at DESC)");
                    log.info("--- [AdminItineraryMigration] Created index {} on itineraries ---", INDEX_NAME);
                }
            } finally {
                releaseLock(conn);
            }
        } catch (IllegalStateException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new IllegalStateException("CRITICAL: Failed to initialize Phase 3 admin itinerary index: " + ex.getMessage(), ex);
        }
    }

    private boolean isIndexPresent(Connection conn) throws Exception {
        if (!tableExists(conn, "itineraries")) {
            return true;
        }
        Set<String> indexes = new HashSet<>();
        DatabaseMetaData meta = conn.getMetaData();
        String catalog = conn.getCatalog();
        try (ResultSet rs = meta.getIndexInfo(catalog, null, "itineraries", false, false)) {
            while (rs.next()) {
                String idx = rs.getString("INDEX_NAME");
                if (idx != null) {
                    indexes.add(idx.toLowerCase());
                }
            }
        }
        return indexes.contains(INDEX_NAME);
    }

    private boolean tableExists(Connection conn, String tableName) throws Exception {
        DatabaseMetaData meta = conn.getMetaData();
        String catalog = conn.getCatalog();
        try (ResultSet rs = meta.getTables(catalog, null, tableName, new String[]{"TABLE"})) {
            if (rs.next()) {
                return true;
            }
        }
        try (ResultSet rs = meta.getTables(catalog, null, tableName.toUpperCase(), new String[]{"TABLE"})) {
            return rs.next();
        }
    }

    private boolean acquireLock(Connection conn) throws Exception {
        try (PreparedStatement ps = conn.prepareStatement("SELECT GET_LOCK(?, 15)")) {
            ps.setString(1, MIGRATION_LOCK);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() && rs.getInt(1) == 1;
            }
        }
    }

    private void releaseLock(Connection conn) {
        try (PreparedStatement ps = conn.prepareStatement("SELECT RELEASE_LOCK(?)")) {
            ps.setString(1, MIGRATION_LOCK);
            ps.execute();
        } catch (Exception ex) {
            log.warn("--- [AdminItineraryMigration] Failed to release advisory lock '{}': {} ---",
                    MIGRATION_LOCK, ex.getMessage());
        }
    }
}
