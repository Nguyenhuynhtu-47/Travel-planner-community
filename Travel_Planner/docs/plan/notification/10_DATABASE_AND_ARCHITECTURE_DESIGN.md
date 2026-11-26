# Database và Backend Architecture Design

**Trạng thái:** Logical proposal and implementation reviewed against the project's JPA/Hibernate schema convention. The additive notification mappings were verified on owner-approved `travel_planner_test` (MySQL 8.0.44) on 2026-11-26. Production schema remains unverified and must be provisioned through the existing operational database process.

## Source schema evidence

JPA source maps `User` to `users` with `user_id` Java Integer; `Friendship` to `friendships` with unique `(user_low_id,user_high_id)`; `Follow` to `follows` with pair uniqueness; `Post` to `posts`; `PostLike` to `post_likes` unique `(post_id,user_id)`; `PostComment` to `post_comments`; itinerary/activity thread comments to `comments` with nullable activity/parent/root; `PostReport` to `post_reports`; `Conversation`, `Message`, `ConversationReadState` to messaging tables; `AuditLog` to `audit_logs`; settings to `system_settings`. IDs vary: Post/Message/Comment often Long, User/Itinerary/Activity Integer. Confirm actual column type and FK in MySQL before new FK.

`CODEBASE_GUIDE/db_info` is a source-derived inventory, not proof current runtime schema equals source. Existing schema strategy/config, exact production version and migration history must be verified before rollout. No destructive change or inferred runtime table claim.

## Proposed tables

### 1. `notifications` — Center personal social/moderation items

| Column proposal | Type/logical constraints | Purpose |
|---|---|---|
| `notification_id` | BIGINT auto PK (confirm convention) | Stable sort/read identifier |
| `recipient_user_id` | NOT NULL FK to `users.user_id`; physical type must match Integer column | Owner/authorization and user feed |
| `actor_user_id` | nullable FK to users | Social actor or Admin who performed an action |
| `type` | bounded VARCHAR or JPA string enum, NOT NULL | Personal event type or the single `SYSTEM` Center group; messaging stays push-only |
| `action_type` | nullable JPA string enum | Concrete Admin action such as `ACCOUNT_SUSPENDED`, `POST_HIDDEN`, `REPORT_RESOLVED`; null for non-Admin notifications |
| `target_type` | nullable bounded VARCHAR | Explicit target discriminator |
| `target_id` | nullable signed ID matching target domain only after mapping | Polymorphic target; cannot FK a single column to multiple domain tables |
| `source_event_key` | nullable bounded VARCHAR, unique where supported | Idempotency per actual state transition (do not key only actor+target for repeat comments) |
| `title` | bounded VARCHAR | Snapshot display title or template output |
| `body` | bounded VARCHAR/TEXT per UX limits | Safe user-facing text; never message content or admin-private note |
| `created_at` | NOT NULL datetime consistent with existing LocalDateTime storage | Stable feed order |
| `read_at` | nullable datetime | NULL means unread; avoid duplicate boolean |
| Like aggregation fields | only if group-row selected: `group_started_at`, `group_window_end`, aggregate count if not derived | Limit use to C4; avoid unused nullable fields on every row if separate group table selected |

**PK/FK:** PK `notification_id`; recipient/actor FKs. Target is resolved by allowlisted domain query and reauthorization, not polymorphic FK. Actor deletion rule should follow user deletion/anonymization policy.

**Indexes:** `(recipient_user_id, created_at, notification_id)` for descending cursor; unread index candidate `(recipient_user_id, read_at, created_at)` only after MySQL EXPLAIN. Unique `source_event_key` may need nullable semantics/unique scope; define per-type operation before DDL. Avoid redundant indexes.

**Reads:** recipient page with projection; unread `COUNT(*) WHERE recipient=? AND read_at IS NULL`; read-one updates `WHERE id=? AND recipient=? AND read_at IS NULL`; read-all uses cutoff/watermark to leave concurrent new records unread.

**Deletion:** choose cascade/anonymize for user deletion and retention for old notifications. Do not cascade a target deletion into another owner's history without explicit policy; stale target resolver displays safe unavailable content. Define retention period before adding cleanup.

### 2. `system_announcements` — one content record per publication

