# 03. Tổng quan Backend

## Entry point và dependency
TravelPlannerApplication là entrypoint Spring Boot; component scan bắt đầu ở package legacy viết hoa Travel_Planner.Travel_Planner. pom.xml target Java 22, gồm Spring Web MVC, Data JPA, Security, Validation, REST client, JWT jjwt, MySQL connector, Caffeine, Bucket4j, Springdoc và test starters. Không rename package root hàng loạt.

## Request lifecycle
~~~mermaid
sequenceDiagram
 participant App as Flutter
 participant Jwt as JwtAuthenticationFilter
 participant C as Controller
 participant S as Service
 participant R as Repository
 participant DB as MySQL
 App->>Jwt: HTTP + JSON + Bearer token
 Jwt->>Jwt: validate token, load user
 Jwt->>C: principal in SecurityContext
 C->>S: validated request + actor
 S->>R: query/save
 R->>DB: JPA SQL
 DB-->>R: rows
 R-->>S: entities/pages
 S-->>C: response DTO
 C-->>App: status + JSON
~~~
Provider calls (location, route, image) branch from service into network APIs; not all requests touch DB.

## Packages
| Package | File count | Responsibility |
|---|---:|---|
| controller | 17 | HTTP mappings, auth principal, request/response |
| service | 39 | interfaces/implementations, business rules/provider orchestration |
| repository | 13 | Spring Data queries, paging |
| model | 20 | JPA entities, enums/domain values |
| dto | 40 | request/response/location/query contracts |
| security | 5 | JWT filter/provider/user details/security chain |
| config | 2 | config binding and startup work |
| exception | 9 | typed errors/response handling |
| seeder | 2 | seed data |
| util | 1 | shared helper |

mapper/validation folders are empty. Mapping may occur in services/builders.

## API groups
Auth /api/auth; health /api/health; itinerary/day/activity /api/itineraries; owned /api/user/itineraries; destinations /api/destinations, admin /api/admin/destinations; locations /api/locations/search, /providers/tomtom/details, /reverse-geocode, /nearby; comments itinerary/activity and /api/comments/{commentId}/replies; rating/favorite/save; users /api/users; upload /api/media/images; route /api/itineraries/{itineraryId}/days/{dayId}/route. Exact payload/status comes from controller annotations and DTO.

## Security
SecurityConfig is stateless, adds JwtAuthenticationFilter before username/password filter, permits selected public endpoints and requires authentication otherwise; admin endpoints require ADMIN. Services also enforce owner/scope checks. Older architecture/API docs say permitAll/no JWT; code now contradicts those statements.

## Errors and validation
DTOs use Jakarta constraints and controller @Valid where declared. Typed exceptions and ErrorResponse/security handlers produce status and JSON. Verify actual exception mapping for each error type rather than assuming all use one handler.
