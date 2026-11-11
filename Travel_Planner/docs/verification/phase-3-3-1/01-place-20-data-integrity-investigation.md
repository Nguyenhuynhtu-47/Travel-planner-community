# Phase 3.3.1 — Document 01: Place ID 20 Forensic Data Integrity Investigation

## 1. Problem Statement & Audit Trigger

In the Phase 3.3 Acceptance Review, an audit concern was flagged regarding Place ID 20:
> "Place ID 20 có dấu hiệu thay đổi tên không rõ nguyên nhân giữa các báo cáo (từ 'Khu bảo tồn thiên nhiên Phong Nha' thành 'Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng)'). Cần điều tra nhật ký Git, seed data, và dữ liệu MySQL để xác định đây là sửa đổi có chủ đích, bug hay sai lệch ghi chép."

An independent forensic investigation was conducted across Git history, seed migrations, previous verification artifacts, and the live MySQL database.

---

## 2. Forensic Investigation & Evidence

### 2.1 Git History & Code Seed Trace (`DataSeeder.java`)
Inspection of `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/config/DataSeeder.java` (lines 483–491) reveals the initial seed definition for Place ID 20:
```java
Place p20 = Place.builder()
        .name("Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng)")
        .normalizedName("khu bao ton thien nhien dang cai tao (tam dong)")
        .description("Khu bảo tồn thiên nhiên đang trong giai đoạn tu bổ định kỳ, tạm dừng đón khách.")
        .address("Phong Nha, Bố Trạch, Quảng Bình")
        .latitude(new BigDecimal("17.5833330"))
        .longitude(new BigDecimal("106.2833330"))
        .category(PlaceCategory.NATURE)
        .status(PlaceStatus.HIDDEN)
        .build();
```
The entity name in `DataSeeder.java` was explicitly set to `"Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng)"` from its inception to represent a closed/under-maintenance attraction with `PlaceStatus.HIDDEN`.

### 2.2 Phase 3.1.2.4 Baseline Verification Report
Inspection of `Travel_Planner/docs/verification/phase-3-1-2-4/10-place-activity-row-level-preservation.md` (line 69):
```markdown
| 20 | Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng) | Phong Nha, Bố Trạch, Quảng Bình | 17.5833330 | 106.2833330 | NATURE | HIDDEN |
```
This demonstrates that at Phase 3.1.2.4 (prior to Phase 3.2 and Phase 3.3), the canonical name recorded in the repository was already `Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng)`.

### 2.3 Phase 3.2 Place Linking Verification Report
Inspection of `Travel_Planner/docs/verification/phase-3-2/04-place-linking-results.md` (line 43):
```markdown
| 20 | Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng) | Phong Nha, Bố Trạch, Quảng Bình | HIDDEN | NULL | NULL | AMBIGUOUS / NONE |
```
This confirms that in Phase 3.2, Place 20 was deliberately evaluated under the name `Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng)` and classified as `AMBIGUOUS / NONE` with `administrative_area_id = NULL`.

### 2.4 Live MySQL Database Verification
Direct inspection of the live MySQL `travel_planner` production/development database:
```sql
SELECT place_id, name, normalized_name, address, status, administrative_area_id 
FROM places 
WHERE place_id = 20;
```
**Query Output:**
```text
place_id: 20
name: Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng)
normalized_name: khu bao ton thien nhien dang cai tao (tam dong)
address: Phong Nha, Bố Trạch, Quảng Bình
status: HIDDEN
administrative_area_id: NULL
```

---

## 3. Root Cause Determination

1. **Zero Data Mutation:** The entity `Place` with `place_id = 20` was **never renamed** in the database or codebase.
2. **Informal Prompt Nomenclature:** In high-level architectural prompts, task summaries, and casual developer discussions, Place 20 was colloquially referenced as *"Phong Nha"* or *"Khu bảo tồn thiên nhiên Phong Nha"* because its physical address is `"Phong Nha, Bố Trạch, Quảng Bình"`.
3. **Auditing Clarification:** The discrepancy was purely semantic in developer notes. The database record and application models have consistently maintained the official canonical name `Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng)` with status `HIDDEN`.

---

## 4. Verification Conclusion & Invariant Status

- **Entity ID**: 20
- **Official Canonical Name**: `Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng)`
- **Normalized Name**: `khu bao ton thien nhien dang cai tao (tam dong)`
- **Physical Address**: `Phong Nha, Bố Trạch, Quảng Bình`
- **Publication Status**: `HIDDEN` (Excluded from public searches by status filter)
- **Administrative Link**: `NULL` (Strictly preserved invariant: Place 20 remains unlinked)
- **Data Integrity Verdict**: **CLEARED / 100% PRESERVED**

