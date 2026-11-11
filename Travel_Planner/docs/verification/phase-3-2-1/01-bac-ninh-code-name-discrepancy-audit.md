# Phase 3.2.1 — Artifact 01: Bắc Ninh Code–Name Discrepancy Audit

## 1. Executive Summary & Objective

During the review of Phase 3.2 deliverables, an apparent inconsistency was flagged regarding the 12 administrative units quarantined under Tier C (Northern Bắc Ninh units under Resolution 388/NQ-UBTVQH16):
- In the **Phase 3.1.2.4.1 report**, these 12 codes (`07294`, `07375`, `07399`, `07444`, `07840`, `09193`, `09292`, `09313`, `09319`, `09454`, `09475`, `09496`) were reported with names such as **Bố Hạ, Lạng Giang, Kép, Lục Nam, Hiệp Hoà, Yên Phong, Phù Lãng, Chi Lăng, Tiên Du, Gia Bình, Nhân Thắng, Lương Tài**.
- In the **Phase 3.2 report** (`03-trust-classification-report.md`, Section 3), these exact same 12 codes were listed with names such as **Tam Giang, Yên Phụ, Đông Thọ, Văn Môn, Dũng Liệt, Trung Nghĩa, Đông Phong, Long Châu, Thụy Hòa, Tam Đa, Hòa Tiến, Yên Trung**.

This independent audit conducted a forensic, byte-level investigation across all four project layers:
1. Canonical Seed Dataset (`communes.json`).
2. Phase 3.1.2.4 Reconciliation CSV (`03-commune-level-correction.csv`).
3. Phase 3.1.2.4.1 Independent Verification CSV (`07-independent-record-verification.csv`).
4. Active MySQL Production Database (`travel_planner.administrative_areas`).

---

## 2. Four-Layer Forensic Data Comparison

| Code | Layer 1: Canonical Seed (`communes.json`) | Layer 2: Phase 3.1.2.4 CSV (`03-commune-level-correction.csv`) | Layer 3: Phase 3.1.2.4.1 CSV (`07-independent-record-verification.csv`) | Layer 4: MySQL Database (`administrative_areas`) | Phase 3.2 Markdown Report Section 3 (Erronous Text) |
| :---: | :--- | :--- | :--- | :--- | :--- |
| `07294` | `Phường Bố Hạ` | `Phường Bố Hạ` | `Phường Bố Hạ` | `Phường Bố Hạ` | *Xã Tam Giang* |
| `07375` | `Phường Lạng Giang` | `Phường Lạng Giang` | `Phường Lạng Giang` | `Phường Lạng Giang` | *Xã Yên Phụ* |
| `07399` | `Phường Kép` | `Phường Kép` | `Phường Kép` | `Phường Kép` | *Xã Đông Thọ* |
| `07444` | `Phường Lục Nam` | `Phường Lục Nam` | `Phường Lục Nam` | `Phường Lục Nam` | *Xã Văn Môn* |
| `07840` | `Phường Hiệp Hoà` | `Phường Hiệp Hoà` | `Phường Hiệp Hoà` | `Phường Hiệp Hoà` | *Xã Dũng Liệt* |
| `09193` | `Phường Yên Phong` | `Phường Yên Phong` | `Phường Yên Phong` | `Phường Yên Phong` | *Xã Trung Nghĩa* |
| `09292` | `Phường Phù Lãng` | `Phường Phù Lãng` | `Phường Phù Lãng` | `Phường Phù Lãng` | *Xã Đông Phong* |
| `09313` | `Phường Chi Lăng` | `Phường Chi Lăng` | `Phường Chi Lăng` | `Phường Chi Lăng` | *Xã Long Châu* |
| `09319` | `Phường Tiên Du` | `Phường Tiên Du` | `Phường Tiên Du` | `Phường Tiên Du` | *Xã Thụy Hòa* |
| `09454` | `Phường Gia Bình` | `Phường Gia Bình` | `Phường Gia Bình` | `Phường Gia Bình` | *Xã Tam Đa* |
| `09475` | `Phường Nhân Thắng` | `Phường Nhân Thắng` | `Phường Nhân Thắng` | `Phường Nhân Thắng` | *Xã Hòa Tiến* |
| `09496` | `Phường Lương Tài` | `Phường Lương Tài` | `Phường Lương Tài` | `Phường Lương Tài` | *Xã Yên Trung* |

