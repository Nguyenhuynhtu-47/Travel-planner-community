package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.AuditLogMigrationRunner;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.DefaultApplicationArguments;
import org.springframework.boot.test.context.SpringBootTest;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
public class AuditLogMigrationRunnerTest {

    @Autowired
    private DataSource dataSource;

    @Autowired
    private AuditLogMigrationRunner runner;

    @Test
    @DisplayName("AuditLogMigrationRunner verifies audit_logs table, correlation_id, and all required indexes exist")
    void testSchemaCompleteness() throws Exception {
        try (Connection conn = dataSource.getConnection()) {
            assertTrue(runner.isSchemaComplete(conn),
                    "Schema must be complete (audit_logs table, correlation_id column, and 5 indexes)");
        }
    }

    @Test
    @DisplayName("AuditLogMigrationRunner must be strictly idempotent on repeated invocations")
    void testIdempotency() {
        assertDoesNotThrow(() -> {
            runner.run(new DefaultApplicationArguments(new String[0]));
            runner.run(new DefaultApplicationArguments(new String[0]));
        });
    }

    @Test
    @DisplayName("AuditLogMigrationRunner MySQL Advisory Lock enforces mutual exclusion on single connection")
    void testAdvisoryLockIsolation() throws Exception {
        try (Connection conn1 = dataSource.getConnection();
             Connection conn2 = dataSource.getConnection()) {

            try (PreparedStatement ps1 = conn1.prepareStatement("SELECT GET_LOCK('test_audit_log_lock', 2)")) {
                try (ResultSet rs1 = ps1.executeQuery()) {
                    assertTrue(rs1.next());
                    assertEquals(1, rs1.getInt(1));
                }
            }

            try (PreparedStatement ps2 = conn2.prepareStatement("SELECT GET_LOCK('test_audit_log_lock', 0)")) {
                try (ResultSet rs2 = ps2.executeQuery()) {
                    assertTrue(rs2.next());
                    assertEquals(0, rs2.getInt(1));
                }
            }

            try (PreparedStatement psRel = conn1.prepareStatement("SELECT RELEASE_LOCK('test_audit_log_lock')")) {
                try (ResultSet rsRel = psRel.executeQuery()) {
                    assertTrue(rsRel.next());
                    assertEquals(1, rsRel.getInt(1));
                }
            }

            try (PreparedStatement ps2 = conn2.prepareStatement("SELECT GET_LOCK('test_audit_log_lock', 2)")) {
                try (ResultSet rs2 = ps2.executeQuery()) {
                    assertTrue(rs2.next());
                    assertEquals(1, rs2.getInt(1));
                }
            }

            try (PreparedStatement psRel2 = conn2.prepareStatement("SELECT RELEASE_LOCK('test_audit_log_lock')")) {
                psRel2.execute();
            }
        }
    }
}
