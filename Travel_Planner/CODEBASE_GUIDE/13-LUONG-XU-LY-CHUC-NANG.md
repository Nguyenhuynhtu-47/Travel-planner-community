# 13. Luồng xử lý end-to-end

## Đăng nhập
~~~mermaid
sequenceDiagram
 participant UI as Login
 participant N as AuthNotifier
 participant R as AuthRepository
 participant A as ApiClient
 participant C as AuthController
 participant S as AuthServiceImpl
 participant DB as UserRepository
 UI->>N: credentials
 N->>R: login()
 R->>A: POST /api/auth/login
 A->>C: JSON
 C->>S: authenticate
 S->>DB: find username/email
 S->>S: BCrypt + status + JWT
 S-->>A: AuthResponse
 A-->>N: token and user
 N->>N: save through AuthStorage
 N-->>UI: authenticated state
~~~

## Tạo itinerary/activity
Screen → request model toJson → ItineraryCrudRepository → ApiClient with Bearer → POST itinerary/nested day/activity → ItineraryController → ItineraryService validates business rules/owner → JPA repositories/entities → response DTO → Flutter model/notifier → rebuild. Reorder sends ordered list and backend safely updates order to avoid collisions. Delete status behavior must be read in implementation.

## Search place and add activity
Picker debounces input and tags request IDs so stale results are ignored → LocationRepository skips query <2 chars and requests /api/locations/search with mode/session → LocationController/LocationService validate and select provider → query understanding, geographic filter/ranking/cache → DTO results → user chooses place or map pin → CustomLocationResult validates coordinates → create/update activity request persists location metadata. TomTom suggestion may require details endpoint. CARTO tile fetch is a separate stream.

## Comments/replies
CommentsSection constructs CommentsNotifier scoped to itinerary OR activity. Root page loaded first; replies fetched independently. Submit with parentCommentId calls reply endpoint, not root comment endpoint. Backend requires public target and active user; resolves root by traversing parent chain; saves parent and root IDs. Client holds reply list under root, does not indent indefinitely. Delete is soft and content placeholder retained. Guests read public resources; writes require auth.

## Profile/handle
Profile API gets current identity from security principal. Public user endpoints address by numeric id or normalized handle. Handle service strips accents and normalizes; format 3–30 chars; collision fallback uses id/counter. App startup runner backfills missing handles. This is different from private login username.

## Upload
Image picker provides bytes/name → multipart POST /api/media/images with JWT → backend validates file and signs Cloudinary call with server secret → secureUrl response → frontend stores URL in profile/activity. Secret never belongs in Flutter.