| Column proposal | Purpose |
|---|---|
| `announcement_id` BIGINT PK | Stable announcement identity |
| `created_by_user_id` FK to users, nullable only if preserving content after admin deletion is required | Authorship/audit link |
| `title` bounded VARCHAR, NOT NULL | Notification list title |
| `body` TEXT/bounded by API | User-facing body, no internal notes |
| `type` VARCHAR(24), legacy compatibility | No longer an announcement category; writes normalize to `SYSTEM`, API returns `SYSTEM` |
| `status` VARCHAR DRAFT/PUBLISHED/CANCELLED | Lifecycle; expiration can be derived from `expires_at` |
| `created_at`, `updated_at` | Audit timestamps |
| `published_at` nullable | Publication time |
| `expires_at` nullable | Exclude expired announcements from Center and badge |
| optional delivery fields | `push_status/attempt_count/next_attempt_at/sent_at` only if approved durable broadcast job uses this row; not required for Center |

FK creator deletion: preserve immutable announcement and set creator null only if policy/schema permits. Publish/cancel transitions audited. Published body edit behavior/versioning remains a decision; proposal is immutable after publish and create a replacement if corrected.

### 3. `announcement_reads` — receipt per user/content

Columns `announcement_id`, `user_id`, `read_at`; PK `(announcement_id,user_id)`; FKs to announcement/users; upsert once, idempotent. User-first index `(user_id,announcement_id)` can support a consolidated read list, but test EXPLAIN. Delete receipts with purged announcement; retain announcement content/history per admin policy. User deletion cascades/anonymizes by account policy.

### 4. `user_device_tokens` — FCM registration, not push history

Columns `device_token_id` PK, `user_id` FK, unique `fcm_token`, `platform`, `created_at`, `updated_at`, `last_seen_at`, nullable `disabled_at`. Candidate index `(user_id,disabled_at)`. No model/device name/location/fingerprint. Token upsert transfers unique token to current account; invalid FCM token is disabled. Logout unregister vs detach, account deletion, token retention need approval. Never return token in normal API or log.

### 5. `notification_like_actors` — selected for C4

This child table stores current actor membership for an unread grouped-Like notification; it is not a copy of all `post_likes` and is not required to render every actor in the UI. It uses a generated PK, unique `(notification_id,actor_user_id)`, FK to notification and actor, `created_at`, and indexes for actor lookup/count. The notification row keeps latest actor and aggregate text/count for the Center tile; membership makes unlike behavior exact even when the actor is not the latest displayed actor.

## C4 Like aggregation — approved decision (2026-11-26)

- Use fixed UTC calendar-day aggregation per `(recipient, post, type)` for the current unread group. A read group is immutable; a later day creates a new row. The child actor relation supports exact membership and race-safe counts.
- Unlike before mark-read removes actor membership; count derives from child rows; if empty, delete the unread group. Unlike after read preserves history. Re-like adds the actor to the current unread bucket, creating a fresh unread row when the prior group is already read. This differs from current total `Post.likeCount`, which counts active domain likes.
- Concurrent like/unlike/read operations: persist domain PostLike unique pair and serialize aggregate/read mutation with the recipient row lock; parent and actor uniqueness protect duplicate membership. Do not catch arbitrary DB errors as idempotent.
- Alternative single `notifications` row with JSON actor IDs rejected: unbounded, concurrency/read updates costly. Individual rows + UI aggregation is simpler storage schema but violates the requirement to aggregate persisted like items; not selected.
- Rolling 24h was not selected. The selected child table is mapped as a JPA entity and tested in the isolated test schema; no feature-specific SQL or migration framework is used.

## Announcement storage comparison

| Option | Space/write | Pagination/unread | Future account | Decision |
|---|---|---|---|---|
| One shared row + read receipt | O(announcements + actual reads); no audience fanout | Anti-join for unread; Center merges two sorted feeds/cursor | Visible while active if query-time audience | Recommended, if future users should see active items |
| Copy one Notification row per recipient | O(user count × announcements) | Simple unified list/count | Requires backfill for new accounts | Reject: duplicate content/fanout, contradicts scale goal |
| Global cursor/watermark per user | Few read rows | A single watermark cannot represent arbitrary per-item reads unless order/exception model grows | New user baseline semantics complex | Not selected unless all-read-only UX |
| FCM topic only | No Center storage | No history, no read state/unread page | No replay for later users | Not sufficient; topic is dispatch only |

Unread announcement count: active `PUBLISHED` and (`expires_at IS NULL OR > now`) rows anti-joined against receipt for principal. List includes both read/unread for active items. Query-time audience means future active accounts see unexpired announcement; requires owner approval.

## Event and transaction architecture

