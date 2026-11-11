# Phase 3.2.2 — Artifact 03: Admin Manual Linking API Contract Audit

## 1. Executive Summary & Objective

During Phase 3.2 architectural discussions, the administrative linking endpoint was occasionally referenced in documentation under a RESTful resource-update convention:
`PUT /api/admin/places/{id}/administrative-area`

However, the production backend codebase implements command-oriented RPC endpoints under `/api/admin/places`. This document provides a definitive, byte-level audit of the actual controller implementation, resolving the route discrepancy and specifying the exact API contract.

---

## 2. Controller Architecture & Route Resolution

### 2.1 Route Comparison: Specification vs. Production Code

| Aspect | Early Conceptual Reference | Actual Production Implementation (`AdminPlaceAdministrativeAreaController.java`) |
| :--- | :--- | :--- |
| **Route Path** | `/api/admin/places/{id}/administrative-area` | `/api/admin/places/{id}/administrative-area/link` |
| **HTTP Verb** | `PUT` | `POST` |
| **Semantic Intent** | Idempotent resource replacement | Explicit intent-driven command (linking action with validation and audit justification) |
| **Production Status** | **NOT IMPLEMENTED** (Does not exist in bytecode) | **ACTIVE & VERIFIED** (Fully implemented, tested, and active) |

### 2.2 Rationale for the Production Contract
1. **Explicit Semantic Clarity:** In RESTful domain design, updating a sub-resource relationship that involves complex domain validation (such as trust tiers, quarantine checks, and homonym elimination) is conventionally modeled via explicit sub-resource action paths (`/link`, `/resolve`, `/preview`).
2. **Distinct Action Separation:**
   - Explicit manual assignment by an operator: `POST .../link`
   - Automated resolver invocation for a single entity: `POST .../resolve`
   - Read-only simulation without database mutation: `POST .../preview`
   - Complete disassociation: `DELETE ...`

---

## 3. Comprehensive Admin Controller Contract Specification

Controller Class: `AdminPlaceAdministrativeAreaController`  
Base Mapping: `@RequestMapping("/api/admin/places")`  
Security: `@PreAuthorize("hasRole('ADMIN')")` at class level.

### 3.1 Endpoint 1: Manual Link to Administrative Area
- **Route:** `POST /api/admin/places/{id}/administrative-area/link`
- **Description:** Manually associates a Place with a specified administrative area code. Enforces strict legal quarantine checks.
- **Request Headers:**
  - `Authorization: Bearer <ADMIN_JWT_TOKEN>`
  - `Content-Type: application/json`
- **Path Parameter:**
  - `id` (`Long`): Unique identifier of the target `Place` (`place_id`).
- **Request Body (`ManualLinkAdministrativeAreaRequest`):**
  ```json
  {
    "administrativeAreaCode": "00070",
    "reason": "Admin verified physical location in Hoan Kiem ward"
  }
  ```
  - `administrativeAreaCode` (`String`, required, `@NotBlank`): 5-digit administrative area code.
  - `reason` (`String`, optional): Administrative rationale for manual assignment.
- **Success Response:** `200 OK`
  - Body: `PlaceDetailResponse` containing updated `placeId`, `name`, `address`, and embedded `administrativeArea` object.
- **Error Responses:**
  - `400 Bad Request`: When `administrativeAreaCode` is blank or belongs to the 12 quarantined Northern Bắc Ninh codes (`07294..09496`).
  - `401 Unauthorized`: When no valid JWT authentication header is provided.
  - `403 Forbidden`: When the authenticated user lacks `ROLE_ADMIN`.
  - `404 Not Found`: When `placeId` does not exist, or `administrativeAreaCode` does not exist in `administrative_areas`.

### 3.2 Endpoint 2: Unlink Administrative Area
- **Route:** `DELETE /api/admin/places/{id}/administrative-area`
- **Description:** Removes the administrative area foreign key from the Place (`places.administrative_area_id = NULL`).
- **Path Parameter:** `id` (`Long`): Place ID.
- **Success Response:** `200 OK` with `PlaceDetailResponse` (`administrativeArea: null`).
- **Error Responses:** `401 Unauthorized`, `403 Forbidden`, `404 Not Found`.

### 3.3 Endpoint 3: Resolve & Link Automatically
- **Route:** `POST /api/admin/places/{id}/administrative-area/resolve`
- **Query Parameter:** `overwriteExisting` (`boolean`, optional, default: `false`).
- **Description:** Executes `AdministrativeAreaResolver`. If resolution confidence satisfies auto-link criteria (`HIGH_CONFIDENCE` or `MEDIUM_CONFIDENCE`) and the unit is not quarantined, updates `places.administrative_area_id`.
- **Success Response:** `200 OK` with `PlaceResolutionResultResponse`.

### 3.4 Endpoint 4: Preview Resolution (Dry Run)
- **Route:** `POST /api/admin/places/{id}/administrative-area/preview`
- **Description:** Read-only simulation. Runs the resolver and returns candidates and confidence classification without persisting changes.
- **Success Response:** `200 OK` with `PlaceResolutionResultResponse`.

### 3.5 Endpoint 5: Batch Resolve & Link
- **Route:** `POST /api/admin/places/administrative-area/batch-resolve`
- **Request Body (`BatchResolvePlacesRequest`):**
  ```json
  {
    "placeIds": [1, 2, 3],
    "dryRun": false,
    "overwriteExisting": false
  }
  ```
- **Success Response:** `200 OK` with `BatchLinkingReportResponse` summarizing total examined, linked, skipped, quarantined, and ambiguous counts.

---

## 4. Contract Conformance Summary

1. The actual API contract is confirmed as `POST /api/admin/places/{id}/administrative-area/link`.
2. Any documentation referencing `PUT /api/admin/places/{id}/administrative-area` is clarified as historical conceptual notation superseded by the production RPC design.
3. No new endpoints were introduced; the existing verified implementation is preserved without code mutation.

