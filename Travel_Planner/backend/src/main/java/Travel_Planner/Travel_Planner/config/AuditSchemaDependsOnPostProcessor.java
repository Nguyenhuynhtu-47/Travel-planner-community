package Travel_Planner.Travel_Planner.config;

import jakarta.persistence.EntityManagerFactory;
import org.springframework.beans.BeansException;
import org.springframework.beans.factory.config.BeanDefinition;
import org.springframework.beans.factory.config.BeanFactoryPostProcessor;
import org.springframework.beans.factory.config.ConfigurableListableBeanFactory;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.Set;

/**
 * Ensures JPA EntityManagerFactory (and therefore Hibernate ddl-auto=validate)
 * initializes strictly AFTER {@link AuditLogMigrationRunner} has created/verified
 * the {@code audit_logs} table.
 *
 * This mirrors Spring Boot's native EntityManagerFactoryDependsOnPostProcessor
 * pattern without introducing Flyway or Liquibase.
 */
@Component
public class AuditSchemaDependsOnPostProcessor implements BeanFactoryPostProcessor {

    private static final String AUDIT_MIGRATION_BEAN = "auditLogMigrationRunner";
    private static final String ADMIN_USER_MIGRATION_BEAN = "adminUserMigrationRunner";
    private static final String ADMIN_ITINERARY_MIGRATION_BEAN = "adminItineraryMigrationRunner";
    private static final String SYSTEM_SETTING_MIGRATION_BEAN = "systemSettingMigrationRunner";

    @Override
    public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
        Set<String> preJpaBeans = new LinkedHashSet<>();
        if (beanFactory.containsBeanDefinition(AUDIT_MIGRATION_BEAN)) {
            preJpaBeans.add(AUDIT_MIGRATION_BEAN);
        }
        if (beanFactory.containsBeanDefinition(ADMIN_USER_MIGRATION_BEAN)) {
            preJpaBeans.add(ADMIN_USER_MIGRATION_BEAN);
        }
        if (beanFactory.containsBeanDefinition(ADMIN_ITINERARY_MIGRATION_BEAN)) {
            preJpaBeans.add(ADMIN_ITINERARY_MIGRATION_BEAN);
        }
        if (beanFactory.containsBeanDefinition(SYSTEM_SETTING_MIGRATION_BEAN)) {
            preJpaBeans.add(SYSTEM_SETTING_MIGRATION_BEAN);
        }
        if (preJpaBeans.isEmpty()) {
            return;
        }

        Set<String> emfBeanNames = new LinkedHashSet<>();
        emfBeanNames.addAll(Arrays.asList(beanFactory.getBeanNamesForType(EntityManagerFactory.class, true, false)));
        if (beanFactory.containsBeanDefinition("entityManagerFactory")) {
            emfBeanNames.add("entityManagerFactory");
        }

        for (String emfBeanName : emfBeanNames) {
            if (!beanFactory.containsBeanDefinition(emfBeanName)) {
                continue;
            }
            BeanDefinition bd = beanFactory.getBeanDefinition(emfBeanName);
            String[] existingDependsOn = bd.getDependsOn();
            Set<String> updated = new LinkedHashSet<>(preJpaBeans);
            if (existingDependsOn != null) {
                updated.addAll(Arrays.asList(existingDependsOn));
            }
            bd.setDependsOn(updated.toArray(new String[0]));
        }
    }
}
