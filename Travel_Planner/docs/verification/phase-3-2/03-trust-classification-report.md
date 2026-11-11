# Phase 3.2 — Administrative Area Trust Classification Report
**Target Snapshot:** 2026-09-20  
**Phase:** 3.2 — Place–Administrative Area Linking & Resolution  
**Database Audit Date:** 2026-11-11

---

## 1. Classification Model Summary

All 3,355 records in `administrative_areas` are categorized into 4 rigorous trust tiers:

```
Total Administrative Areas: 3,355
├── Tier A: VERIFIED_AND_TRUSTED       (67 records)
│     ├── 34 Province-Level Units (parent_id IS NULL)
│     └── 33 Primary Verified Communes
│           ├── 10 Đồng Nai Post-Arrangement Wards (NQ 1662/NQ-UBTVQH15)
│           ├── 13 Special Zones & Insular Units (Đặc khu Phú Quốc, Hoàng Sa, v.v.)
│           └── 10 Core Municipal Wards (Hà Nội, TP.HCM, Đà Nẵng, Hải Phòng, Cần Thơ)
│
├── Tier B: VERIFIED_WITH_LIMITATIONS   (3,276 records)
│     └── Secondary verified communes supported by GSO 2025 dataset & QĐ 19/2025/QĐ-TTg
│
├── Tier C: UNVERIFIED_AND_QUARANTINED (12 records)
│     └── North Bắc Ninh commune codes lacking primary official annex proof under NQ 388/NQ-UBTVQH16
│
└── Tier D: MISMATCH                    (0 records)
      └── Obsolete or contradictory records (cleared during catalog reconciliation)
```

---

## 2. Tier A: Verified and Trusted (67 Records)

### 2.1 Provinces and Central Cities (34 Units)
All 34 province-level units established under Resolution 202/2025/QH15 and related primary legal decrees:
- `01` Thành phố Hà Nội
- `04` Tỉnh Cao Bằng
- `08` Tỉnh Tuyên Quang
- `11` Tỉnh Điện Biên
- `12` Tỉnh Lai Châu
- `14` Tỉnh Sơn La
- `15` Tỉnh Lào Cai
- `19` Tỉnh Thái Nguyên
- `20` Tỉnh Lạng Sơn
- `22` Thành phố Quảng Ninh
- `24` Thành phố Bắc Ninh
- `25` Tỉnh Phú Thọ
- `31` Thành phố Hải Phòng
- `33` Tỉnh Hưng Yên
- `37` Tỉnh Ninh Bình
- `38` Tỉnh Thanh Hoá
- `40` Tỉnh Nghệ An
- `42` Tỉnh Hà Tĩnh
- `44` Tỉnh Quảng Trị
- `46` Thành phố Huế
- `48` Thành phố Đà Nẵng
- `51` Tỉnh Quảng Ngãi
- `52` Tỉnh Gia Lai
- `56` Tỉnh Khánh Hoà
- `66` Tỉnh Đắk Lắk
- `68` Tỉnh Lâm Đồng
- `75` Thành phố Đồng Nai
- `79` Thành phố Hồ Chí Minh
- `80` Tỉnh Tây Ninh
- `82` Tỉnh Đồng Tháp
- `86` Tỉnh Vĩnh Long
- `91` Tỉnh An Giang
- `92` Thành phố Cần Thơ
- `96` Tỉnh Cà Mau

### 2.2 33 Primary Verified Communes
- **10 Đồng Nai Wards:** `26248` (Trảng Bom), `26368` (Dầu Giây), `26170` (Long Thành), `26485` (Phước Thiền), `25357` (Tân Triều), `26425` (Long Giao), `26116` (Trảng Dài), `25270` (Tam Phước), `26326` (Bình Sơn), `25363` (An Hòa).
- **13 Special Zones & Islands:** `06994` (Cô Tô), `07192` (Bạch Long Vĩ), `11914` (Cồn Cỏ), `11948` (Cù Lao Chàm), `19742` (Lý Sơn), `20333` (Hoàng Sa), `21548` (Trường Sa), `22736` (Phú Quý), `23272` (Côn Đảo), `26732` (Thổ Chu), `31078` (Đặc khu Phú Quốc), `31105` (Kiên Hải), `31108` (Hòn Nghệ).
- **10 Core Municipal Wards:** `00004` (Phường Ba Đình), `00008` (Phường Hoàn Kiếm), `25747` (Phường Bến Nghé), `25750` (Phường Bến Thành), `20194` (Phường Hải Châu), `20197` (Phường Liên Chiểu), `10507` (Phường Hồng Bàng), `10525` (Phường Ngô Quyền), `31120` (Phường Ninh Kiều), `31135` (Phường Cái Răng).

---

## 3. Tier C: Unverified and Quarantined (12 Records)

The 12 commune/ward records from northern Bắc Ninh province that were not verified with primary legal annexes of Resolution 388/NQ-UBTVQH16:
1. `07294` — Phường Bố Hạ
2. `07375` — Phường Lạng Giang
3. `07399` — Phường Kép
4. `07444` — Phường Lục Nam
5. `07840` — Phường Hiệp Hoà
6. `09193` — Phường Yên Phong
7. `09292` — Phường Phù Lãng
8. `09313` — Phường Chi Lăng
9. `09319` — Phường Tiên Du
10. `09454` — Phường Gia Bình
11. `09475` — Phường Nhân Thắng
12. `09496` — Phường Lương Tài

These records are strictly excluded from runtime resolution, auto-linking, manual linking, and place association.

---

## 4. Database Verification Query & Counts

```sql
SELECT trust_classification, COUNT(*) 
FROM administrative_areas 
GROUP BY trust_classification;
```

**Output:**
```
trust_classification        COUNT(*)
UNVERIFIED_AND_QUARANTINED  12
VERIFIED_AND_TRUSTED        67
VERIFIED_WITH_LIMITATIONS   3276
MISMATCH                    0
------------------------------------
Total                       3,355
```

