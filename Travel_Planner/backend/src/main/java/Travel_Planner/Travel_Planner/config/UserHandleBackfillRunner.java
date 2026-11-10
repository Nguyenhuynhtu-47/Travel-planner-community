package Travel_Planner.Travel_Planner.config;

import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.UserHandleService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.ResultSet;
import java.util.List;

@Component
@Order(1)
public class UserHandleBackfillRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(UserHandleBackfillRunner.class);

    private final UserRepository userRepository;
    private final UserHandleService userHandleService;
    private final JdbcTemplate jdbcTemplate;

    public UserHandleBackfillRunner(UserRepository userRepository,
                                    UserHandleService userHandleService) {
        this(userRepository, userHandleService, null);
    }

    @Autowired
    public UserHandleBackfillRunner(UserRepository userRepository,
                                    UserHandleService userHandleService,
                                    JdbcTemplate jdbcTemplate) {
        this.userRepository = userRepository;
        this.userHandleService = userHandleService;
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        ensureSchemaAndBackfill();
    }

    public void ensureSchemaAndBackfill() {
        try {
            ensureColumnExists();
            backfillUsers();
            ensureConstraints();
        } catch (Exception e) {
            log.warn("--- [UserHandleBackfill] Schema check/migration note: {} ---", e.getMessage());
        }
    }

    private void ensureColumnExists() {
        if (jdbcTemplate == null || jdbcTemplate.getDataSource() == null) return;
        try (Connection conn = jdbcTemplate.getDataSource().getConnection()) {
            DatabaseMetaData meta = conn.getMetaData();
            boolean exists = false;
            try (ResultSet rs = meta.getColumns(conn.getCatalog(), null, "users", "handle")) {
                if (rs.next()) exists = true;
            }
            if (!exists) {
                try (ResultSet rs = meta.getColumns(conn.getCatalog(), null, "USERS", "HANDLE")) {
                    if (rs.next()) exists = true;
                }
            }
            if (!exists) {
                log.info("--- [UserHandleBackfill] Column 'handle' does not exist in 'users'. Adding column... ---");
                jdbcTemplate.execute("ALTER TABLE users ADD COLUMN handle VARCHAR(30) NULL");
            }
        } catch (Exception e) {
            log.warn("--- [UserHandleBackfill] Could not check/add 'handle' column via metadata: {} ---", e.getMessage());
        }
    }

    private void backfillUsers() {
        List<User> usersNeedingHandle = userRepository.findUsersNeedingHandle();
        if (usersNeedingHandle.isEmpty()) {
            return;
        }

        log.info("--- [UserHandleBackfill] Found {} account(s) without public handle. Backfilling safe unique handles... ---", usersNeedingHandle.size());
        for (User user : usersNeedingHandle) {
            String generatedHandle = userHandleService.generateUniqueHandle(user.getFullName(), user.getUserId());
            user.setHandle(generatedHandle);
            userRepository.save(user);
            log.info("--- [UserHandleBackfill] Backfilled handle '@{}' for user ID {} (display name: '{}') ---",
                    generatedHandle, user.getUserId(), user.getFullName());
        }
        log.info("--- [UserHandleBackfill] Successfully backfilled {} handle(s). ---", usersNeedingHandle.size());
    }

    private void ensureConstraints() {
        if (jdbcTemplate == null) return;
        try {
            jdbcTemplate.execute("ALTER TABLE users MODIFY COLUMN handle VARCHAR(30) NOT NULL");
        } catch (Exception e) {
            log.debug("--- [UserHandleBackfill] Column already NOT NULL or cannot alter: {} ---", e.getMessage());
        }

        try {
            jdbcTemplate.execute("ALTER TABLE users ADD UNIQUE KEY uk_users_handle (handle)");
        } catch (Exception e) {
            log.debug("--- [UserHandleBackfill] Unique key uk_users_handle already exists or cannot add: {} ---", e.getMessage());
        }
    }
}
