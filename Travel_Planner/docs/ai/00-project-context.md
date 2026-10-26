
# Project Context

## 1. Project Name
Travel Planner

## 2. Project Description
Travel Planner is a community platform where users can
share travel itineraries, discover trips created by others,
save itineraries, reuse existing trips and personalize
them according to their own needs.

The platform focuses on community-generated travel content
rather than only displaying predefined travel packages.

## 3. Project Objectives
- Help users discover useful travel itineraries.
- Allow users to create and manage their own itineraries.
- Support saving, copying and personalizing itineraries.
- Encourage community participation through ratings and comments.
- Help users organize destinations, activities, schedules and budgets.
- Provide administrative tools for platform management.

## 4. Technology Stack
- Mobile application: Flutter
- Web application: Flutter Web
- Backend: Spring Boot
- Database: MySQL
- Frontend-backend communication: REST API and JSON

Use the versions and dependencies already defined in the project.
Do not upgrade frameworks without a clear reason.

## 5. User Roles

### Guest
- Register and log in.
- Explore publicly available itineraries.
- Search, filter and sort itineraries.
- View itinerary details and supported destination information.

### User
- Manage personal profile and privacy settings.
- Create, view, edit and delete owned itineraries.
- Organize itineraries by day, destination and activity.
- Save and reuse existing itineraries.
- Personalize copied itineraries.
- Rate and comment on eligible itineraries.
- Follow other users if supported by the feature specification.
- Receive notifications where implemented.

### Admin
- Manage users and itinerary content.
- Manage locations and destination information.
- Moderate ratings, comments and reported content.
- Handle violations and account restrictions.
- View administrative statistics and dashboards.

The exact permissions must follow the feature specification
and backend authorization rules.

## 6. Main Functional Modules
- Authentication and authorization
- User profile and privacy
- Itinerary management
- Itinerary discovery
- Search, filtering and sorting
- Destinations and map integration
- Saved itineraries and itinerary reuse
- Ratings and comments
- User following and community interactions
- Notifications
- Administration and moderation

## 7. Platform Responsibilities
Flutter Mobile:
- Provide mobile-friendly navigation and interactions.
- Support one-handed usage where practical.
- Adapt layouts to smaller screens.

Flutter Web:
- Serve primarily as the administration, moderation, and content management platform (`frontend/web`).
- Provide responsive layouts for desktop, tablet, and compact screens.
- Use available screen width effectively (side navigation, split panels).
- Support efficient data filtering, moderation, user management, and metrics reporting.

Spring Boot:
- Expose APIs for both Flutter platforms.
- Enforce business rules and permissions.
- Validate requests and manage database operations.
- Return consistent responses and errors.

MySQL:
- Persist application data and relationships.
- Enforce appropriate keys, constraints and indexes.

## 8. Product and Design Principles
- Usability before decoration.
- Root visual design reference: `DESIGN.md` defines the overarching visual language (Airbnb-inspired photography-led consumer marketplace, pure white canvas `#FFFFFF`, Rausch `#FF385C` primary brand voltage, soft rounded geometry, and modest typographic weights).
- Canonical implementation guide: `docs/ai/04-ui-design-system.md` adapts the visual reference into concrete Flutter tokens, component conventions, and platform rules for the project.
- Consistency across mobile and web screens.
- Clear separation of responsibilities between presentation, business rules, and data access.
- Secure access to private user data.
- Reuse existing functionality and shared components where possible.
- Keep features aligned with documented requirements.

## 9. Scope Control
Do not invent new major features or business rules.
If a requirement is missing, inspect existing documentation
and implementation first.
Ask for clarification when the decision materially affects
the product or data model.

## 10. Sources of Truth
- Mandatory agent instructions: `AGENTS.md`
- Root visual design reference: `DESIGN.md`
- Feature scope: `docs/Travel_Planner_Function_Specification.md`
- Architecture: `docs/ai/01-architecture.md`
- Coding conventions: `docs/ai/02-coding-rules.md`
- API contracts: `docs/ai/03-api-contract.md`
- Canonical UI design system: `docs/ai/04-ui-design-system.md`
- UX guidelines: `docs/ai/05-ux-guidelines.md`
- Feature specifications: `docs/ai/06-feature-spec.md`
- Testing & quality assurance: `docs/ai/07-testing-quality.md`
- AI Agent workflow: `docs/ai/08-agent-workflow.md`
- Animation guidelines: `docs/ai/10-animation-guidelines.md`
