# Phase 3.2.1 — Artifact 04: Ambiguous Places Audit & Review

## 1. Executive Summary & Objective

In Phase 3.2, the automated linking pipeline successfully linked **20 out of 24** places to canonical administrative areas. Exactly **4 places** (IDs 11, 12, 20, 22) remained unlinked (`administrative_area_id = NULL`) because the Resolver classified them as `AMBIGUOUS` with `eligibleForAutoLink = false`.

This audit rigorously evaluates each of the 4 places to establish:
1. The candidates identified during address and landmark tokenization.
2. The root cause of the score tie or conflict leading to `AMBIGUOUS`.
3. The geographic containment of the actual landmark relative to administrative boundaries.
4. Definitive recommendations on whether each place should be linked or remain `NULL`.

---

## 2. In-Depth Evaluation of the 4 Ambiguous Places

### 2.1 Place 11: Bà Nà Hills & Cầu Vàng
- **Place ID:** `11`
- **Stored Address:** `"Hòa Ninh, Hòa Vang, TP. Đà Nẵng"`
- **Geographic Coordinates:** `(15.9988500, 107.9961600)`
- **Candidate Administrative Areas:**
  - Candidate 1: `20308` — `Xã Bà Nà` (Parent: Đà Nẵng) — Matched landmark token `"Bà Nà"` in Place name.
  - Candidate 2: `20320` — `Xã Hoà Vang` (Parent: Đà Nẵng) — Matched address tokens `"Hòa Ninh, Hòa Vang"`.
- **Reason for Ambiguity:**
  Both candidates scored equally high in the Resolver's weighted scoring matrix: Candidate 1 scored on the distinctive tourist landmark name, while Candidate 2 scored on the formal district/commune token in the address string. Neither candidate exceeded the other by the requisite score margin threshold.
- **Geographical & Cadastral Containment:**
  Physically, the entrance cable car station and lower facilities of Bà Nà Hills are located in thôn An Sơn, xã Hòa Ninh, huyện Hòa Vang. However, the upper mountain resort and Ba Na Nature Reserve have historically crossed boundaries into what is represented as `Xã Bà Nà` in tourist and regional planning records.
- **Recommendation:**
  **REMAIN NULL.**
  Auto-linking must remain inhibited. An administrative operator can manually link this place to either `20308` or `20320` via `POST /api/admin/places/11/administrative-area/link` after the municipal master plan confirms the exact post-2025 boundary assignment.

---

### 2.2 Place 12: Bán Đảo Sơn Trà & Chùa Linh Ứng
- **Place ID:** `12`
- **Stored Address:** `"Hoàng Sa, Thọ Quang, Sơn Trà, TP. Đà Nẵng"`
- **Geographic Coordinates:** `(16.1001000, 108.2778000)`
- **Candidate Administrative Areas:**
  - Candidate 1: `20333` — `Đặc khu Hoàng Sa` (Parent: Đà Nẵng, `SPECIAL_ZONE`) — Matched street name token `"Hoàng Sa"`.
  - Candidate 2: `20263` — `Phường Sơn Trà` (Parent: Đà Nẵng, `WARD`) — Matched district token `"Sơn Trà"`.
- **Reason for Ambiguity:**
  The address string starts with `"Hoàng Sa"`, referring to the coastal boulevard named after the Hoàng Sa archipelago (*Đường Hoàng Sa*). The resolver's token extractor matched `"Hoàng Sa"` to `20333 Đặc khu Hoàng Sa`, while simultaneously matching `"Sơn Trà"` to `20263 Phường Sơn Trà`.
- **Geographical & Cadastral Containment:**
  Chùa Linh Ứng - Bãi Bụt is located on the Sơn Trà peninsula on mainland Vietnam (`16.1001° N, 108.2778° E`), physically situated in Thọ Quang ward, Sơn Trà district. It is over 300 kilometers away from the Paracel Islands (`Đặc khu Hoàng Sa`).
- **Critical Safety Observation:**
  The Resolver's conservative ambiguity detection **prevented a catastrophic false positive**, namely auto-linking a mainland peninsula pagoda to the offshore Paracel Special Zone!
