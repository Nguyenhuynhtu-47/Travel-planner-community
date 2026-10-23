
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
- Manual & Automated UI Verification Checklist:
  - **Theme and Design Token Consistency:** Confirm screens consume theme tokens from `Theme.of(context)` / `lib/core/theme/` (derived from canonical `docs/ai/04-ui-design-system.md` and `DESIGN.md`). Reject hardcoded hex colors, arbitrary margins, and ad-hoc decorations.
  - **Reusable Component Consistency:** Verify reuse of shared components from `lib/shared/widgets/` (`AppEmptyState`, `AppErrorState`, `AppLoadingIndicator`, shared buttons, search bars, and card shells).
  - **Text Readability & Accessibility:** Verify normal text (< 24px regular, < 18.66px bold, including standard 14px/16px button labels) targets minimum 4.5:1 contrast against its background (WCAG SC 1.4.3), and large text targets minimum 3.0:1. Non-text visual information necessary to identify UI components and states must target minimum 3.0:1 (WCAG SC 1.4.11). Note that white text (`#FFFFFF`) on resting Rausch `#FF385C` produces **3.52:1** (meeting 3.0:1 for large text and non-text UI components, but failing 4.5:1 for normal text); verify that buttons requiring strict 4.5:1 compliance at rest utilize the documented accessible proposal (`primary-accessible` `#D90740` at **5.18:1** vs `#FFFFFF`, or dark `ink` text `#222222` on `#FF385C` at **4.52:1**), while `#E00B41` (`primary-active` at **4.89:1** vs `#FFFFFF`) is reserved strictly for the `button-primary-active` press state. Passing contrast ratios is a design/testing target and does not guarantee overall WCAG compliance on its own. Form inputs must have visible labels and field error text. Touch targets must meet the minimum 48x48dp standard.
  - **Responsive Layout & Overflow Handling:** Test layouts across breakpoints (< 744px Mobile, 744px–1128px Tablet, > 1128px Desktop). Verify no render overflow bars (yellow/black tape) occur when resizing or rotating.
  - **State Handling:** Validate proper visual representation for Loading (skeletons and spinners), Empty (`AppEmptyState` with action), Error (`AppErrorState` with retry), and Disabled states.
  - **Navigation & Interaction Behavior:** Ensure smooth route transitions, persistent bottom navigation on mobile, persistent side rails on web, and sticky bottom/rail action bars.
  - **Cross-Platform Visual Consistency:** Confirm visual alignment between Mobile and Web while honoring platform ergonomic distinctions.

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
