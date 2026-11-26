# 10 — Backend tests

Backend test set hiện có 51 file. Tên file chỉ thể hiện inventory; không chứng minh test pass. Một số tests cần cấu hình DB/provider test. Kiểm kê: 2026-11-17.

## Cách chạy
```text
cd backend; .\mvnw.cmd test (Windows) / ./mvnw test (Unix).
```

Lần kiểm tra ngày 2026-11-17: messaging subset chạy 9 tests PASS; `TravelPlannerApplicationTests` chạy PASS trên MySQL 8.0.44 test schema. Full suite chạy 497 tests: 455 passed, 42 errors do FK test-data cleanup (`media_assets.uploaded_by`/`posts.author_id`) ở RatingControllerTest, RouteServiceTest, SavedItineraryControllerTest. Ba class này chạy riêng trên schema sạch: 42/42 passed. Đây không xác minh production DB.

## File inventory
- Travel_Planner/Travel_Planner/ActivityCommentPreservationTest.java
- Travel_Planner/Travel_Planner/ActivityLocationMigrationRunnerTest.java
- Travel_Planner/Travel_Planner/ActivityLocationTest.java
- Travel_Planner/Travel_Planner/AdministrativeAreaControllerTest.java
- Travel_Planner/Travel_Planner/AdministrativeAreaMigrationRunnerTest.java
- Travel_Planner/Travel_Planner/AdministrativeAreaRepositoryTest.java
- Travel_Planner/Travel_Planner/AdministrativeAreaResolverTest.java
- Travel_Planner/Travel_Planner/AdministrativeAreaValidatorTest.java
- Travel_Planner/Travel_Planner/AdminPlaceAdministrativeAreaControllerTest.java
- Travel_Planner/Travel_Planner/AuthControllerTest.java
- Travel_Planner/Travel_Planner/ChatRateLimiterTest.java
- Travel_Planner/Travel_Planner/CloneConcurrencyAndRollbackTest.java
- Travel_Planner/Travel_Planner/CloudinaryImageUploadServiceTest.java
- Travel_Planner/Travel_Planner/CommentThreadServiceTest.java
- Travel_Planner/Travel_Planner/CommunityControllerIntegrationTest.java
- Travel_Planner/Travel_Planner/CommunityPostServiceTest.java
- Travel_Planner/Travel_Planner/DataSeederTest.java
- Travel_Planner/Travel_Planner/DestinationConsolidationMigrationRunnerTest.java
- Travel_Planner/Travel_Planner/FavoriteControllerTest.java
- Travel_Planner/Travel_Planner/FriendshipPrivacyServiceTest.java
- Travel_Planner/Travel_Planner/GeographicFilterServiceTest.java
- Travel_Planner/Travel_Planner/HealthControllerTest.java
- Travel_Planner/Travel_Planner/HereGeocodingProviderTest.java
- Travel_Planner/Travel_Planner/ItineraryCloneTest.java
- Travel_Planner/Travel_Planner/ItineraryControllerTest.java
- Travel_Planner/Travel_Planner/ItineraryCrudTest.java
- Travel_Planner/Travel_Planner/ItineraryPlaceTest.java
- Travel_Planner/Travel_Planner/LocationDeduplicationTest.java
- Travel_Planner/Travel_Planner/LocationRankingServiceTest.java
- Travel_Planner/Travel_Planner/LocationSearchAndFilteringTest.java
- Travel_Planner/Travel_Planner/LocationServiceTest.java
- Travel_Planner/Travel_Planner/MessageRequestServiceTest.java
- Travel_Planner/Travel_Planner/MediaCleanupServiceTest.java
- Travel_Planner/Travel_Planner/OpenRouteServiceRoutingProviderTest.java
- Travel_Planner/Travel_Planner/PlaceAdministrativeAreaMigrationRunnerTest.java
- Travel_Planner/Travel_Planner/PlaceAdministrativeAreaServiceTest.java
- Travel_Planner/Travel_Planner/PlaceControllerTest.java
- Travel_Planner/Travel_Planner/PlaceNormalizationServiceTest.java
- Travel_Planner/Travel_Planner/PlaceServiceTest.java
- Travel_Planner/Travel_Planner/PostServiceJpaIntegrationTest.java
- Travel_Planner/Travel_Planner/ProviderFailureAndResilienceTest.java
- Travel_Planner/Travel_Planner/PublicUserServiceTest.java
- Travel_Planner/Travel_Planner/QueryUnderstandingServiceTest.java
- Travel_Planner/Travel_Planner/RatingControllerTest.java
- Travel_Planner/Travel_Planner/RouteServiceTest.java
- Travel_Planner/Travel_Planner/SavedItineraryControllerTest.java
- Travel_Planner/Travel_Planner/security/JwtTokenProviderTest.java
- Travel_Planner/Travel_Planner/TomTomPlacesProviderTest.java
- Travel_Planner/Travel_Planner/TravelPlannerApplicationTests.java
- Travel_Planner/Travel_Planner/UserHandleDatabasePersistenceTest.java
- Travel_Planner/Travel_Planner/UserHandleServiceTest.java

## Notification Core (added 2026-11-26)

- `Travel_Planner/Travel_Planner/NotificationServiceImplTest.java`
- `Travel_Planner/Travel_Planner/NotificationControllerTest.java`
- `Travel_Planner/Travel_Planner/NotificationDatabaseIntegrationTest.java` (JPA/Hibernate schema, repository behavior, HTTP auth/ownership, concurrent dedup and announcement rules)
- `Travel_Planner/Travel_Planner/SocialNotificationServiceImplTest.java` (social events and Admin action mapping)
- `Travel_Planner/Travel_Planner/AdminUserModerationNotificationTest.java` (status transition hook)
- `Travel_Planner/Travel_Planner/CommunityPostServiceTest.java` (post moderation/report service behavior)

Focused command from `backend`: `mvnw.cmd '-Dtest=NotificationServiceImplTest,NotificationControllerTest,NotificationDatabaseIntegrationTest' test`. Test DB is `travel_planner_test`; never point it at the developer DB.
