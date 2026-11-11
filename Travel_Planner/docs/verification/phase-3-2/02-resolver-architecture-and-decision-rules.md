# Phase 3.2 — Administrative Area Resolver Architecture & Decision Rules
**Target Snapshot:** 2026-09-20  
**Phase:** 3.2 — Place–Administrative Area Linking & Resolution  
**Component:** `AdministrativeAreaResolver` / `AdministrativeAreaResolverImpl`  
**Execution Date:** 2026-11-11

---

## 1. Architectural Overview

The `AdministrativeAreaResolver` provides deterministic, high-integrity resolution between unstructured destination records (`Place`) and canonical administrative units (`AdministrativeArea`).

It operates through a strict multi-tier hierarchy:
```
[Place Input: Name, Address, Coordinates, CandidateCode]
       │
       ▼
 1. Geographic Bounds Validation ([8.0, 24.0] Lat, [102.0, 110.0] Lon)
       │
       ▼
 2. Priority 1: Exact Administrative Code Match
       ├── If Code in Quarantined List -> REJECT immediately (UNVERIFIED, autoLink=false)
       └── If Code Valid -> Link with HIGH/MEDIUM CONFIDENCE
       │
       ▼ (if no candidate code)
 3. Priority 2: Structured Address Decomposition
       ├── Detect Province from Address (ordered descending by length; short tokens require word boundaries)
       ├── Fallback: Detect Province from Place Name
       │
       ├── Check Quarantined Bắc Ninh Match by name in Province 24 -> REJECT immediately
       │
       ├── Search Active Communes within Province:
       │     ├── 1 Match -> Link (STRUCTURED_COMMUNE_MATCH)
       │     ├── > 1 Matches -> Apply Disambiguation Rules:
       │     │     ├── Rule 1: Province Homonym Elimination (e.g. drop Phường Lào Cai when Phường Sa Pa matches)
       │     │     ├── Rule 2: Compound Specificity Advantage (length > second + 3)
       │     │     └── If still ambiguous -> AMBIGUOUS (autoLink=false, candidate list attached)
       │     └── 0 Matches -> Fallback to Province Unit (PROVINCE_LEVEL_FALLBACK, MEDIUM_CONFIDENCE)
       │
       ▼ (if no province detected)
 4. Priority 3: Fallback / No Match
       └── Return NO_MATCH (eligibleForAutoLink=false)
```

---

## 2. Confidence Classification Levels

The resolver assigns one of 6 standardized confidence levels:

| Confidence Classification | Eligible for Auto-Link | Description & Criteria |
| :--- | :---: | :--- |
| `HIGH_CONFIDENCE` | **Yes** | Exact code match or structured address match resolving to Tier A (`VERIFIED_AND_TRUSTED`) unit. |
| `MEDIUM_CONFIDENCE` | **Yes** | Exact code match or structured address match resolving to Tier B (`VERIFIED_WITH_LIMITATIONS`) unit, or provincial fallback. |
| `LOW_CONFIDENCE` | No | Partial name similarity or ambiguous sub-units requiring human review. |
| `AMBIGUOUS` | No | Multiple candidate communes of equal specificity detected (e.g. Bà Nà vs Hòa Vang; Phong Nha vs Bố Trạch). Candidates attached. |
| `UNVERIFIED` | **STRICTLY NO** | Matched unit belongs to the 12 quarantined Bắc Ninh records under Resolution 388/NQ-UBTVQH16. Link rejected. |
| `NO_MATCH` | No | Address and name contain no identifiable administrative entities within Vietnam territory. |

---

## 3. Disambiguation Rules

### 3.1 Province Homonym Elimination
In cases where a place address mentions both the province and a specific district/town (e.g. `Sa Pa, Lào Cai`), searching communes within province `15` matches both `02647 Phường Lào Cai` and `03006 Phường Sa Pa`. Because `Lào Cai` is the homonym of the province itself, the resolver discards the provincial homonym in favor of the distinct local subdivision (`Phường Sa Pa`).

### 3.2 Compound Commune Prioritization
When an address contains compound names (e.g. `58 Quốc Tử Giám, Đống Đa, Hà Nội`), matching returns both `00226 Phường Văn Miếu - Quốc Tử Giám` and historical/broader district tokens. The compound ward name has significantly greater length specificity (`length > second + 3`) and is resolved unambiguously.

### 3.3 Safe Quarantine Rejection
Any candidate code or text matching any of the 12 quarantined Bắc Ninh records immediately terminates the resolution pipeline:
- `confidence`: `UNVERIFIED`
- `resolvedArea`: `null`
- `eligibleForAutoLink`: `false`
- `matchMethod`: `QUARANTINED_BAC_NINH_MATCH` or `QUARANTINED_COMMUNE_REJECTED`
- Logged at `WARN` level with tag `[QUARANTINE_GUARD]`.

### 3.4 Spatial Coordinate Bounding Box
Validates all coordinates against Vietnam territorial bounds:
- Latitude: `[8.0, 24.0]`
- Longitude: `[102.0, 110.0]`
Out-of-bounds coordinates generate an explicit warning flag on the resolution response without halting textual resolution.

