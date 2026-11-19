package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.PasswordResetMigrationRunner;
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
public class PasswordResetMigrationRunnerTest {

    @Autowired
    private DataSource dataSource;

    @Autowired
    private PasswordResetMigrationRunner runner;

    @Test
    @DisplayName("PasswordResetMigrationRunner: Schema verification should confirm password_reset_tokens table exists")
    void testSchemaCompleteness() throws Exception {
        try (Connection conn = dataSource.getConnection()) {
            boolean complete = runner.isSchemaComplete(conn);
            assertTrue(complete, "Schema must be verified complete (password_reset_tokens table exists)");
        }
    }

    @Test
    @DisplayName("PasswordResetMigrationRunner: Runner must be idempotent when invoked multiple times")
    void testIdempotency() {
        assertDoesNotThrow(() -> {
            runner.run(new DefaultApplicationArguments(new String[0]));
            runner.run(new DefaultApplicationArguments(new String[0]));
        }, "Running migration runner multiple times must be completely idempotent");
    }

    @Test
    @DisplayName("PasswordResetMigrationRunner: MySQL Advisory Lock functions correctly on single connection and excludes concurrent connections")
    void testAdvisoryLockIsolation() throws Exception {
        try (Connection conn1 = dataSource.getConnection();
             Connection conn2 = dataSource.getConnection()) {

            // Acquire lock on conn1
            try (PreparedStatement ps1 = conn1.prepareStatement("SELECT GET_LOCK('test_pwd_reset_lock', 2)")) {
                try (ResultSet rs1 = ps1.executeQuery()) {
                    assertTrue(rs1.next());
                    assertEquals(1, rs1.getInt(1), "conn1 must acquire lock");
                }
            }

            // conn2 attempts to acquire same lock with 0 timeout -> must fail (return 0)
            try (PreparedStatement ps2 = conn2.prepareStatement("SELECT GET_LOCK('test_pwd_reset_lock', 0)")) {
                try (ResultSet rs2 = ps2.executeQuery()) {
                    assertTrue(rs2.next());
                    assertEquals(0, rs2.getInt(1), "conn2 must be excluded while conn1 holds the lock");
                }
            }

            // Release lock on conn1
            try (PreparedStatement psRel = conn1.prepareStatement("SELECT RELEASE_LOCK('test_pwd_reset_lock')")) {
                try (ResultSet rsRel = psRel.executeQuery()) {
                    assertTrue(rsRel.next());
                    assertEquals(1, rsRel.getInt(1), "conn1 must successfully release lock");
                }
            }

            // conn2 now can acquire the lock
            try (PreparedStatement ps2 = conn2.prepareStatement("SELECT GET_LOCK('test_pwd_reset_lock', 2)")) {
                try (ResultSet rs2 = ps2.executeQuery()) {
                    assertTrue(rs2.next());
                    assertEquals(1, rs2.getInt(1), "conn2 should now acquire lock after conn1 released it");
                }
            }

            // Clean up conn2 lock
            try (PreparedStatement psRel2 = conn2.prepareStatement("SELECT RELEASE_LOCK('test_pwd_reset_lock')")) {
                psRel2.execute();
            }
        }
    }
}
