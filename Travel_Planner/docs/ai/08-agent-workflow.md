
# AI Agent Workflow

## Phase 1: Understand
1. Read AGENTS.md.
2. Read the project context and relevant AI documents.
3. Read the related feature specification.
4. Inspect existing implementation and dependencies.
5. Identify missing requirements and conflicts.

Do not start coding before understanding the existing module.

## Phase 2: Plan
Create a concise plan containing:
- Expected behavior.
- Files to create or modify.
- Frontend changes.
- Backend changes.
- Database changes, if required.
- API contract changes, if required.
- Tests and verification steps.

Prefer the smallest complete implementation.

## Phase 3: Confirm
Ask for clarification before implementation when:
- Requirements are ambiguous in a material way.
- Business rules conflict.
- A change may delete or migrate important data.
- A major architecture or API decision is required.

Do not ask unnecessary questions when the requirements
and existing conventions already provide a clear answer.

## Phase 4: Implement
- Follow the documented architecture and coding rules.
- Reuse existing components and services.
- Keep UI consistent with the design system.
- Handle loading, empty, success and error states.
- Validate input on the backend.
- Enforce permissions on the server.
- Keep frontend and backend contracts synchronized.
- Avoid unrelated changes.

## Phase 5: Verify
Run applicable:
- Formatters.
- Static analysis.
- Unit and integration tests.
- Frontend build.
- Backend build.
- Manual checks for important UI flows.

Choose checks based on the files changed and the tools available.

## Phase 6: Review
Check for:
- Duplicated code.
- Inconsistent UI.
- Broken API contracts.
- Missing validation.
- Security and authorization gaps.
- Unhandled errors.
- Unnecessary dependencies.
- Unintended changes to unrelated files.

## Phase 7: Report
Provide:
1. Summary of the implementation.
2. Files created or changed.
3. Important technical decisions.
4. Tests and commands actually executed.
5. Build results.
6. Known issues and unverified behavior.

## Task Boundaries
Do not claim that a feature is fully complete if only
its UI, API or database layer has been implemented.

Distinguish clearly between completed, partially completed
and blocked work.
