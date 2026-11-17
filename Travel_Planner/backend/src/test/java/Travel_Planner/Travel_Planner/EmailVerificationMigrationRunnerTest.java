package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.EmailVerificationMigrationRunner;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.DefaultApplicationArguments;
import org.springframework.boot.test.context.SpringBootTest;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
public class EmailVerificationMigrationRunnerTest {

    @Autowired
    private DataSource dataSource;

    @Autowired
    private EmailVerificationMigrationRunner runner;

    @Test
    @DisplayName("EmailVerificationMigrationRunner: Schema verification should confirm all columns and tables exist")
    void testSchemaCompleteness() throws Exception {
        try (Connection conn = dataSource.getConnection()) {
            boolean complete = runner.isSchemaComplete(conn);
            assertTrue(complete, "Schema must be verified complete (email_verified, token_version, email_verification_tokens)");
        }
    }

    @Test
    @DisplayName("EmailVerificationMigrationRunner: Runner must be idempotent when invoked multiple times")
    void testIdempotency() {
        assertDoesNotThrow(() -> {
            runner.run(new DefaultApplicationArguments(new String[0]));
            runner.run(new DefaultApplicationArguments(new String[0]));
        }, "Running migration runner multiple times must be completely idempotent");
    }

    @Test
    @DisplayName("EmailVerificationMigrationRunner: MySQL Advisory Lock functions correctly on single connection and excludes concurrent connections")
    void testAdvisoryLockIsolation() throws Exception {
        try (Connection conn1 = dataSource.getConnection();
             Connection conn2 = dataSource.getConnection()) {

            // Acquire lock on conn1
            try (PreparedStatement ps1 = conn1.prepareStatement("SELECT GET_LOCK('test_email_verif_lock', 2)")) {
                try (ResultSet rs1 = ps1.executeQuery()) {
                    assertTrue(rs1.next());
                    assertEquals(1, rs1.getInt(1), "conn1 must acquire lock");
                }
            }

            // conn2 attempts to acquire same lock with 0 timeout -> must fail (return 0)
            try (PreparedStatement ps2 = conn2.prepareStatement("SELECT GET_LOCK('test_email_verif_lock', 0)")) {
                try (ResultSet rs2 = ps2.executeQuery()) {
                    assertTrue(rs2.next());
                    assertEquals(0, rs2.getInt(1), "conn2 must be excluded while conn1 holds the lock");
                }
            }

            // Release lock on conn1
            try (PreparedStatement psRel = conn1.prepareStatement("SELECT RELEASE_LOCK('test_email_verif_lock')")) {
                try (ResultSet rsRel = psRel.executeQuery()) {
                    assertTrue(rsRel.next());
                    assertEquals(1, rsRel.getInt(1), "conn1 must successfully release lock");
                }
            }

            // conn2 now can acquire the lock
            try (PreparedStatement ps2 = conn2.prepareStatement("SELECT GET_LOCK('test_email_verif_lock', 2)")) {
                try (ResultSet rs2 = ps2.executeQuery()) {
                    assertTrue(rs2.next());
                    assertEquals(1, rs2.getInt(1), "conn2 should now acquire lock after conn1 released it");
                }
            }

            // Clean up conn2 lock
            try (PreparedStatement psRel2 = conn2.prepareStatement("SELECT RELEASE_LOCK('test_email_verif_lock')")) {
                psRel2.execute();
            }
        }
    }
}