1. Domain service establishes successful transition and recipient.
2. Social/moderation Center record is inserted in same DB transaction, using explicit event key; rollback removes both domain mutation and notification.
3. AFTER_COMMIT event sends FCM/realtime invalidation. FCM must not run before commit.
4. Best-effort `@TransactionalEventListener(AFTER_COMMIT)` has crash-loss window; `@Async` does not make it durable. Existing chat listener is after-commit with local simple broker; no generic durable worker verified.
5. Outbox: consider bounded outbox for social/moderation retry only if reliability SLA requires it. Alternative delivery state on notification row couples concerns. Announcement row itself can represent a pending broadcast if delivery state columns are approved. Message Push is separate and has no per-message outbox; durable option, if required, is coalesced by recipient/conversation/window.

## API/data security

Principal sets recipient. Admin endpoints role-guarded. Unique ids must not reveal other users. Target IDs are hints, not authorization. FCM token is secret. Body/actor snapshot privacy and localization must be decided. User deletion, notification retention and stale target behavior must be tested.

## DDL gate

Before a production schema rollout: confirm live database name/version/schema fingerprint without printing credentials; rehearse backup/restore; review the compatible migration method, data types/constraints, execution order and additive rollback plan. Do not trust Hibernate `update` as a production migration. The current test-database approval does not authorize production DDL.

### Admin action notification schema update — 2026-11-26

- `notifications.action_type` is nullable and stores `NotificationActionType`; no new history table or FK is added.
- The Admin history endpoint filters this column and indexes `(action_type, target_type, target_id, created_at, notification_id)` for target-filtered, newest-first review; it paginates in the database and fetches the actor in the same query.
- The existing MySQL test database auto-added this column via JPA and persisted/read an Admin action successfully. Only `travel_planner_test` was changed.
- The source no longer maps `system_announcements.type` as an enum. Its existing non-null column is retained as a string for compatibility and set to `SYSTEM` on new/update writes. On a production database still using a MySQL enum, provision the column as `VARCHAR(24)` through the existing reviewed DBA process before deploying `ddl-auto=validate`.
- Ensure production `notifications.type` accepts `SYSTEM` (retain `MODERATION_UPDATE` for old rows or convert the column to a string column), and add nullable `notifications.action_type` with the new action enum values. Inspect the live schema before writing the corresponding DDL.
- Existing `MODERATION_UPDATE` rows remain readable as a deprecated compatibility alias and are normalized to `SYSTEM` by API/filtering; no existing notification history is rewritten by app startup.
- No SQL deployment script or schema reset was added. Production schema and rollback rehearsal are unverified.

## Phase 1 implementation evidence — 2026-11-26

- Source now maps the additive `notifications` table in `model/Notification.java`; it references `users.user_id` for recipient and optional actor, and stores polymorphic target IDs as bounded strings because source entity IDs vary between Integer and Long.
- MySQL test confirmed the FK types, unique `(recipient_user_id, source_event_key)`, feed/unread indexes, keyset query, unread aggregate, scoped read updates and watermark update. Integration tests ran against `travel_planner_test` / MySQL 8.0.44; no dev/production database was accessed.
- Notification tables are mapped by JPA entities and repositories and follow the existing local/test `ddl-auto=update` convention. Production remains `ddl-auto=validate`; provisioning through the existing operational database process has not been verified. This feature adds no migration framework or SQL deployment scripts.
- The service locks the recipient row for create and read-all. Create deduplicates by the recipient-scoped event key; a unique constraint remains the final guard.
- C4 is implemented in source: UTC calendar-day grouping; unlike removes actor only while unread and preserves read history; re-like joins the current unread group. The `notification_like_actors` JPA mapping was exercised in `travel_planner_test`. Notification retention is unchanged.
- Rollback is forward-safe: an application rollback leaves the additive table in place. Do not drop it as part of rollback; archive/retain records and remove the table only under a separately reviewed data-retention procedure.

## Phase 3 implementation decision — 2026-11-26

- User approved the shared-row design and future-user semantics: any ACTIVE account can read currently PUBLISHED, unexpired announcements, including accounts created later.
- `system_announcements` and `announcement_reads` are modeled in JPA. Local/test schema follows Hibernate configuration; production schema provisioning remains unverified and is outside this source change.
- Announcement receipts are inserted only after an explicit open. Personal `read-all` deliberately does not create announcement receipts.
- Mobile feed merges bounded source queries using opaque Base64 cursor `(createdAt,id,source)` and at most `2*(size+1)` rows; no audience fanout/copies are created.
- FCM delivery is not enabled in this phase. Token registration, reliable delivery and credentials remain later-phase work and unverified.
