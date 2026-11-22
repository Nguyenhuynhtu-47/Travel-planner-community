# Backend Admin Seed Duplicate Handle Startup Fix Report

**Date:** 2026-11-23  
**Status:** Resolved & Verified  
**Branch:** `feature/admin-moderation-integration`  

---

## 1. Executive Summary

During backend initialization with development seed data enabled (`app.seed.enabled=true`), Spring Boot crashed on startup with a fatal `DataIntegrityViolationException`:

```
org.springframework.dao.DataIntegrityViolationException: 
Duplicate entry 'nam.admin' for key 'users.uk_users_handle'
```

This report documents the root-cause analysis, the architecture of the idempotent seeding engine implemented in `DataSeeder.java`, distributed locking protection for multi-instance deployments, and comprehensive automated and live database verification confirming zero data loss and flawless startup.

---

## 2. Root Cause Analysis

### 2.1 Database Schema & Pre-existing State
In MySQL database `travel_planner`, table `users` contains unique constraints on three columns:
- `uk_users_username` on `username`
- `uk_users_email` on `email`
- `uk_users_handle` on `handle`

An administrative account already existed in the database:
- `user_id`: `578`
- `username`: `"admin"`
- `handle`: `"nam.admin"`
- `email`: `"admin@gmail.com"`
- `role`: `ADMIN`
- `status`: `ACTIVE`

### 2.2 Flawed Seeder Lookup Logic
In `DataSeeder.java`, the administrative seed definition was specified as:
- `username`: `"admin_master"`
- `handle`: `"nam.admin"`
- `email`: `"admin@travelplanner.local"`
- `role`: `ADMIN`

Prior to this fix, `DataSeeder.seedUsers()` checked for account existence using only:
```java
userRepository.findByUsername(def.getUsername())
    .orElseGet(() -> userRepository.findByEmail(def.getEmail()).orElse(null))
```

This check exhibited three critical flaws:
1. **Handle Ignored:** It completely ignored `def.getHandle()`.
2. **Admin Alias Ignored:** It did not account for existing admin accounts with alternate usernames (e.g., `"admin"` vs `"admin_master"`).
3. **Unchecked INSERT:** Because neither username `"admin_master"` nor email `"admin@travelplanner.local"` matched User 578, the method concluded that the account was absent and called `userRepository.save(def)`.

When Hibernate executed `INSERT INTO users (handle, username, email, ...) VALUES ('nam.admin', 'admin_master', ...)`, MySQL rejected the statement with `Duplicate entry 'nam.admin' for key 'users.uk_users_handle'`, crashing the application context during startup.

---

## 3. Solution Architecture & Implementation

### 3.1 Idempotent Account Resolution (`resolveOrCreateSeedUser`)
In `DataSeeder.java`, user resolution was re-architected into `resolveOrCreateSeedUser(User def)`:

1. **Pre-check All Unique Constraints:**
   Queries existing records across all three unique constraints:
   - `userRepository.findByUsername(def.getUsername())`
   - `userRepository.findByEmail(def.getEmail())`
   - `userRepository.findByHandle(def.getHandle())`

2. **Admin Alias Awareness:**
   If `def.getRole() == Role.ADMIN`:
   - If `def.getUsername()` is `"admin_master"`, checks for pre-existing `"admin"`.
   - If `def.getUsername()` is `"admin"`, checks for pre-existing `"admin_master"`.

3. **Deduplication:**
   Matches are collected into a `Map<Integer, User> matchedUsers` keyed by `userId` to eliminate redundant references when multiple fields belong to the same existing user.

4. **Three Execution Branches:**
   - **Case 1: Fresh Database (0 matches):**
     Saves the seed user via `userRepository.save(def)`.
   - **Case 2: Consistent Pre-existence (1 match):**
     Safely reuses the existing user record without modification. **No password, role, profile, or status is overwritten.**
   - **Case 3: Inconsistent State (>1 matches across username/email/handle):**
     Logs a clear warning identifying the conflicting user IDs. Safely skips insertion/mutation and preserves existing database records without throwing an exception or violating constraints.