- **Recommendation:**
  **REMAIN NULL FOR AUTO-LINKING.**
  Under manual administrator discretion, this place can be safely linked to `20263 Phường Sơn Trà` (or a dedicated Thọ Quang ward code if created in future catalogs). Automated linking must strictly remain disabled.

---

### 2.3 Place 20: Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng)
- **Place ID:** `20`
- **Stored Address:** `"Phong Nha, Bố Trạch, Quảng Bình"`
- **Geographic Coordinates:** `(17.5890000, 106.2830000)`
- **Candidate Administrative Areas:**
  - Candidate 1: `19138` — `Xã Phong Nha` (Parent: Quảng Bình)
  - Candidate 2: `19141` — `Xã Bố Trạch` (Parent: Quảng Bình)
- **Reason for Ambiguity:**
  The address contains both `"Phong Nha"` (township/commune) and `"Bố Trạch"` (district/commune). Both administrative areas exist in the catalog as Tier B verified entities under Quảng Bình province, and both matched with equal score weights.
- **Geographical & Cadastral Containment:**
  The national park / nature reserve spans hundreds of square kilometers across multiple communes in Bố Trạch district, including Phong Nha, Tân Trạch, Thượng Trạch, and Phúc Trạch. Assigning the entire reserve to a single commune without cadastral coordinates is inherently arbitrary.
- **Recommendation:**
  **REMAIN NULL.**
  Preserving `administrative_area_id = NULL` is correct for expansive national parks and multi-commune conservation zones until multi-polygon spatial indexing is supported in future phases.

---

### 2.4 Place 22: Chợ Đêm Sơn Trà
- **Place ID:** `22`
- **Stored Address:** `"Mai Hắc Đế, An Hải Trung, Sơn Trà, TP. Đà Nẵng"`
- **Geographic Coordinates:** `(16.0615000, 108.2320000)`
- **Candidate Administrative Areas:**
  - Candidate 1: `20275` — `Phường An Hải` (Parent: Đà Nẵng) — Matched ward token `"An Hải Trung"`.
  - Candidate 2: `20263` — `Phường Sơn Trà` (Parent: Đà Nẵng) — Matched district token `"Sơn Trà"`.
- **Reason for Ambiguity:**
  Under the 2024–2025 ward rearrangement in Đà Nẵng, several wards in Sơn Trà district (such as An Hải Đông, An Hải Tây, An Hải Trung) were rearranged and consolidated. The catalog contains both `20275 Phường An Hải` and `20263 Phường Sơn Trà`.
- **Geographical & Cadastral Containment:**
  The night market is situated at the foot of the Dragon Bridge on Mai Hắc Đế street, intersecting the boundary zone of An Hải ward.
- **Recommendation:**
  **REMAIN NULL.**
  Leaving this place unlinked until verified by local municipal administration ensures that tourists receive accurate administrative boundary data without premature heuristics.

---

## 3. Summary of Ambiguous Places Status

| Place ID | Name | Stored Address | Coordinates | Candidates | Final Audit Recommendation |
| :---: | :--- | :--- | :---: | :--- | :--- |
| **11** | Bà Nà Hills & Cầu Vàng | Hòa Ninh, Hòa Vang, Đà Nẵng | (15.998, 107.996) | `20308` (Bà Nà), `20320` (Hoà Vang) | **Maintain NULL** (Ambiguous) |
| **12** | Bán Đảo Sơn Trà & Chùa Linh Ứng | Hoàng Sa, Thọ Quang, Sơn Trà, Đà Nẵng | (16.100, 108.277) | `20333` (Hoàng Sa), `20263` (Sơn Trà) | **Maintain NULL** (Crucial False Positive Prevention) |
| **20** | Khu bảo tồn thiên nhiên Đang Cải Tạo | Phong Nha, Bố Trạch, Quảng Bình | (17.589, 106.283) | `19138` (Phong Nha), `19141` (Bố Trạch) | **Maintain NULL** (Multi-commune Reserve) |
| **22** | Chợ Đêm Sơn Trà | Mai Hắc Đế, An Hải Trung, Sơn Trà, Đà Nẵng | (16.061, 108.232) | `20275` (An Hải), `20263` (Sơn Trà) | **Maintain NULL** (Ward Consolidation) |

The system's conservative behavior in leaving these 4 places unlinked is verified as optimal and compliant with all project safety guidelines.

