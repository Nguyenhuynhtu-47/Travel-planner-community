
# Feature Specification Rules

## 1. Source of Truth
The main functional specification is:

docs/Travel_Planner_Function_Specification.md

Read the relevant sections before implementing a feature.

Do not duplicate the complete feature list in this file.
Update the main specification when approved requirements change.

## 2. Requirement Interpretation
For each feature, identify:
- Purpose.
- User roles.
- Preconditions.
- Main flow.
- Alternative flows.
- Validation rules.
- Business constraints.
- Expected results.
- Error cases.
- Acceptance criteria.

Do not implement only the visible UI while ignoring
the required backend behavior.

## 3. Roles and Permissions
Distinguish Guest, User and Admin permissions.

- Guest: public features and permitted authentication flows.
- User: authorized personal and community operations.
- Admin: administrative operations permitted by policy.

Use the detailed functional specification for exact permissions.
The backend must enforce access control.

## 4. Itinerary Business Rules
Before implementing itinerary operations, verify:
- Ownership and visibility rules.
- Required itinerary information.
- Day and activity relationships.
- Destination and schedule constraints.
- Budget and duration validation.
- Editing and deletion permissions.
- Public and private visibility behavior.

Do not invent unspecified validation limits.

## 5. Reuse and Personalization
Before implementing reuse:
- Verify whether reuse creates a new itinerary.
- Define ownership of the copied itinerary.
- Preserve the source itinerary.
- Follow the documented attribution rules.
- Record reuse history if required by the specification.
- Define which fields are copied and which are regenerated.

## 6. Community Interactions
Verify the documented rules for:
- Saving and unsaving itineraries.
- Rating eligibility.
- Comment creation and deletion.
- Following users.
- Notifications.
- Reporting and moderation.

Do not invent restrictions such as one-rating-only
unless the approved requirements specify them.

## 7. Implementation Requirements
A complete feature may require:
- Flutter UI (aligned with `docs/ai/04-ui-design-system.md` and `DESIGN.md`).
- Frontend state and validation.
- API client and data models.
- Spring Boot controller and service.
- Database changes when necessary.
- Authorization and error handling.
- Tests and documentation.

Implement only the layers required by the feature. Visual styling must consume the canonical UI design system tokens without altering or dropping specified business rules, endpoints, or data models.

## 8. Acceptance Criteria
Before coding, define observable acceptance criteria:
- Visual presentation adheres to canonical design tokens (colors, typography, spacing, 48x48dp touch targets, responsive layouts).
- Feature behavior conforms to the functional specification (`docs/Travel_Planner_Function_Specification.md`).
- Loading, empty (`AppEmptyState`), error (`AppErrorState`), and disabled states are handled.
- Server-side permissions and ownership checks are fully verified.

A feature is not complete merely because its screen renders.
Verify its business behavior, API integration, permissions
and relevant error states.

## 9. Requirement Conflicts
If the functional specification conflicts with the current
implementation or another document:
1. Identify the conflict.
2. Explain the impact.
3. Propose a resolution.
4. Obtain clarification when the decision changes
   business behavior, permissions or persisted data.
