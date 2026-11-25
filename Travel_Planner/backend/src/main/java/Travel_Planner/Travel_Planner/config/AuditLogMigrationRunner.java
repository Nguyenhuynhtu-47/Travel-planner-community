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
 * Idempotent database schema migration runner for Phase 1: Audit Trail Core.
 *
 * Implements {@link InitializingBean} alongside {@link AuditSchemaDependsOnPostProcessor}
 * so the 'audit_logs' table and its required compound query indexes are created under a
 * connection-scoped MySQL advisory lock ('audit_log_migration_lock') BEFORE JPA's
 * EntityManagerFactory performs Hibernate {@code ddl-auto=validate} in production.
 *
 * Also implements {@link ApplicationRunner} for explicit idempotent verification at startup
 * and test execution.
 *
 * Rollback SQL:
 * DROP TABLE IF EXISTS audit_logs;
 */
@Component("auditLogMigrationRunner")
@Order(7)
public class AuditLogMigrationRunner implements InitializingBean, ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(AuditLogMigrationRunner.class);
    public static final String MIGRATION_LOCK = "audit_log_migration_lock";

    private final DataSource dataSource;

    @Autowired
    public AuditLogMigrationRunner(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    public AuditLogMigrationRunner(JdbcTemplate jdbcTemplate) {
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
                    log.info("--- [AuditLogMigration] Migration lock held by another instance, and 'audit_logs' schema is complete. Proceeding safely. ---");
                    return;
                }
                throw new IllegalStateException("CRITICAL: Failed to acquire migration lock '" + MIGRATION_LOCK
                        + "' and 'audit_logs' schema is incomplete! Halting startup.");
            }

            try {
                DatabaseMetaData meta = conn.getMetaData();
                String catalog = conn.getCatalog();

                try (Statement stmt = conn.createStatement()) {
                    if (!tableExists(meta, catalog, "audit_logs")) {
                        log.info("--- [AuditLogMigration] Creating 'audit_logs' table... ---");
                        stmt.execute("""
                            CREATE TABLE IF NOT EXISTS audit_logs (
                                log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
                                actor_id INT NOT NULL,
                                actor_username VARCHAR(50) NOT NULL,
                                action_type VARCHAR(50) NOT NULL,
                                target_type VARCHAR(50) NOT NULL,
                                target_id VARCHAR(100) NOT NULL,
                                reason VARCHAR(255) NULL,
                                result_status VARCHAR(30) NOT NULL DEFAULT 'SUCCESS',
                                before_data_json TEXT NULL,
                                after_data_json TEXT NULL,
                                ip_address VARCHAR(45) NULL,
                                user_agent VARCHAR(255) NULL,
                                correlation_id VARCHAR(64) NULL,
                                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                INDEX idx_audit_actor_created (actor_id, created_at DESC),
                                INDEX idx_audit_action_created (action_type, created_at DESC),
                                INDEX idx_audit_target_created (target_type, target_id, created_at DESC),
                                INDEX idx_audit_created_at (created_at DESC),
                                INDEX idx_audit_correlation_id (correlation_id)
                            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                        """);
                        log.info("--- [AuditLogMigration] Successfully created 'audit_logs' table ---");
                    } else {
                        ensureMissingColumnsAndIndexes(conn, meta, catalog, stmt);
                    }
                }
            } finally {
                releaseLock(conn);
            }
        } catch (IllegalStateException e) {
            throw e;
        } catch (Exception e) {
            throw new IllegalStateException("CRITICAL: Failed to initialize 'audit_logs' schema during startup.", e);
        }
    }

    private void ensureMissingColumnsAndIndexes(Connection conn, DatabaseMetaData meta, String catalog, Statement stmt) throws Exception {
        if (!columnExists(meta, catalog, "audit_logs", "correlation_id")) {
            stmt.execute("ALTER TABLE audit_logs ADD COLUMN correlation_id VARCHAR(64) NULL AFTER user_agent");
        }
        Set<String> existingIndexes = getExistingIndexNames(meta, catalog, "audit_logs");
        if (!existingIndexes.contains("idx_audit_actor_created")) {
            stmt.execute("CREATE INDEX idx_audit_actor_created ON audit_logs (actor_id, created_at DESC)");
        }
        if (!existingIndexes.contains("idx_audit_action_created")) {
            stmt.execute("CREATE INDEX idx_audit_action_created ON audit_logs (action_type, created_at DESC)");
        }
        if (!existingIndexes.contains("idx_audit_target_created")) {
            stmt.execute("CREATE INDEX idx_audit_target_created ON audit_logs (target_type, target_id, created_at DESC)");
        }
        if (!existingIndexes.contains("idx_audit_created_at")) {
            stmt.execute("CREATE INDEX idx_audit_created_at ON audit_logs (created_at DESC)");
        }
        if (!existingIndexes.contains("idx_audit_correlation_id")) {
            stmt.execute("CREATE INDEX idx_audit_correlation_id ON audit_logs (correlation_id)");
        }
    }

    public boolean isSchemaComplete(Connection conn) {
        try {
            DatabaseMetaData meta = conn.getMetaData();
            String catalog = conn.getCatalog();
            if (!tableExists(meta, catalog, "audit_logs")) {
                return false;
            }
            Set<String> indexes = getExistingIndexNames(meta, catalog, "audit_logs");
            return indexes.contains("idx_audit_actor_created")
                    && indexes.contains("idx_audit_action_created")
                    && indexes.contains("idx_audit_target_created")
                    && indexes.contains("idx_audit_created_at")
                    && indexes.contains("idx_audit_correlation_id")
                    && columnExists(meta, catalog, "audit_logs", "correlation_id");
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

    private boolean columnExists(DatabaseMetaData meta, String catalog, String tableName, String columnName) {
        try {
            for (String tbl : new String[]{tableName, tableName.toUpperCase(), tableName.toLowerCase()}) {
                for (String col : new String[]{columnName, columnName.toUpperCase(), columnName.toLowerCase()}) {
                    try (ResultSet rs = meta.getColumns(catalog, null, tbl, col)) {
                        if (rs.next()) {
                            return true;
                        }
                    }
                }
            }
        } catch (Exception e) {
            log.debug("Error checking column {}.{}: {}", tableName, columnName, e.getMessage());
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
