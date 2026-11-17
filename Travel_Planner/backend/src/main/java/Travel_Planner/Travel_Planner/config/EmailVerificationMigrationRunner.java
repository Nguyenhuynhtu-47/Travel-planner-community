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
@Order(2)
public class EmailVerificationMigrationRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(EmailVerificationMigrationRunner.class);
    private static final String MIGRATION_LOCK = "email_verification_migration_lock";

    private final JdbcTemplate jdbcTemplate;

    @Autowired
    public EmailVerificationMigrationRunner(JdbcTemplate jdbcTemplate) {
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
                    log.info("--- [EmailVerificationMigration] Migration lock held by another instance, but schema is already complete. Proceeding safely. ---");
                    return;
                } else {
                    throw new IllegalStateException("CRITICAL: Failed to acquire migration lock '" + MIGRATION_LOCK + "' and email verification schema is incomplete! Halting startup to prevent serving traffic with corrupted schema.");
                }
            }

            try {
                // Re-check schema metadata on this locked connection (double-checked locking)
                DatabaseMetaData meta = conn.getMetaData();
                String catalog = conn.getCatalog();

                try (Statement stmt = conn.createStatement()) {
                    // 1. Check & Add 'email_verified' column to users
                    boolean emailVerifiedExists = columnExists(meta, catalog, "users", "email_verified");
                    if (!emailVerifiedExists) {
                        log.info("--- [EmailVerificationMigration] Adding 'email_verified' column to 'users'... ---");
                        // Add column with DEFAULT TRUE so existing legacy rows atomically receive TRUE
                        stmt.execute("ALTER TABLE users ADD COLUMN email_verified BOOLEAN NOT NULL DEFAULT TRUE");
                        // Then set default for all future user registrations to FALSE
                        stmt.execute("ALTER TABLE users ALTER COLUMN email_verified SET DEFAULT FALSE");
                        log.info("--- [EmailVerificationMigration] Added 'email_verified': legacy users = TRUE, new registrations default = FALSE ---");
                    } else {
                        // If column already exists (e.g. from prior partial migration), safely update only legacy accounts
                        // that have no record in email_verification_tokens, preserving state of new unverified users
                        stmt.execute("""
                            UPDATE users u
                            LEFT JOIN email_verification_tokens evt ON u.user_id = evt.user_id
                            SET u.email_verified = TRUE
                            WHERE evt.token_id IS NULL AND u.email_verified = FALSE
                        """);
                        // Also ensure no legacy NULL values remain
                        stmt.execute("UPDATE users SET email_verified = TRUE WHERE email_verified IS NULL");
                    }

                    // 2. Check & Add 'token_version' column to users
                    boolean tokenVersionExists = columnExists(meta, catalog, "users", "token_version");
                    if (!tokenVersionExists) {
                        log.info("--- [EmailVerificationMigration] Adding 'token_version' column to 'users'... ---");
                        stmt.execute("ALTER TABLE users ADD COLUMN token_version INT NOT NULL DEFAULT 1");
                        stmt.execute("UPDATE users SET token_version = 1");
                    } else {
                        stmt.execute("UPDATE users SET token_version = 1 WHERE token_version IS NULL");
                    }

                    // 3. Check & Create 'email_verification_tokens' table
                    boolean tableExists = tableExists(meta, catalog, "email_verification_tokens");
                    if (!tableExists) {
                        log.info("--- [EmailVerificationMigration] Creating 'email_verification_tokens' table... ---");
                        stmt.execute("""
                            CREATE TABLE IF NOT EXISTS email_verification_tokens (
                                token_id BIGINT AUTO_INCREMENT PRIMARY KEY,
                                user_id INT NOT NULL,
                                token_hash VARCHAR(64) NOT NULL,
                                token_type VARCHAR(30) NOT NULL DEFAULT 'EMAIL_VERIFICATION',
                                attempts INT NOT NULL DEFAULT 0,
                                expires_at DATETIME NOT NULL,
                                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                CONSTRAINT fk_evt_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
                                INDEX idx_evt_token_hash (token_hash),
                                INDEX idx_evt_user_type (user_id, token_type)
                            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                        """);
                        log.info("--- [EmailVerificationMigration] Successfully created 'email_verification_tokens' table ---");
                    }
                }
            } finally {
                releaseLock(conn);
            }
        } catch (IllegalStateException e) {
            throw e;
        } catch (Exception e) {
            log.warn("--- [EmailVerificationMigration] Migration warning/note: {} ---", e.getMessage());
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
                        log.info("--- [EmailVerificationMigration] Advisory lock '{}' released successfully. ---", MIGRATION_LOCK);
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
            boolean emailVerified = columnExists(meta, catalog, "users", "email_verified");
            boolean tokenVersion = columnExists(meta, catalog, "users", "token_version");
            boolean tableExists = tableExists(meta, catalog, "email_verification_tokens");
            return emailVerified && tokenVersion && tableExists;
        } catch (Exception e) {
            return false;
        }
    }

    private boolean columnExists(DatabaseMetaData meta, String catalog, String tableName, String columnName) {
        try {
            try (ResultSet rs = meta.getColumns(catalog, null, tableName, columnName)) {
                if (rs.next()) return true;
            }
            try (ResultSet rs = meta.getColumns(catalog, null, tableName.toUpperCase(), columnName.toUpperCase())) {
                if (rs.next()) return true;
            }
            try (ResultSet rs = meta.getColumns(catalog, null, tableName.toLowerCase(), columnName.toLowerCase())) {
                if (rs.next()) return true;
            }
        } catch (Exception e) {
            log.debug("Error checking column {}.{}: {}", tableName, columnName, e.getMessage());
        }
        return false;
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
