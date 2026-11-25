package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.AuditLogMigrationRunner;
import Travel_Planner.Travel_Planner.model.AuditLog;
import Travel_Planner.Travel_Planner.model.enums.AuditActionType;
import Travel_Planner.Travel_Planner.model.enums.AuditResultStatus;
import Travel_Planner.Travel_Planner.model.enums.AuditTargetType;
import Travel_Planner.Travel_Planner.repository.AuditLogRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.config.BeanDefinition;
import org.springframework.beans.factory.config.ConfigurableListableBeanFactory;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.jdbc.core.JdbcTemplate;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.ResultSet;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Verifies Production startup behavior with Hibernate {@code spring.jpa.hibernate.ddl-auto=validate}.
 */
@SpringBootTest
class AuditLogProductionValidationTest {

    @Autowired
    private DataSource dataSource;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private ConfigurableListableBeanFactory beanFactory;

    @Test
    @DisplayName("EntityManagerFactory explicitly depends on auditLogMigrationRunner before Hibernate schema validation")
    void entityManagerFactory_dependsOnAuditLogMigrationRunner() {
        BeanDefinition emfDefinition = beanFactory.getBeanDefinition("entityManagerFactory");
        String[] dependsOn = emfDefinition.getDependsOn();
        assertNotNull(dependsOn, "entityManagerFactory must declare dependsOn");
        assertTrue(Arrays.asList(dependsOn).contains("auditLogMigrationRunner"),
                "entityManagerFactory must depend on auditLogMigrationRunner so audit_logs exists before ddl-auto=validate");
    }

    @Test
    @DisplayName("Production ddl-auto=validate succeeds when audit_logs is missing before boot and remains idempotent when table already exists")
    void productionDdlValidate_createsMissingTableBeforeHibernateValidate_andIsIdempotentWhenExisting() throws Exception {
        // 1. Simulate clean production state where audit_logs table does NOT exist yet
        jdbcTemplate.execute("DROP TABLE IF EXISTS audit_logs");
        try (Connection conn = dataSource.getConnection()) {
            assertFalse(tableExists(conn, "audit_logs"),
                    "Precondition: audit_logs must not exist before Production boot");
        }

        // 2. Boot a dedicated context with Hibernate ddl-auto=validate (Production mode)
        try (ConfigurableApplicationContext prodCtx = new SpringApplicationBuilder(TravelPlannerApplication.class)
                .web(WebApplicationType.NONE)
                .properties(
                        "spring.jpa.hibernate.ddl-auto=validate",
                        "spring.jpa.show-sql=false",
                        "app.seed.enabled=false",
                        "app.administrative-areas.import.enabled=false",
                        "app.place-administrative-areas.linking.enabled=false",
                        "jwt.secret=404E635266556A586E3272357538782F413F4428472B4B6250645367566B5970"
                )
                .run()) {

            AuditLogMigrationRunner runner = prodCtx.getBean(AuditLogMigrationRunner.class);
            try (Connection conn = prodCtx.getBean(DataSource.class).getConnection()) {
                assertTrue(runner.isSchemaComplete(conn),
                        "audit_logs table and indexes must be created before Hibernate validate finishes");
            }

            // Verify AuditLogRepository works cleanly under ddl-auto=validate
            AuditLogRepository repo = prodCtx.getBean(AuditLogRepository.class);
            AuditLog persisted = repo.saveAndFlush(AuditLog.builder()
                    .actorId(1)
                    .actorUsername("prod_verifier")
                    .actionType(AuditActionType.SETTING_UPDATE)
                    .targetType(AuditTargetType.SYSTEM_SETTING)
                    .targetId("PROD_CHECK")
                    .resultStatus(AuditResultStatus.SUCCESS)
                    .correlationId("prod-validate-corr-1")
                    .createdAt(LocalDateTime.now())
                    .build());
            assertNotNull(persisted.getLogId());
        }

        // 3. Re-boot a second Production ddl-auto=validate context when audit_logs ALREADY exists with data (idempotency check)
        try (ConfigurableApplicationContext secondProdCtx = new SpringApplicationBuilder(TravelPlannerApplication.class)
                .web(WebApplicationType.NONE)
                .properties(
                        "spring.jpa.hibernate.ddl-auto=validate",
                        "spring.jpa.show-sql=false",
                        "app.seed.enabled=false",
                        "app.administrative-areas.import.enabled=false",
                        "app.place-administrative-areas.linking.enabled=false",
                        "jwt.secret=404E635266556A586E3272357538782F413F4428472B4B6250645367566B5970"
                )
                .run()) {

            AuditLogRepository repo = secondProdCtx.getBean(AuditLogRepository.class);
            List<AuditLog> existingRows = repo.findAll();
            assertEquals(1, existingRows.size(),
                    "Idempotent migration must preserve pre-existing audit_logs rows across restarts");
            assertEquals("PROD_CHECK", existingRows.get(0).getTargetId());
        } finally {
            jdbcTemplate.execute("DELETE FROM audit_logs");
        }
    }

    private boolean tableExists(Connection conn, String tableName) throws Exception {
        DatabaseMetaData meta = conn.getMetaData();
        try (ResultSet rs = meta.getTables(conn.getCatalog(), null, tableName, new String[]{"TABLE"})) {
            return rs.next();
        }
    }
}
