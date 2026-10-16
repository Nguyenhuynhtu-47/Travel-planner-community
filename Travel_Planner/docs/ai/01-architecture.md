
# Architecture Guidelines

## 1. General Architecture
The project consists of:
- Flutter Mobile
- Flutter Web
- Spring Boot REST API
- MySQL database

Both Flutter applications communicate with the same backend.

Do not implement separate business logic for mobile and web
when the same backend functionality can be reused.

## 2. Flutter Architecture
Follow the established project directory structure in `frontend/mobile/lib/` and `frontend/web/lib/`.
Do not create arbitrary layers or duplicate folders.

### Root and Core Structure
- `lib/main.dart`: Root entry point, application initialization, and top-level MaterialApp.
- `lib/core/`:
  - `constants/`: Global constants, API route paths, assets, and storage keys.
  - `network/`: HTTP client wrapper, interceptors, error parsers, and base API clients.
  - `router/`: App navigation routes, route guards, and path definitions.
  - `theme/`: Design tokens, colors, typography, and ThemeData definitions.
  - `utils/`: Common helpers, formatters, and validators.
- `lib/shared/`:
  - `widgets/`: Truly shared UI components (buttons, dialogs, form fields, loading, empty, and error states).
- `lib/features/<feature_name>/`:
  - `data/` (when needed): Feature API data sources, DTOs, and repository implementations.
  - `domain/` (when needed): Feature models/entities and repository contracts.
  - `presentation/`:
    - `screens/` or `pages/`: UI screens for the feature.
    - `widgets/`: Feature-specific sub-widgets.
    - State management: Feature state coordinators (avoid empty domain/data layers if logic is simple).

Platform roles:
- Both Flutter Mobile and Flutter Web communicate with the same Spring Boot REST API and reuse the same backend business logic. Do not duplicate business logic or create separate APIs for mobile and web.
- `frontend/mobile`: Prioritizes the end-user experience (itinerary discovery, creation, editing, personalization, saved trips, profile, social interaction, and offline downloads).
- `frontend/web`: Prioritizes administration, moderation, and content management based on the current codebase scope (`dashboard`, `moderation`, `violations`, `users`), while maintaining responsive layouts. Do not assume Web is permanently restricted to Admin only if future business requirements expand user-facing web features.

## 3. Frontend Responsibilities
- Screens render UI and collect user input.
- Widgets handle focused presentation responsibilities.
- State management coordinates UI state and actions without embedding API calls directly in widgets.
- Repositories abstract data access and caching.
- API clients handle HTTP communication, serialization, and error mapping.
- Models and DTOs represent defined data contracts.
- Validation provides immediate user feedback before network dispatch.

Do not put HTTP requests and complex business logic directly
inside large screen widgets.

## 4. Spring Boot Architecture
Follow the layered structure established under `src/main/java/Travel_Planner/Travel_Planner/`:

### Package Naming and Legacy Convention
- **Root Package**: `Travel_Planner.Travel_Planner`. This capitalized root package name is a legacy convention inherited from the existing project setup. Preserve it across all imports and files to maintain compatibility. Do not create new root packages or perform bulk package renaming. Any standardization to standard Java lowercase package conventions will be handled in a dedicated refactoring phase subject to explicit project owner approval.
- **Subpackages**: Must be strictly lowercase: `controller`, `service`, `repository`, `model`, `dto`, `security`, `config`, `exception`, `mapper`, `validation`, `util`.

### Package Responsibilities
- `controller/`:
  - Handle HTTP requests and responses.
  - Validate request input (`@Valid`, `@Validated`).
  - Delegate all business operations to the service layer.
  - Keep controllers thin without business logic or database queries.
- `service/`:
  - Implement business rules and logic.
  - Enforce operation-level permissions and resource ownership.
  - Coordinate database transactions.
- `repository/`:
  - Access persistent data via Spring Data JPA interfaces.
  - Define custom JPQL/derived queries.
- `model/`:
  - Database-persisted JPA entities (Note: all entities reside in `model`, NOT `entity`).
  - Includes enums and JPA lifecycle hooks.
- `dto/`:
  - Request contracts in `dto/request/`.
  - Response contracts in `dto/response/`.
- `mapper/`:
  - Map between JPA entities and DTOs.
- `exception/`:
  - Global exception handler (`@RestControllerAdvice`) and custom domain exceptions.
