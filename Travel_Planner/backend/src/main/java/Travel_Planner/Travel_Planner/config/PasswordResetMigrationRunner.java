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
@Order(3)
public class PasswordResetMigrationRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(PasswordResetMigrationRunner.class);
    private static final String MIGRATION_LOCK = "password_reset_migration_lock";

    private final JdbcTemplate jdbcTemplate;

    @Autowired
    public PasswordResetMigrationRunner(JdbcTemplate jdbcTemplate) {
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
                // If lock timed out or was not acquired, verify if another instance already completed schema migration
                if (isSchemaComplete(conn)) {
                    log.info("--- [PasswordResetMigration] Migration lock held by another instance, but schema is already complete. Proceeding safely. ---");
                    return;
                } else {
                    throw new IllegalStateException("CRITICAL: Failed to acquire migration lock '" + MIGRATION_LOCK + "' and password reset schema is incomplete! Halting startup to prevent serving traffic with corrupted schema.");
                }
            }

            try {
                // Re-check schema metadata on this locked connection (double-checked locking)
                DatabaseMetaData meta = conn.getMetaData();
                String catalog = conn.getCatalog();

                try (Statement stmt = conn.createStatement()) {
                    // Check & Create 'password_reset_tokens' table
                    boolean tableExists = tableExists(meta, catalog, "password_reset_tokens");
                    if (!tableExists) {
                        log.info("--- [PasswordResetMigration] Creating 'password_reset_tokens' table... ---");
                        stmt.execute("""
                            CREATE TABLE IF NOT EXISTS password_reset_tokens (
                                token_id BIGINT AUTO_INCREMENT PRIMARY KEY,
                                user_id INT NOT NULL,
                                token_hash VARCHAR(64) NOT NULL,
                                attempts INT NOT NULL DEFAULT 0,
                                expires_at DATETIME NOT NULL,
                                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                CONSTRAINT fk_prt_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
                                INDEX idx_prt_token_hash (token_hash),
                                INDEX idx_prt_user (user_id)
                            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                        """);
                        log.info("--- [PasswordResetMigration] Successfully created 'password_reset_tokens' table ---");
                    }
                }
            } finally {
                releaseLock(conn);
            }
        } catch (IllegalStateException e) {
            throw e;
        } catch (Exception e) {
            log.warn("--- [PasswordResetMigration] Migration warning/note: {} ---", e.getMessage());
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
            log.debug("GET_LOCK failed: {}", e.getMessage());
        }
        return false;
    }

    private void releaseLock(Connection conn) {
        String sql = "SELECT RELEASE_LOCK(?)";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, MIGRATION_LOCK);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    int result = rs.getInt(1);
                    if (!rs.wasNull() && result == 1) {
                        log.info("--- [PasswordResetMigration] Advisory lock '{}' released successfully. ---", MIGRATION_LOCK);
                    }
                }
            }
        } catch (Exception e) {
            log.debug("RELEASE_LOCK failed: {}", e.getMessage());
        }
    }

    public boolean isSchemaComplete(Connection conn) {
        try {
            DatabaseMetaData meta = conn.getMetaData();
            String catalog = conn.getCatalog();
            return tableExists(meta, catalog, "password_reset_tokens");
        } catch (Exception e) {
            return false;
        }
    }

    private boolean tableExists(DatabaseMetaData meta, String catalog, String tableName) {
        try {
            try (ResultSet rs = meta.getTables(catalog, null, tableName, new String[]{"TABLE"})) {
                if (rs.next()) return true;
            }
            try (ResultSet rs = meta.getTables(catalog, null, tableName.toUpperCase(), new String[]{"TABLE"})) {
                if (rs.next()) return true;
            }
            try (ResultSet rs = meta.getTables(catalog, null, tableName.toLowerCase(), new String[]{"TABLE"})) {
                if (rs.next()) return true;
            }
        } catch (Exception e) {
            log.debug("Error checking table {}: {}", tableName, e.getMessage());
        }
        return false;
    }
}
