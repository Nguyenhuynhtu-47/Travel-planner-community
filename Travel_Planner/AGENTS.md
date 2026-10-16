
# Travel Planner - Agent Instructions

## 1. Project Overview
Travel Planner is a community platform for sharing,
discovering, saving, reusing and personalizing travel itineraries.

Technology stack:
- Mobile: Flutter
- Web: Flutter Web
- Backend: Spring Boot
- Database: MySQL
- Communication: REST API with JSON

Both mobile and web use the same backend API.

## 2. Mandatory Documentation
Before implementing a task, read the relevant documents:

- docs/ai/00-project-context.md
- docs/ai/01-architecture.md
- docs/ai/02-coding-rules.md
- docs/ai/03-api-contract.md
- docs/ai/04-ui-design-system.md
- docs/ai/05-ux-guidelines.md
- docs/ai/06-feature-spec.md
- docs/ai/07-testing-quality.md
- docs/ai/08-agent-workflow.md

For business requirements, also consult:
- docs/Travel_Planner_Function_Specification.md

Read UI and UX documents for all interface changes.
Read API and architecture documents for frontend-backend changes.

## 3. Existing Project Rules
- Inspect the existing project before changing code.
- Preserve the current folder structure unless a change is necessary.
- Reuse existing components, services and utilities.
- Do not duplicate existing functionality.
- Do not rewrite working modules without a clear reason.
- Do not invent business rules, endpoints or database fields.
- Do not introduce dependencies without justification.
- Do not modify unrelated files.

## 4. Frontend and Backend
- Flutter mobile and Flutter web must use the same backend contract.
- Backend business rules must be enforced on the server.
- Never rely on frontend checks alone for authorization.
- Keep API models consistent with actual backend DTOs.
- Handle loading, empty, success and error states.
- Keep the UI consistent with the shared design system.

## 5. UI/UX Requirements
- Follow docs/ai/04-ui-design-system.md.
- Follow docs/ai/05-ux-guidelines.md.
- Prefer clean, practical and content-focused interfaces.
- Avoid excessive cards, shadows, icons and decorative elements.
- Do not introduce arbitrary colors or inconsistent spacing.
- Make mobile and web layouts appropriate to their platforms.

## 6. Implementation Workflow
- Inspect the relevant files first.
- Identify requirements and acceptance criteria.
- List the files that need to change.
- Implement in small, focused steps.
- Update related tests and documentation when necessary.
- Ask for clarification when requirements conflict.

## 7. Quality Assurance
- Run relevant tests and static analysis.
- Verify the affected application builds when possible.
- Fix issues introduced by the changes.
- Never claim a test or build passed unless it was run.
- Report incomplete checks and known limitations.

## 8. Completion Report
When finishing a task, report:
1. What was implemented.
2. Files created or modified.
3. API or database changes, if any.
4. Tests and build checks actually performed.
5. Remaining issues or assumptions.
