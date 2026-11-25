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
 * Idempotent database schema migration runner for Phase 2: Admin User Management.
 *
 * Ensures the standalone {@code admin_role_guard} mutex table, its {@code ADMIN_ROLE_MUTEX}
 * seed row, and {@code idx_users_admin_filter} index on {@code users} exist under a
 * connection-scoped MySQL advisory lock BEFORE JPA EntityManagerFactory runs ddl-auto=validate.
 *
 * Rollback SQL:
 * DROP TABLE IF EXISTS admin_role_guard;
 * DROP INDEX idx_users_admin_filter ON users;
 */
@Component("adminUserMigrationRunner")
@Order(8)
public class AdminUserMigrationRunner implements InitializingBean, ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(AdminUserMigrationRunner.class);
    public static final String MIGRATION_LOCK = "admin_user_migration_lock";

    private final DataSource dataSource;

    @Autowired
    public AdminUserMigrationRunner(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    public AdminUserMigrationRunner(JdbcTemplate jdbcTemplate) {
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
                if (isSchemaComplete(conn)) {
                    log.info("--- [AdminUserMigration] Migration lock held by another instance, and schema is complete. Proceeding safely. ---");
                    return;
                }
                throw new IllegalStateException("CRITICAL: Failed to acquire migration lock '" + MIGRATION_LOCK
                        + "' and admin user schema is incomplete! Halting startup.");
            }

            try {
                DatabaseMetaData meta = conn.getMetaData();
                String catalog = conn.getCatalog();

                try (Statement stmt = conn.createStatement()) {
                    if (!tableExists(meta, catalog, "admin_role_guard")) {
                        log.info("--- [AdminUserMigration] Creating 'admin_role_guard' table... ---");
                        stmt.execute("""
                            CREATE TABLE IF NOT EXISTS admin_role_guard (
                                guard_id INT PRIMARY KEY,
                                guard_name VARCHAR(50) NOT NULL UNIQUE,
                                locked_at DATETIME NULL,
                                locked_by VARCHAR(50) NULL
                            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                        """);
                        log.info("--- [AdminUserMigration] Successfully created 'admin_role_guard' table ---");
                    }

                    // Idempotent mutex seed row
                    stmt.execute("""
                        INSERT INTO admin_role_guard (guard_id, guard_name)
                        VALUES (1, 'ADMIN_ROLE_MUTEX')
                        ON DUPLICATE KEY UPDATE guard_name = guard_name
                    """);

                    // Ensure admin filter index on users if users table already exists
                    if (tableExists(meta, catalog, "users")) {
                        Set<String> userIndexes = getExistingIndexNames(meta, catalog, "users");
                        if (!userIndexes.contains("idx_users_admin_filter")) {
                            log.info("--- [AdminUserMigration] Creating 'idx_users_admin_filter' on 'users'... ---");
                            stmt.execute("CREATE INDEX idx_users_admin_filter ON users (role, status, created_at DESC)");
                        }
                    }
                }
            } finally {
                releaseLock(conn);
            }
        } catch (IllegalStateException e) {
            throw e;
        } catch (Exception e) {
            throw new IllegalStateException("CRITICAL: Failed to initialize Phase 2 admin user schema.", e);
        }
    }

    public boolean isSchemaComplete(Connection conn) {
        try {
            DatabaseMetaData meta = conn.getMetaData();
            String catalog = conn.getCatalog();
            if (!tableExists(meta, catalog, "admin_role_guard")) {
                return false;
            }
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT COUNT(*) FROM admin_role_guard WHERE guard_name = 'ADMIN_ROLE_MUTEX'");
                 ResultSet rs = ps.executeQuery()) {
                if (!rs.next() || rs.getInt(1) < 1) {
                    return false;
                }
            }
            if (tableExists(meta, catalog, "users")) {
                Set<String> userIndexes = getExistingIndexNames(meta, catalog, "users");
                return userIndexes.contains("idx_users_admin_filter");
            }
            return true;
        } catch (Exception e) {
            return false;
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
            ps.executeQuery();
        } catch (Exception e) {
            log.debug("RELEASE_LOCK failed: {}", e.getMessage());
        }
    }

    private boolean tableExists(DatabaseMetaData meta, String catalog, String tableName) {
        try {
            for (String candidate : new String[]{tableName, tableName.toUpperCase(), tableName.toLowerCase()}) {
                try (ResultSet rs = meta.getTables(catalog, null, candidate, new String[]{"TABLE"})) {
                    if (rs.next()) {
                        return true;
                    }
                }
            }
        } catch (Exception e) {
            log.debug("Error checking table {}: {}", tableName, e.getMessage());
        }
        return false;
    }

    private Set<String> getExistingIndexNames(DatabaseMetaData meta, String catalog, String tableName) {
        Set<String> names = new HashSet<>();
        try {
            for (String candidate : new String[]{tableName, tableName.toUpperCase(), tableName.toLowerCase()}) {
                try (ResultSet rs = meta.getIndexInfo(catalog, null, candidate, false, false)) {
                    while (rs.next()) {
                        String idxName = rs.getString("INDEX_NAME");
                        if (idxName != null) {
                            names.add(idxName.toLowerCase());
                        }
                    }
                }
                if (!names.isEmpty()) {
                    break;
                }
            }
        } catch (Exception e) {
            log.debug("Error checking indexes for {}: {}", tableName, e.getMessage());
        }
        return names;
    }
}
