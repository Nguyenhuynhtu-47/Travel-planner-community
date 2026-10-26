
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
- docs/ai/09-development-log.md
- docs/ai/10-animation-guidelines.md

For business requirements, also consult:
- docs/Travel_Planner_Function_Specification.md

Read UI and UX documents for all interface changes.
Read docs/ai/10-animation-guidelines.md for relevant Flutter UI animation decisions (backend-only tasks are exempt).
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
- Follow docs/ai/10-animation-guidelines.md for relevant Flutter UI tasks (inspect code first, default to subtle motion, use Flutter-native primitives, allow zero-motion decisions; backend-only tasks are exempt).
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

## 9. Development Log (Mandatory)

Maintain a single development log at:

`docs/ai/09-development-log.md`

### Before Starting a Task
- Read `docs/ai/09-development-log.md` if it exists.
- Review the relevant source code, Git state, and related project documentation.
- Use the log as historical context, not as proof that the current code is correct.
- Verify the actual implementation before continuing previous work.

### After Completing a Task
Update `docs/ai/09-development-log.md` in the same task whenever implementation, testing, configuration, or documentation changes are made.

Record:
- Date and task summary.
- Git branch and relevant commit information, when available.
- Features completed, partially completed, or still pending.
- Important files created or modified.
- API, database, architecture, or UI changes, if applicable.
- Tests and build commands actually executed and their results.
- Bugs fixed, known issues, blockers, and technical decisions.
- Recommended next steps.

### Log Maintenance Rules
- Append a new dated session entry instead of creating a new log file.
- Update the current project status and next steps when they change.
- Keep historical entries useful and concise.
- Never invent completed work, test results, commits, or implementation details.
- Distinguish verified facts from assumptions and unverified information.
- Do not replace or duplicate the existing project specifications and coding rules.
- Do not modify unrelated files solely to update the log.
- If the task is interrupted or incomplete, record the actual progress and remaining work.

### Completion Report
The final task report must summarize the implementation and checks performed, and confirm whether `docs/ai/09-development-log.md` was updated. If the log could not be updated, explain why.

### Language Requirements (Mandatory)

- Write all content in `docs/ai/09-development-log.md` in English, including headings, session entries, summaries, status updates, technical decisions, known issues, and next steps.
- Use clear, concise, professional technical English.
- Do not write Vietnamese sentences or paragraphs in the development log, even when the task instructions or conversation are in Vietnamese.
- Keep code identifiers, file paths, API endpoints, commands, and technical names unchanged.
- When documenting Vietnamese UI messages or user-facing text, preserve the original text only when necessary and briefly explain it in English.
- Before completing a task, check all newly added or modified log content for Vietnamese text and rewrite it in English.
- When updating existing entries, preserve historical accuracy. Translate existing Vietnamese prose into English only when needed for consistency; do not change technical facts, test results, or historical meaning.