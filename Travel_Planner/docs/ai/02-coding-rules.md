
# Coding Rules

## 1. General Principles
- Write readable, maintainable and focused code.
- Follow the existing conventions of each module.
- Prefer simple solutions over unnecessary abstractions.
- Keep functions and classes focused on one responsibility.
- Avoid duplicated logic.
- Remove unused imports, variables and obsolete code.
- Do not silently change existing business behavior.

## 2. Naming
### Flutter / Dart
- Classes and enums: UpperCamelCase.
- Variables and functions: lowerCamelCase.
- Constants: follow the existing Dart convention.
- File names: lowercase_with_underscores.dart.

### Spring Boot / Java
- Root package: `Travel_Planner.Travel_Planner`. This uppercase root package is a legacy exception inherited from the existing repository setup, not the standard Java lowercase convention for new projects. Preserve this casing across all files to maintain compatibility. Do not create new root packages or rename packages in bulk. Any refactoring to standard package conventions must be proposed as a separate refactor task and requires explicit project owner approval.
- Subpackage names: strictly lowercase (`controller`, `service`, `repository`, `model`, `dto`, `security`, `config`, `exception`, `mapper`, `validation`, `util`).
- Classes and interfaces: UpperCamelCase.
- Methods and variables: lowerCamelCase.
- Constants: UPPER_SNAKE_CASE.
- DTO names must clearly indicate their purpose and direction (`CreateItineraryRequest`, `ItineraryResponse`).

Use descriptive names related to the business domain.
Avoid unclear abbreviations.

## 3. Flutter Rules
- Use null safety correctly.
- Prefer const constructors where applicable.
- Extract reusable widgets when it improves clarity.
- Keep screens focused on presentation and interaction.
- Do not stuff entire business logic, API requests, and data mapping into large Widget classes; delegate to services, repositories, and state coordinators.
- Separate network communication from UI widgets into repositories or data sources.
- Handle asynchronous states and errors explicitly (Loading, Empty, Error, Success).
- Dispose controllers, stream subscriptions, and change notifiers when widgets unmount.
- State management:
  - Temporarily use Flutter's built-in mechanisms: `StatefulWidget`, `ChangeNotifier`, and `ValueNotifier`.
  - `StatefulWidget` is prioritized for local UI state (e.g., text controllers, tab switching, local visibility toggles).
  - `ChangeNotifier` or `ValueNotifier` is used when appropriate for shared state scope within a feature (e.g., listing feeds, form submission state).
  - Do not arbitrarily add external libraries (such as `flutter_bloc`, `provider`, or `riverpod`) to `pubspec.yaml` without approval.
  - Adding external state management is not permanently forbidden: if a complex feature warrants a dedicated library, the Agent must present the technical rationale, benefits, and architectural impact, and wait for project owner approval before modifying dependencies.

## 4. Spring Boot Rules
- Keep controllers thin.
- Put business rules in the service layer.
- Use DTOs for API input and output where appropriate.
- Validate incoming requests.
- Use appropriate transaction boundaries.
- Avoid exposing persistence entities directly by default.
- Use centralized exception handling.
- Apply authorization checks to protected operations.

## 5. API and Data
- Use consistent JSON field naming.
- Follow the existing API response conventions.
- Avoid undocumented changes to request and response fields.
- Handle null values and invalid input explicitly.
- Do not return internal exception details to clients.
- Avoid N+1 database queries where relevant.

## 6. Error Handling
- Handle expected errors explicitly.
- Show user-friendly messages in the UI.
- Keep technical details in appropriate logs.
- Never silently ignore important failures.
- Do not catch and suppress every exception.

## 7. Security
- Never hardcode passwords, API secrets or private keys.
- Do not commit environment files containing secrets.
- Validate user input on the backend.
- Check authorization for every protected operation.
- Do not trust client-supplied roles or ownership.
- Do not log credentials or sensitive personal data.

## 8. Dependencies
- Inspect existing dependencies before adding new ones.
- Explain why a new dependency is necessary.
- Avoid duplicate libraries with overlapping responsibilities.
- Do not perform unrelated dependency upgrades.

## 9. Code Changes
- Make the smallest reasonable change.
- Preserve backward compatibility where possible.
- Update related tests when behavior changes.
- Update documentation when contracts change.
- Do not delete working code without justification.

## 10. Comments
- Explain why complex logic exists, not obvious syntax.
- Keep comments accurate when code changes.
- Avoid redundant comments and excessive documentation.
