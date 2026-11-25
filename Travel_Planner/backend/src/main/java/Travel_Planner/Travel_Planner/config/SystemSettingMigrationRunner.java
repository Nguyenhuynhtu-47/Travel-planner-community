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
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;

/**
 * Idempotent pre-JPA migration runner for Phase 6: System Settings.
 * Ensures {@code system_settings} table exists and default business settings are seeded
 * under a MySQL advisory lock prior to Hibernate {@code ddl-auto=validate}.
 */
@Component("systemSettingMigrationRunner")
@Order(10)
public class SystemSettingMigrationRunner implements InitializingBean, ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(SystemSettingMigrationRunner.class);
    public static final String MIGRATION_LOCK = "system_setting_migration_lock";

    private final DataSource dataSource;

    @Autowired
    public SystemSettingMigrationRunner(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    public SystemSettingMigrationRunner(JdbcTemplate jdbcTemplate) {
        this.dataSource = jdbcTemplate != null ? jdbcTemplate.getDataSource() : null;
    }

    @Override
    public void afterPropertiesSet() {
        ensureSchemaAndSeed();
    }

    @Override
    public void run(ApplicationArguments args) {
        ensureSchemaAndSeed();
    }

    public void ensureSchemaAndSeed() {
        if (dataSource == null) {
            return;
        }

        try (Connection conn = dataSource.getConnection()) {
            boolean lockAcquired = acquireLock(conn);
            if (!lockAcquired) {
                log.warn("--- [SystemSettingMigration] Could not acquire lock {}, continuing cautiously ---", MIGRATION_LOCK);
                return;
            }

            try (Statement stmt = conn.createStatement()) {
                stmt.execute("""
                        CREATE TABLE IF NOT EXISTS system_settings (
                            setting_key VARCHAR(100) PRIMARY KEY,
                            setting_value TEXT NOT NULL,
                            setting_group VARCHAR(50) NOT NULL,
                            description VARCHAR(255) NULL,
                            value_type VARCHAR(20) NOT NULL DEFAULT 'STRING',
                            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                            updated_by VARCHAR(50) NULL
                        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                        """);

                seedIfAbsent(conn, "MODERATION_AUTO_HIDE_THRESHOLD", "5", "MODERATION",
                        "Ngưỡng số báo cáo vi phạm để tự động ẩn bài viết (1 - 50)", "INT");
                seedIfAbsent(conn, "GEO_AUTO_RESOLVE_CONFIDENCE_THRESHOLD", "0.85", "GEO",
                        "Ngưỡng độ tin cậy tối thiểu để tự động liên kết khu vực hành chính (0.50 - 1.00)", "DOUBLE");
                seedIfAbsent(conn, "MEDIA_MAX_IMAGE_SIZE_MB", "2", "MEDIA",
                        "Dung lượng ảnh tối đa cho phép ở tầng nghiệp vụ (1 - 5 MB, không vượt quá giới hạn Servlet 5MB)", "INT");
                seedIfAbsent(conn, "SYSTEM_MAINTENANCE_MODE", "false", "MAINTENANCE",
                        "Bật/tắt chế độ bảo trì toàn hệ thống (Admin vẫn truy cập bình thường)", "BOOLEAN");
                seedIfAbsent(conn, "SYSTEM_MAINTENANCE_MESSAGE",
                        "Hệ thống đang bảo trì định kỳ. Vui lòng quay lại sau.", "MAINTENANCE",
                        "Thông điệp hiển thị cho người dùng khi hệ thống đang bảo trì", "STRING");
            } finally {
                releaseLock(conn);
            }
        } catch (Exception ex) {
            throw new IllegalStateException("Failed to initialize system_settings schema", ex);
        }
    }

    private void seedIfAbsent(
            Connection conn,
            String key,
            String value,
            String group,
            String description,
            String valueType) throws Exception {
        String sql = """
                INSERT IGNORE INTO system_settings
                (setting_key, setting_value, setting_group, description, value_type, updated_at, updated_by)
                VALUES (?, ?, ?, ?, ?, NOW(), 'SYSTEM')
                """;
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, key);
            ps.setString(2, value);
            ps.setString(3, group);
            ps.setString(4, description);
            ps.setString(5, valueType);
            ps.executeUpdate();
        }
    }

    private boolean acquireLock(Connection conn) {
        try (PreparedStatement ps = conn.prepareStatement("SELECT GET_LOCK(?, 10)")) {
            ps.setString(1, MIGRATION_LOCK);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() && rs.getInt(1) == 1;
            }
        } catch (Exception ex) {
            log.warn("--- [SystemSettingMigration] Lock check failed: {} ---", ex.getMessage());
            return false;
        }
    }

    private void releaseLock(Connection conn) {
        try (PreparedStatement ps = conn.prepareStatement("SELECT RELEASE_LOCK(?)")) {
            ps.setString(1, MIGRATION_LOCK);
            ps.executeQuery();
        } catch (Exception ignored) {
        }
    }
}
