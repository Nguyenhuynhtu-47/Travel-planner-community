# AI Agent Workflow

## Phase 1: Understand
1. **Read `AGENTS.md` first:** Contains mandatory project-wide instructions and constraints.
2. **Read `DESIGN.md`:** Primary reference for visual design decisions, design tokens, typography, spacing, and component styling.
3. **Read relevant AI documentation:**
   - Architecture: `docs/ai/01-architecture.md`
   - Coding conventions: `docs/ai/02-coding-rules.md`
   - API contracts: `docs/ai/03-api-contract.md`
   - Canonical UI design system: `docs/ai/04-ui-design-system.md` (canonical project-specific implementation guide)
   - UX guidelines: `docs/ai/05-ux-guidelines.md`
   - Feature specifications: `docs/ai/06-feature-spec.md` and `docs/Travel_Planner_Function_Specification.md`
   - Testing & quality: `docs/ai/07-testing-quality.md`
   - Development history: `docs/ai/09-development-log.md`
   - Animation guidelines: `docs/ai/10-animation-guidelines.md` (mandatory for relevant Flutter UI tasks; backend-only tasks exempt)
4. Inspect existing implementation and dependencies across `frontend/mobile`, `frontend/web`, and `backend`.
5. Identify requirements, missing specifications, and potential conflicts.

Do not start coding before understanding the existing module.

## Phase 2: Plan
Create a concise plan containing:
- Expected behavior and observable acceptance criteria.
- Files to create or modify.
- Frontend changes (reuse canonical tokens from `docs/ai/04-ui-design-system.md` and shared widgets).
- Motion & animation analysis for Flutter UI tasks (follow `docs/ai/10-animation-guidelines.md`: inspect code first, assess frequency of use, select motion level [Level 0 None, Level 1 Subtle, Level 2 Moderate, Level 3 Expressive], choose Flutter-native technique, or document that no animation is necessary).
- Backend changes (maintain contracts and permissions).
- Database changes, if required.
- API contract changes, if required.
- Tests and verification steps.

Prefer the smallest complete implementation.

## Phase 3: Confirm
Ask for clarification before implementation when:
- Requirements are ambiguous in a material way.
- Business rules or documentation sources conflict.
- A change may delete or migrate important data.
- A major architecture, database, or API decision is required.

Do not ask unnecessary questions when the requirements and existing conventions already provide a clear answer.

## Phase 4: Implement
- Follow the documented architecture and coding rules.
- Treat `docs/ai/04-ui-design-system.md` as the canonical project-specific UI implementation guide.
- Reuse existing design tokens and shared components (`lib/shared/widgets/`).
- For Flutter UI motion, follow `docs/ai/10-animation-guidelines.md`: default to subtle, purposeful motion, use Flutter-native implicit or explicit animation widgets, strictly prohibit React/npm packages, and always dispose `AnimationController` instances in `dispose()`.
- Avoid unnecessary redesigns, duplicated styling definitions, and unrelated changes.
- Handle loading, empty, success, and error states.
- Validate input on the backend; never trust frontend checks alone.
- Enforce permissions and resource ownership on the server.
- Keep frontend and backend contracts synchronized.

## Phase 5: Verify
Run applicable verification checks based on the tools available and the scope of change:
- Formatters (`dart format`, etc.).
- Static analysis (`flutter analyze`).
- Unit and integration tests (`flutter test`, `.\mvnw.cmd test`).
- Build checks when feasible.
- UI checklist: token consistency, responsive breakpoints (< 744px, 744–1128px, > 1128px), touch targets >= 48x48dp, and error/empty states.
- Animation verification (for UI motion): ensure `AnimationController` is disposed, verify accessibility behavior when `disableAnimations` / reduced motion is active, ensure 60fps performance without frame drops, and use `tester.pump(duration)` rather than unbounded `pumpAndSettle()` when continuous spinners or shimmers are present.

Never claim a test or build check passed unless it was physically executed in the workspace.

## Phase 6: Review
Check for:
- Duplicated code or hardcoded visual values.
- Inconsistent UI or deviation from the canonical design system.
- Undisposed animation controllers, unjustified/distracting animations, or React/web animation packages in Flutter code.
- Broken API contracts or orphaned database columns.
- Missing input validation or authorization vulnerabilities.
- Unhandled error scenarios.
- Unnecessary new dependencies.
- Unintended changes to unrelated files.

## Phase 7: Document and Log
1. Maintain documentation integrity; update API or feature docs when contracts change.
2. **Append a dated English entry to `docs/ai/09-development-log.md`:**
   - Date and task summary.
   - Files created or modified.
   - Key technical or design-system decisions.
   - Tests and commands actually executed with real results.
   - Known limitations or remaining follow-ups.

## Phase 8: Report
Provide:
1. Summary of the implementation.
2. Files created or changed.
3. Important technical decisions (including motion level and rationale for Flutter UI tasks, or rationale if no animation was needed).
4. Tests and commands actually executed with verified results.
5. Remaining issues, assumptions, or recommended next steps.

## Task Boundaries
Do not claim that a feature is fully complete if only its UI, API, or database layer has been implemented.
Distinguish clearly between completed, partially completed, and blocked work.
