# 14. Cấu hình, dependency và chạy

## Environment variables (tên only)
Root .env.example lists DB_URL, DB_USERNAME, DB_PASSWORD, DB_TEST_URL; JWT_SECRET/JWT_EXPIRATION_MS; SERVER_PORT; ALLOWED_ORIGINS/ALLOWED_ORIGIN_PATTERNS; APP_SEED_ENABLED; TRUSTED_PROXIES; Cloudinary fields; GEOCODING_PROVIDER plus LocationIQ/HERE/TomTom keys/URLs/flags; ROUTING_PROVIDER/OpenRouteService key/URL/limits; API_BASE_URL; CARTO_API_KEY/MAP_API_KEY. application.properties maps these to Spring config and imports .env. Guide intentionally has no real values.

## Dependency/config files
Backend: pom.xml, Maven wrapper scripts, application.properties, application-prod.properties. Mobile/Web each have pubspec.yaml, pubspec.lock, analysis_options.yaml and platform directories. Root has .env.example and .gitignore. API_BASE_URL and map tile variables are compile-time dart-defines for Flutter.

## Commands from README
Backend from backend: .\mvnw.cmd spring-boot:run; tests .\mvnw.cmd test; health /api/health. Flutter projects run flutter pub get then flutter run. README says Web Chrome on port 8081. Android emulator maps host to 10.0.2.2; physical device needs reachable IP/forwarding. This is instruction, not proof commands pass in current environment.

## Safety checks
Confirm selected Spring profile/DB target, port, and provider config before launch. Run tests against DB_TEST_URL/test profile, not production. UserHandleBackfillRunner can issue schema DDL. No build/test/database/provider calls were run for this guide.
