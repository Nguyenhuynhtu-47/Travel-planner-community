# Phase 3.2.2 — Artifact 04: Quarantine Enforcement & Defense-in-Depth Verification

## 1. Executive Summary & Objective

This document verifies the end-to-end execution path and defense-in-depth mechanisms that prevent any quarantined administrative unit (Tier C, Resolution 388/NQ-UBTVQH16) from being linked to a Place or Activity.

The audit evaluates all scenarios outlined in the Phase 3.2.2 specification, tracing requests through the entire stack:
`HTTP Request → Security Filter → Controller → Service → Repository → Database`

---

## 2. Multi-Tier Defense-in-Depth Architecture

```
[Incoming Request]
        │
        ▼
[Spring Security Filter] ─── (Non-admin or unauthenticated) ──► 401 / 403 Blocked
        │ (ROLE_ADMIN verified)
        ▼
[AdminPlaceAdministrativeAreaController] ─── (@Valid DTO check) ──► 400 if Blank
        │
        ▼
[PlaceAdministrativeAreaServiceImpl]
   ├── Barrier 1: Resolver Static Quarantine Set Check
   │              (QUARANTINED_BAC_NINH_CODES) ──────────────► 400 Bad Request
   │
   ├── Barrier 2: Database Area Entity Trust Check
   │              (trust_classification == UNVERIFIED...) ──► 400 Bad Request
   │
   └── Barrier 3: Batch / Auto-Link Resolver Suppression
                  (eligibleForAutoLink = false) ─────────────► Skipped, No DB write
        │
        ▼
[PlaceRepository.save(place)] ───► MySQL (Database Constraint & State Verification)
```

---

## 3. Comprehensive Scenario Verification Matrix

The following matrix documents the verified behavior for all 11 operational scenarios:

| # | Scenario Description | Trigger Entry Point | Verification Mechanism | Actual Execution Result | Pass / Fail |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **1** | Anonymous user invokes link | `POST /api/admin/places/1/administrative-area/link` | `JwtAuthenticationFilter` rejects missing token | **401 Unauthorized** | **PASS** |
| **2** | Authenticated normal user (`ROLE_USER`) | `POST /api/admin/places/1/administrative-area/link` | `@PreAuthorize("hasRole('ADMIN')")` evaluates user authority | **403 Forbidden** | **PASS** |
| **3** | Admin + Verified Tier A area (e.g. `00070`) | `POST /api/admin/places/1/administrative-area/link` | Code looked up, trust tier verified, entity linked and saved | **200 OK** (Place updated) | **PASS** |
| **4** | Admin + Tier B area (`VERIFIED_WITH_LIMITATIONS`) | `POST /api/admin/places/1/administrative-area/link` | Code looked up, valid non-quarantined entity linked | **200 OK** (Place updated) | **PASS** |
| **5** | Admin + Quarantined area (e.g. `07294`) | `POST /api/admin/places/1/administrative-area/link` | `QUARANTINED_BAC_NINH_CODES.contains(code)` triggers exception | **400 Bad Request** (`"cách ly pháp lý"`) | **PASS** |
| **6** | Admin + Non-existent area code (e.g. `99999`) | `POST /api/admin/places/1/administrative-area/link` | `areaRepository.findByCodeWithParent` returns empty Optional | **404 Not Found** (`"Không tìm thấy đơn vị HC"`) | **PASS** |
| **7** | Admin + Non-existent Place ID (e.g. `999999`) | `POST /api/admin/places/999999/administrative-area/link` | `placeRepository.findById` returns empty Optional | **404 Not Found** (`"Không tìm thấy địa điểm"`) | **PASS** |
| **8** | Admin + Ambiguous Place + Verified area | `POST /api/admin/places/11/administrative-area/link` | Place 11 (`NULL`) receives explicit administrative assignment | **200 OK** (Explicit human resolution) | **PASS** |
| **9** | Admin + Place already linked | `POST /api/admin/places/{id}/administrative-area/link` | Manual link explicitly updates target area; `resolve` requires `overwriteExisting=true` | **200 OK** (Controlled overwrite) | **PASS** |
| **10** | Direct Java Service Invocation with Quarantined Code | `PlaceAdministrativeAreaService.linkManually(...)` | Service method validates code before entity association | Throws `BadRequestException` | **PASS** |
| **11** | Batch Resolution / Migration Runner encountering Quarantined Code | `batchResolveAndLink()` or `PlaceAdministrativeAreaMigrationRunner` | `resolve()` returns `eligibleForAutoLink=false`; service bypasses mutation | Record counted as `quarantinedSkipped`; 0 DB writes | **PASS** |

---

## 4. Code Evidence of Quarantine Enforcements

### 4.1 Service-Level Rejection (`PlaceAdministrativeAreaServiceImpl.java`)
```java
// Check 1: Static Code Whitelist / Quarantine Guard
if (AdministrativeAreaResolverImpl.QUARANTINED_BAC_NINH_CODES.contains(code)) {
    log.warn("[QUARANTINE_GUARD] Manual linking rejected for placeId={} to quarantined code {}", placeId, code);
    throw new BadRequestException("Không thể liên kết thủ công với đơn vị hành chính đang bị cách ly pháp lý (NQ 388/NQ-UBTVQH16): " + code);
}

// Check 2: Database Entity Classification Guard
if (area.getTrustClassification() == AdministrativeAreaTrustClassification.UNVERIFIED_AND_QUARANTINED) {
    throw new BadRequestException("Đơn vị hành chính này thuộc diện cách ly pháp lý, không được phép liên kết.");
}
```

### 4.2 Auto-Link Resolution Guard (`PlaceAdministrativeAreaServiceImpl.java`)
```java
if (result.isEligibleForAutoLink() && result.getResolvedArea() != null) {
    String code = result.getResolvedArea().getCode();

    if (AdministrativeAreaResolverImpl.QUARANTINED_BAC_NINH_CODES.contains(code)) {
        log.warn("[QUARANTINE_GUARD] Refusing to link placeId={} to quarantined code {}", placeId, code);
        result.setEligibleForAutoLink(false);
        result.setResolvedArea(null);
        result.setConfidence(ConfidenceClassification.UNVERIFIED);
        return result;
    }
    // ...
}
```

---

## 5. Audit Logging & System Limitations

### 5.1 Current Audit Capabilities
1. **SLF4J Structured Logging:** Every administrative linking or unlinking operation emits an audit log at `INFO` level:
   `log.info("Manually linked Place {} ({}) -> AdministrativeArea {} ({})", place.getPlaceId(), place.getName(), area.getCode(), area.getName());`
2. **Entity Timestamps:** The `places` table maintains an `updated_at` column (`datetime(6)`) which is automatically updated upon JPA commit.

### 5.2 Explicit Limitation
The application **does not currently maintain a dedicated database audit log table** (e.g., `place_administrative_area_audit_log` storing `admin_user_id`, `old_area_id`, `new_area_id`, `reason_text`, `ip_address`). In accordance with Phase 3.2.2 safety rules, no new audit subsystem or database migration is introduced at this time; this is documented as an accepted architectural limitation.