---

## 3. Database Query Evidence

Direct query executed against `travel_planner` MySQL database:
```sql
SELECT code, name, area_type, trust_classification 
FROM administrative_areas 
WHERE code IN ('07294', '07375', '07399', '07444', '07840', '09193', '09292', '09313', '09319', '09454', '09475', '09496')
ORDER BY code ASC;
```

**Result:**
```
+-------+--------------------+-----------+----------------------------+
| code  | name               | area_type | trust_classification       |
+-------+--------------------+-----------+----------------------------+
| 07294 | Phường Bố Hạ       | WARD      | UNVERIFIED_AND_QUARANTINED |
| 07375 | Phường Lạng Giang  | WARD      | UNVERIFIED_AND_QUARANTINED |
| 07399 | Phường Kép         | WARD      | UNVERIFIED_AND_QUARANTINED |
| 07444 | Phường Lục Nam     | WARD      | UNVERIFIED_AND_QUARANTINED |
| 07840 | Phường Hiệp Hoà    | WARD      | UNVERIFIED_AND_QUARANTINED |
| 09193 | Phường Yên Phong   | WARD      | UNVERIFIED_AND_QUARANTINED |
| 09292 | Phường Phù Lãng    | WARD      | UNVERIFIED_AND_QUARANTINED |
| 09313 | Phường Chi Lăng    | WARD      | UNVERIFIED_AND_QUARANTINED |
| 09319 | Phường Tiên Du     | WARD      | UNVERIFIED_AND_QUARANTINED |
| 09454 | Phường Gia Bình    | WARD      | UNVERIFIED_AND_QUARANTINED |
| 09475 | Phường Nhân Thắng  | WARD      | UNVERIFIED_AND_QUARANTINED |
| 09496 | Phường Lương Tài   | WARD      | UNVERIFIED_AND_QUARANTINED |
+-------+--------------------+-----------+----------------------------+
12 rows in set (0.01 sec)
```

---

## 4. Where Did the Names "Tam Giang", "Yên Phụ", etc., Come From?

Investigation reveals that the names listed in the Phase 3.2 markdown text (Tam Giang, Yên Phụ, Đông Thọ, Văn Môn, Dũng Liệt, Trung Nghĩa, Đông Phong, Long Châu, Thụy Hòa, Tam Đa, Hòa Tiến, Yên Trung) are actual commune units in **Yên Phong District, Bắc Ninh**, possessing completely different GSO/catalog codes:
- `09202` — Xã Tam Giang (`VERIFIED_WITH_LIMITATIONS`)
- `09205` — Xã Yên Trung (`VERIFIED_WITH_LIMITATIONS`)
- `09208` — Xã Tam Đa (`VERIFIED_WITH_LIMITATIONS`)
- `09238` — Xã Văn Môn (`VERIFIED_WITH_LIMITATIONS`)
- ... etc.

These 12 communes exist as valid Tier B records in the database with their proper respective codes (`09202`, `09205`, etc.).

---

## 5. Root Cause Determination

The discrepancy was **strictly a clerical transcription error in markdown prose** during the writing of Section 3 of `Travel_Planner/docs/verification/phase-3-2/03-trust-classification-report.md`.

Specifically:
1. **No database corruption occurred:** The MySQL database records for `07294..09496` were never modified, never renamed, and always remained `Phường Bố Hạ`, `Phường Lạng Giang`, etc.
2. **No code or resolver corruption occurred:** The Java hardcoded quarantine set `AdministrativeAreaResolverImpl.QUARANTINED_BAC_NINH_CODES` references codes `07294..09496`, matching the exact database records.
3. **No seed or CSV dataset corruption occurred:** Both `communes.json` and all verification CSVs match the database 100%.
4. **Remediation action:** Section 3 of `Travel_Planner/docs/verification/phase-3-2/03-trust-classification-report.md` has been amended to reflect the true, canonical names (`Phường Bố Hạ`, `Phường Lạng Giang`, etc.) in complete alignment with the database, seed files, and legal documents.

