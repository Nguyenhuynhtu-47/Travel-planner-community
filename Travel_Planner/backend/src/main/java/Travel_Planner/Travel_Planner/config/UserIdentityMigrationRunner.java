package Travel_Planner.Travel_Planner.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;

@Component
@Order(4)
public class UserIdentityMigrationRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(UserIdentityMigrationRunner.class);
    private static final String MIGRATION_LOCK = "user_identity_migration_lock";

    private final JdbcTemplate jdbcTemplate;

    @Autowired
    public UserIdentityMigrationRunner(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void run(ApplicationArguments args) {
        ensureSchemaAndMigration();
    }

    public void ensureSchemaAndMigration() {
        if (jdbcTemplate == null || jdbcTemplate.getDataSource() == null) {
            return;
        }

        try (Connection conn = jdbcTemplate.getDataSource().getConnection()) {
            boolean lockAcquired = acquireLock(conn);

            if (!lockAcquired) {
                if (isSchemaComplete(conn)) {
                    log.info("--- [UserIdentityMigration] Migration lock held by another instance, but schema is already complete. Proceeding safely. ---");
                    return;
                } else {
                    throw new IllegalStateException("CRITICAL: Failed to acquire migration lock '" + MIGRATION_LOCK + "' and user identities schema is incomplete! Halting startup.");
                }
            }

            try {
                DatabaseMetaData meta = conn.getMetaData();
                String catalog = conn.getCatalog();

                try (Statement stmt = conn.createStatement()) {
                    boolean tableExists = tableExists(meta, catalog, "user_identities");
                    if (!tableExists) {
                        log.info("--- [UserIdentityMigration] Creating 'user_identities' table... ---");
                        stmt.execute("""
                            CREATE TABLE IF NOT EXISTS user_identities (
                                identity_id INT AUTO_INCREMENT PRIMARY KEY,
                                user_id INT NOT NULL,
                                provider VARCHAR(50) NOT NULL,
                                provider_subject VARCHAR(255) NOT NULL,
                                email VARCHAR(100) NULL,
                                created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
                                updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
                                CONSTRAINT fk_ui_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
                                CONSTRAINT uk_user_identities_provider_subject UNIQUE (provider, provider_subject),
                                INDEX idx_user_identities_user_id (user_id)
                            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                        """);
                        log.info("--- [UserIdentityMigration] Successfully created 'user_identities' table ---");
                    }
                }
            } finally {
                releaseLock(conn);
            }
        } catch (IllegalStateException e) {
            throw e;
        } catch (Exception e) {
            log.warn("--- [UserIdentityMigration] Migration note: {} ---", e.getMessage());
        }
    }

    private boolean acquireLock(Connection conn) {
        String sql = "SELECT GET_LOCK(?, 15)";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, MIGRATION_LOCK);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    int result = rs.getInt(1);
                    return !rs.wasNull() && result == 1;
                }
            }
        } catch (Exception e) {
            log.warn("--- [UserIdentityMigration] Could not query GET_LOCK: {} ---", e.getMessage());
        }
        return false;
    }

    private void releaseLock(Connection conn) {
        String sql = "SELECT RELEASE_LOCK(?)";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, MIGRATION_LOCK);
            ps.executeQuery();
        } catch (Exception e) {
            log.warn("--- [UserIdentityMigration] Could not release migration lock: {} ---", e.getMessage());
        }
    }

    private boolean isSchemaComplete(Connection conn) {
        try {
            DatabaseMetaData meta = conn.getMetaData();
            return tableExists(meta, conn.getCatalog(), "user_identities");
        } catch (Exception e) {
            return false;
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
