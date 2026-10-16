
# Testing and Quality Guidelines

## 1. General
- Distinguish test guidance/commands from actual execution results. Never claim a test or build check passed unless it was physically executed and verified in the terminal.
- Verify that command line tools and wrappers (e.g., `mvnw.cmd`, `flutter`) actually exist and function before documenting verification.
- Test the affected modules based on the scope of change:
  - Backend changes: compile, unit tests, service logic, controller endpoints, validation.
  - Flutter changes: static analysis, widget tests, UI state rendering (loading/empty/error).
  - API changes: contract sync between backend DTOs and Flutter models.
- Report any checks that could not be executed due to missing environment tools or network restrictions.

## 2. Flutter
Execute verification commands within `Travel_Planner/frontend/mobile` or `Travel_Planner/frontend/web`:
- Static analysis command: `flutter analyze`
- Unit and widget test command: `flutter test`
- Formatting verification: `dart format --output=none --set-exit-if-changed .`
- Manual UI checklist:
  - Loading, empty, error, and success states.
  - Form validation messages and touch target sizes.
  - Responsive layout behavior across window resizing.
  - API integration and authentication token persistence.

## 3. Spring Boot
Execute verification commands from `Travel_Planner/backend/`:
- Compilation check: `.\mvnw.cmd test-compile` (Windows) or `./mvnw test-compile`
- Unit and integration tests: `.\mvnw.cmd test`
- Scope of test coverage:
  - Service layer business logic and validation rules.
  - Controller endpoints and HTTP status codes (`@WebMvcTest` or `@SpringBootTest`).
  - Request validation constraints (`@Valid`).
  - Authorization and resource ownership logic.
  - Custom exceptions and global `@RestControllerAdvice` error responses.
  - Multi-entity transactional rollbacks.

## 4. API Integration
Verify:
- Request fields match backend DTOs (`camelCase`).
- Response fields match frontend models.
- HTTP status codes are handled correctly (200, 201, 400, 401, 403, 404, 409, 500).
- Authentication requirements are respected.
- Errors are displayed appropriately.
- Both mobile and web remain compatible with the same endpoint contract.

## 5. Database Schema & Migration Safety
- **Hibernate DDL Auto Limitations**:
  - The backend uses `spring.jpa.hibernate.ddl-auto=update`.
  - Hibernate creates missing tables and adds missing columns automatically, but **NEVER drops or renames columns**.
  - Renaming an entity property in Java creates a new orphaned column in MySQL, leaving the old column with stale data.
  - Do not treat `ddl-auto=update` as a complete schema migration tool.
- **Safety Rules**:
  - Before renaming, modifying data types, or removing fields in an Entity, thoroughly assess the impact on existing data, queries, and constraints.
  - Never drop tables, truncate user data, reset the database, or execute destructive DDL commands on environments containing real data.
  - Always verify that JPA entity annotations (`@Column(name = "...")`, `@Table(name = "...")`) strictly match the MySQL schema.
  - Ensure foreign key relationships use `FetchType.LAZY` to prevent N+1 query performance degradation.
- **Migration Recommendation**:
  - For future production stability, moving from `ddl-auto=update` to a versioned migration tool (Flyway or Liquibase) is strongly recommended.
  - Do NOT introduce Flyway/Liquibase unilaterally; submit it as an explicit architectural proposal for project owner approval.

## 6. Security
Test relevant cases for:
- Unauthenticated access.
- Unauthorized roles.
- Access to another user's private resources.
- Invalid input.
- Sensitive information exposure.
- Invalid or expired credentials.

## 7. Regression
After changing a shared component or API:
- Identify all known consumers.
- Check affected screens and modules.
- Verify that unrelated behavior remains intact.

## 8. Completion Criteria
Before marking a task complete:
- Review the code changes.
- Run relevant tests and analysis.
- Run the applicable build check.
- Fix errors introduced by the change.
- Document remaining failures or limitations.

Never replace an actual verification result with an assumption.