5. **Bidirectional In-Memory Mapping:**
   `map.put(def.getUsername(), resolved)` and if `resolved.getUsername() != def.getUsername()`, also maps `map.put(resolved.getUsername(), resolved)`. This guarantees downstream seeder dependencies (places, itineraries, comments) resolve their foreign keys cleanly regardless of which admin alias is present.

### 3.2 Distributed Advisory Locking for Concurrency
To safeguard against race conditions when multiple application instances start concurrently:
- Implemented `acquireDistributedLock()` and `releaseDistributedLock()` in `DataSeeder.java` utilizing MySQL `GET_LOCK('travel_planner_data_seed_lock', 15)`.
- The lock is acquired on a dedicated JDBC connection before seeding and released in a `try ... finally` block.
- Graceful fallback: If locking fails or runs on a database not supporting `GET_LOCK`, seeding proceeds with a warning rather than blocking execution.

---

## 4. Testing & Verification

### 4.1 Automated Test Suite
Created `AdminSeedIdempotencyTest.java` verifying 4 distinct scenarios:
1. **Scenario 1 (Fresh Database):** Correctly creates `admin_master` with hashed password and `ADMIN` role.
2. **Scenario 2 (Existing `nam.admin` / `admin`):** Correctly detects existing account, does NOT insert duplicate, preserves user ID 578, role, and password.
3. **Scenario 3 (Repeated Executions):** Calling `dataSeeder.seedData()` consecutively results in identical user counts (0 duplicate users created).
4. **Scenario 4 (Inconsistent Constraints):** Conflicting username/handle records across different users are detected safely without crashing.

### 4.2 Test Suite Cleanup Enhancement
Fixed foreign key constraint cleanup in `DataSeederTest.java` and `AdminSeedIdempotencyTest.java`:
- Disabled session foreign key checks (`SET FOREIGN_KEY_CHECKS = 0`) before cleaning child tables (`post_reports`, `post_media`, `post_comments`, `post_likes`, `posts`, `media_assets`), then re-enabled (`SET FOREIGN_KEY_CHECKS = 1`), preventing foreign key errors caused by cross-test data.

### 4.3 Test Results
- **`AdminSeedIdempotencyTest` & `DataSeederTest`:**
  - Command: `mvn test -Dtest="AdminSeedIdempotencyTest,DataSeederTest"`
  - Result: **12 tests run, 0 failures, 0 errors (BUILD SUCCESS)**
- **`PostServiceJpaIntegrationTest`:**
  - Command: `mvn test -Dtest="PostServiceJpaIntegrationTest"`
  - Result: **2 tests run, 0 failures, 0 errors (BUILD SUCCESS)**

### 4.4 Live Backend & Database Verification
Started Spring Boot against the live MySQL `travel_planner` database with `app.seed.enabled=true`:
- **Startup Log Output:**
  ```
  INFO --- [DataSeeder] Initializing realistic development seed data
  INFO --- [DataSeeder] Seed user 'admin_master' already exists as user ID 578 (username='admin', handle='nam.admin', role=ADMIN). Preserving existing record without modification.
  ...
  INFO --- [DataSeeder] Completed successfully. Summary: SeedResult(...)
  ```
- **Health Check Endpoint:**
  - `GET http://localhost:8080/api/health` returned HTTP 200:
    ```json
    { "status": "UP", "service": "travel-planner-backend" }
    ```
- **User 578 Database Verification:**
  - `SELECT user_id, username, handle, email, role, status FROM travel_planner.users WHERE user_id = 578;`
  - Output: `578 | admin | nam.admin | admin@gmail.com | ADMIN | ACTIVE` (100% preserved).
- **Authentication Endpoint Verification:**
  - `POST http://localhost:8080/api/auth/login` with `{"usernameOrEmail": "admin", "password": "..."}` succeeded and returned a valid signed JWT token containing `role: ADMIN` and `userId: 578`.

---

## 5. Compliance & Deliverables

- **Working Tree:** No existing data deleted; no database tables dropped; no git commits or pushes performed.
- **Reports & Logs:**
  - Detailed Report: `Travel_Planner/docs/plan/18-admin-seed-startup-fix-report.md`
  - Development Log: Updated in `Travel_Planner/docs/ai/09-development-log.md`
