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
@Order(5)
public class SessionAndEmailChangeMigrationRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(SessionAndEmailChangeMigrationRunner.class);
    private static final String MIGRATION_LOCK = "session_and_email_change_migration_lock";

    private final JdbcTemplate jdbcTemplate;

    @Autowired
    public SessionAndEmailChangeMigrationRunner(JdbcTemplate jdbcTemplate) {
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
                    log.info("--- [SessionMigration] Migration lock held by another instance, but schema is already complete. Proceeding safely. ---");
                    return;
                } else {
                    throw new IllegalStateException("CRITICAL: Failed to acquire migration lock '" + MIGRATION_LOCK + "' and session schema is incomplete! Halting startup.");
                }
            }

            try {
                DatabaseMetaData meta = conn.getMetaData();
                String catalog = conn.getCatalog();

                try (Statement stmt = conn.createStatement()) {
                    // 1. user_sessions table
                    boolean userSessionsExists = tableExists(meta, catalog, "user_sessions");
                    if (!userSessionsExists) {
                        log.info("--- [SessionMigration] Creating 'user_sessions' table... ---");
                        stmt.execute("""
                            CREATE TABLE IF NOT EXISTS user_sessions (
                                session_id VARCHAR(36) PRIMARY KEY,
                                user_id INT NOT NULL,
                                device_info VARCHAR(255) NULL,
                                ip_address VARCHAR(45) NULL,
                                status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
                                created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
                                last_active_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
                                expires_at DATETIME(6) NOT NULL,
                                CONSTRAINT fk_us_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
                                INDEX idx_us_user_id (user_id),
                                INDEX idx_us_status (status),
                                INDEX idx_us_expires_at (expires_at)
                            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                        """);
                        log.info("--- [SessionMigration] Successfully created 'user_sessions' table ---");
                    }

                    // 2. email_change_requests table
                    boolean emailChangeExists = tableExists(meta, catalog, "email_change_requests");
                    if (!emailChangeExists) {
                        log.info("--- [SessionMigration] Creating 'email_change_requests' table... ---");
                        stmt.execute("""
                            CREATE TABLE IF NOT EXISTS email_change_requests (
                                id BIGINT AUTO_INCREMENT PRIMARY KEY,
                                user_id INT NOT NULL,
                                old_email VARCHAR(100) NOT NULL,
                                new_email VARCHAR(100) NOT NULL,
                                otp_hash VARCHAR(64) NOT NULL,
                                attempts INT NOT NULL DEFAULT 0,
                                status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
                                expires_at DATETIME(6) NOT NULL,
                                created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
                                CONSTRAINT fk_ecr_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
                                INDEX idx_ecr_user_id (user_id),
                                INDEX idx_ecr_new_email (new_email),
                                INDEX idx_ecr_status (status)
                            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                        """);
                        log.info("--- [SessionMigration] Successfully created 'email_change_requests' table ---");
                    }
                }
            } finally {
                releaseLock(conn);
            }
        } catch (IllegalStateException e) {
            throw e;
        } catch (Exception e) {
            log.warn("--- [SessionMigration] Migration note: {} ---", e.getMessage());
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
            log.warn("--- [SessionMigration] Could not query GET_LOCK: {} ---", e.getMessage());
        }
        return false;
    }

    private void releaseLock(Connection conn) {
        String sql = "SELECT RELEASE_LOCK(?)";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, MIGRATION_LOCK);
            ps.executeQuery();
        } catch (Exception e) {
            log.warn("--- [SessionMigration] Could not release lock: {} ---", e.getMessage());
        }
    }

    private boolean isSchemaComplete(Connection conn) {
        try {
            DatabaseMetaData meta = conn.getMetaData();
            String catalog = conn.getCatalog();
            return tableExists(meta, catalog, "user_sessions") && tableExists(meta, catalog, "email_change_requests");
        } catch (Exception e) {
            return false;
        }
    }

    private boolean tableExists(DatabaseMetaData meta, String catalog, String tableName) {
        try (ResultSet rs = meta.getTables(catalog, null, tableName, new String[]{"TABLE"})) {
            if (rs.next()) {
                return true;
            }
        } catch (Exception ignored) {
        }
        try (ResultSet rs = meta.getTables(catalog, null, tableName.toUpperCase(), new String[]{"TABLE"})) {
            return rs.next();
        } catch (Exception ignored) {
        }
        return false;
    }
}