- `security/`:
  - Security filter chain, authentication providers, and token filters.
- `config/`:
  - Application configuration (CORS, OpenAPI/Swagger, JPA auditing).
- `validation/`:
  - Custom validation annotations and validators.
- `util/`:
  - Cross-cutting utility classes.

### Transaction Management Rules
- **Layer Placement**: Place `@Transactional` annotations strictly at the Service layer when operations require data integrity. Do not annotate Controller methods or Repository interfaces with `@Transactional`.
- **Read-Only Operations**: Use `@Transactional(readOnly = true)` for query/read operations to optimize JDBC connection handling and avoid Hibernate dirty checking overhead.
- **Multi-Table Write Operations**: For operations modifying multiple tables or entities (e.g., creating an itinerary with days and activities, copying/reusing itineraries, updating counters alongside interaction records, cascading deletions), explicitly define the transaction boundary and rollback expectations.
- **Rollback Conditions**:
  - By default, Spring rolls back transactions automatically for unchecked exceptions (`RuntimeException` and `Error`).
  - Use `rollbackFor = Exception.class` only when there is a specific technical or business reason (such as checked exceptions thrown by business services or external libraries that must trigger rollback). Do not apply `rollbackFor = Exception.class` mechanically to every single method.
- **External Calls & Long-Running Tasks**:
  - Prioritize avoiding keeping database transactions open while invoking external network services (e.g., Map APIs, email services, payment gateways, external storage) or executing long-running tasks, to minimize connection pool exhaustion and timeout risks.
  - If a specific business flow genuinely requires coordinating with an external system, the service must explicitly define error handling and data consistency strategies (such as compensating actions or idempotency). Do not rigidly enforce a single design pattern for every case.
- **Exception Swallowing**: Never catch and swallow exceptions inside transactional methods unless explicit compensation is executed; unhandled failures must propagate to trigger rollback.

## 5. Database Rules
- Inspect existing schema and entity definitions before changing tables.
- Use explicit primary and foreign keys.
- Define appropriate constraints and indexes.
- Keep entity relationships consistent with business rules.
- Avoid destructive schema changes without approval.
- Use transactions for operations that require atomicity.
- Never expose sensitive fields (e.g., passwords, private tokens) through API responses.

## 6. Authentication and Authorization
- **Current Status**: Spring Security is currently configured with stateless session policy and `permitAll()` on all endpoints in `SecurityConfig.java`. No JWT filter, user authentication service, or token provider has been implemented yet. Do not claim that JWT or token authentication is already active in the codebase.
- **Confirmed Authentication Architecture**:
  - **JWT Bearer Token** is the confirmed authentication method for the shared REST API serving Flutter Mobile and Flutter Web.
- **Decisions Pending Project Owner Confirmation**:
  - Access token expiration duration and whether a refresh token strategy (rotation, storage) will be adopted.
  - Token revocation and logout handling (blacklist, database token tracking, or short-lived tokens).
  - Platform-specific secure token storage on Web and Mobile.
- **Core Enforcement Rules**:
  - Backend is the sole enforcer of authentication and authorization. Never rely on frontend checks or hidden UI elements as a security boundary.
  - Distinguish `401 Unauthorized` (unauthenticated, missing, or expired credentials) from `403 Forbidden` (authenticated, but lacking role permissions or resource ownership).
  - Server-side ownership checks: A user can modify or delete only resources they own, regardless of the user ID supplied in the request body.
  - Admin permissions (`ROLE_ADMIN`) must be strictly verified on the server for all administrative endpoints.

## 7. Shared API
- Mobile and web use the same API contract.
- Keep business logic in Spring Boot.
- Keep environment-specific API URLs configurable.
- Configure CORS specifically for required frontend origins:
  - Development: Allowed origins `http://localhost:8081` and `http://127.0.0.1:8081`.
  - Production: Dedicated domain configured via properties or environment variables.
- Do not hardcode secrets or production credentials.

## 8. Dependency Rules
- Reuse existing packages and frameworks.
- Add dependencies only when they provide clear value.
- Explain significant architectural changes before applying them.
- Avoid unnecessary abstraction and duplicated layers.

## 9. Architecture Changes
Before a significant change:
1. Inspect affected modules.
2. Identify dependencies and consumers.
3. Explain the reason for the change.
4. Assess impact on mobile, web, backend and database.
5. Update documentation and tests as needed.
