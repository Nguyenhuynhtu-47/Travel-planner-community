# CANONICAL CORRECTION REFERENCE
## Administrative Catalog — Phase 3.1.2.4
### Verified corrections for the Travel Planner agent

**Document purpose:** This file is the curated correction source for the known factual errors in the Phase 3.1.2.3 Administrative Catalog report and dataset. The agent must read and apply this document directly. It is not a request to repeat web research.

**Revision notice:** This is the corrected revision of the initial file. Any numeric codes previously shown for the 10 Đồng Nai wards and the previously listed 12 Bắc Ninh ward names are withdrawn unless independently present in the official source files bundled with the project.  
**Snapshot:** 2026-09-20  
**Scope:** Province-level administrative units, the 22 commune-to-ward conversions, known incorrect records, parent relationships, and rules for repairing the catalog.  
**Important:** This document corrects the known errors. It does **not** certify every one of the 3,355 catalog rows. Do not describe the whole catalog as fully verified merely because these corrections have been applied.

---

## 1. Non-negotiable correction summary

The Phase 3.1.2.3 report contains two major factual errors:

1. Its 10 claimed Đồng Nai conversions are not the 10 wards established by Resolution 237/NQ-UBTVQH16.
2. Its 12 claimed Bắc Ninh conversions are not the 12 wards established by Resolution 388/NQ-UBTVQH16.

Therefore, the report's statement that all 22 conversions were verified is false. The existing CSV, JSON source data, metadata, imported database rows, and checksums must be corrected together. Editing only the report is not acceptable.

At the 2026-09-20 snapshot:

- Vietnam has **34 province-level administrative units**.
- The correct type distribution is **9 centrally governed cities** and **25 provinces**.
- The catalog's claimed commune-level total of **3,321** is consistent with the 2025 base count plus the 22 conversions, but the count alone does not prove row-level correctness.
- If the source dataset uses the same classification convention, the expected commune-level type counts after these 22 conversions are **709 wards, 2,599 communes, and 13 special zones**. Recalculate from the actual source files; never force database counts to these numbers by fabricating or relabeling rows.

## 2. Correct province-level catalog at 2026-09-20

### 2.1 Correct type totals

| Type | Expected count |
|---|---:|
| CENTRAL_CITY | 9 |
| PROVINCE | 25 |
| **Total** | **34** |

The three 2026 promotions that the Phase 3.1.2.3 report must account for are:

| Current official name | Previous status | Legal instrument | Effective date |
|---|---|---|---|
| Thành phố Đồng Nai | Tỉnh Đồng Nai | Nghị quyết 30/2026/QH16 | 2026-04-30 |
| Thành phố Quảng Ninh | Tỉnh Quảng Ninh | Nghị quyết 36/2026/QH16 | 2026-09-01 |
| Thành phố Bắc Ninh | Tỉnh Bắc Ninh | Nghị quyết 39/2026/QH16 | 2026-09-20 |

These are centrally governed cities at the requested snapshot, not provinces.

### 2.2 Complete list of 34 units

**CENTRAL_CITY (9):**

1. Thành phố Hà Nội
2. Thành phố Huế
3. Thành phố Hải Phòng
4. Thành phố Đà Nẵng
5. Thành phố Hồ Chí Minh
6. Thành phố Cần Thơ
7. Thành phố Đồng Nai
8. Thành phố Quảng Ninh
9. Thành phố Bắc Ninh

**PROVINCE (25):**

1. Tỉnh An Giang
2. Tỉnh Cà Mau
3. Tỉnh Cao Bằng
4. Tỉnh Đắk Lắk
5. Tỉnh Điện Biên
6. Tỉnh Đồng Tháp
7. Tỉnh Gia Lai
8. Tỉnh Hà Tĩnh
9. Tỉnh Hưng Yên
10. Tỉnh Khánh Hòa
11. Tỉnh Lai Châu
12. Tỉnh Lâm Đồng
13. Tỉnh Lạng Sơn
14. Tỉnh Lào Cai
15. Tỉnh Nghệ An
16. Tỉnh Ninh Bình
17. Tỉnh Phú Thọ
18. Tỉnh Quảng Ngãi
19. Tỉnh Quảng Trị
20. Tỉnh Sơn La
21. Tỉnh Tây Ninh
22. Tỉnh Thái Nguyên
23. Tỉnh Thanh Hóa
24. Tỉnh Tuyên Quang
25. Tỉnh Vĩnh Long

**Implementation rule:** Preserve the canonical code of each province-level unit from the applicable official administrative-code source. Do not derive or invent codes from names. A name/type correction must not accidentally change the administrative code.

## 3. Correct 10 Đồng Nai ward conversions

### 3.1 Legal basis

**Nghị quyết số 237/NQ-UBTVQH16**, issued 2026-04-14, effective 2026-04-30, establishes 10 wards in Đồng Nai from the corresponding pre-existing communes.

The correct 10 wards and administrative codes are:

| Correct official unit name | Correct type | Parent at 2026-09-20 | Code |
|---|---|---|---|
| Phường Trảng Bom | WARD | Thành phố Đồng Nai | DO NOT ASSUME — confirm from official code appendix |
| Phường Long Thành | WARD | Thành phố Đồng Nai | DO NOT ASSUME — confirm from official code appendix |
| Phường Trị An | WARD | Thành phố Đồng Nai | DO NOT ASSUME — confirm from official code appendix |
| Phường Nhơn Trạch | WARD | Thành phố Đồng Nai | DO NOT ASSUME — confirm from official code appendix |
| Phường Tân Khai | WARD | Thành phố Đồng Nai | DO NOT ASSUME — confirm from official code appendix |
| Phường Xuân Lộc | WARD | Thành phố Đồng Nai | DO NOT ASSUME — confirm from official code appendix |
| Phường Tân Phú | WARD | Thành phố Đồng Nai | DO NOT ASSUME — confirm from official code appendix |
| Phường Lộc Ninh | WARD | Thành phố Đồng Nai | DO NOT ASSUME — confirm from official code appendix |
| Phường Dầu Giây | WARD | Thành phố Đồng Nai | DO NOT ASSUME — confirm from official code appendix |
| Phường Đồng Phú | WARD | Thành phố Đồng Nai | DO NOT ASSUME — confirm from official code appendix |

**Code correction notice:** An earlier draft of this file contained numeric codes for these rows without a verified official-code citation. Those numbers are withdrawn and MUST NOT be imported or treated as correct. The names above are confirmed by the Government's publication of NQ 237 and the Đồng Nai government portal; codes must come from the project's official administrative-code source.

The codes above are carried forward from the existing administrative-code assignments. The resolution changes the administrative type from commune to ward; it does not justify inventing a new code.

### 3.2 Incorrect Đồng Nai list in Phase 3.1.2.3

The following list in the report is incorrect as the set of 10 conversions under NQ 237:

- Long Hưng
- Phước Tân
- Tam Phước
- An Phước
- Long Đức
- Lộc An
- Bình Sơn
- Hiệp Phước
- Phước Thiền
- Phú Hội

Do not retain these as the 10 NQ 237 conversion rows. Some names may exist as administrative units or local place names in another context; the correction here is specifically that they are **not** the 10 wards established by NQ 237.

## 4. Correct 12 Bắc Ninh ward conversions

### 4.1 Legal basis

**Nghị quyết số 388/NQ-UBTVQH16**, issued 2026-08-04, effective 2026-09-20, establishes 12 wards in Bắc Ninh.

**Critical data limitation:** The official Công báo listing confirms that NQ 388/NQ-UBTVQH16 concerns the establishment of wards in Bắc Ninh and is effective 2026-09-20. However, the full annex text was not successfully extracted in the preparation of this reference. Therefore this document does **not** certify the names or administrative codes of the 12 wards. Do not use a guessed list.

The agent must use the official NQ 388 PDF/DOCX already linked from the Government Gazette entry, or a copy bundled with the project/source package, to transcribe the exact 12 names and the underlying commune names. If the official annex is not available locally, stop mutation of these 12 records and mark them `UNVERIFIED_SOURCE_DOCUMENT_MISSING`. Do not substitute a secondary list or infer names from prior assistant messages.

| Expected number of wards under NQ 388 | 12 |
|---|---:|
| Resolution issue date | 2026-08-04 |
| Effective date | 2026-09-20 |
| Source | Government Gazette entry for 388/NQ-UBTVQH16 (see Section 6) |
| Exact names and codes | Must be transcribed from official annex; not supplied as verified data in this file |

### 4.2 Incorrect Bắc Ninh list in Phase 3.1.2.3

A prior draft of this reference listed the following names as the 12 NQ 388 wards:

- Yên Phong
- Tiên Du
- Chi Lăng
- Phù Lãng
- Lương Tài
- Gia Bình
- Nhân Thắng
- Hiệp Hòa
- Bố Hạ
- Lạng Giang
- Kép
- Lục Nam

**This list is withdrawn as unverified. DO NOT import it or use it as an authoritative correction list.** It must be compared against the actual official annex of NQ 388 before any row is changed.

## 5. Parent corrections for special zones

For the 2026-09-20 snapshot, the following parent relationships must be corrected:

| Special zone | Correct parent |
|---|---|
| Đặc khu Phú Quý | Tỉnh Lâm Đồng |
| Đặc khu Côn Đảo | Thành phố Hồ Chí Minh |
| Đặc khu Phú Quốc | Tỉnh An Giang |
| Đặc khu Thổ Châu | Tỉnh An Giang |
| Đặc khu Kiên Hải | Tỉnh An Giang |

Do not retain the obsolete parent labels Bình Thuận, Bà Rịa–Vũng Tàu, or Kiên Giang for this snapshot.

**Important:** This table corrects the parent relationships only. It does not independently certify the administrative codes, geometry, exact legal type, or all other fields of the 13 special-zone records. Keep those fields subject to the actual legal/source dataset evidence already supplied in the repository.

## 6. Legal timeline and authoritative source references

Use the following supplied references as the basis for these corrections. The agent is not being asked to conduct another web search.

| Instrument | Subject | Date issued | Effective date | Supplied reference |
|---|---|---:|---:|---|
| NQ 202/2025/QH15 | 2025 provincial administrative reorganization | 2025-06-12 | 2025-06-12 (resolution); new arrangement applies from 2025-07-01 | https://quochoi.vn/pages/tim-kiem.aspx?ItemID=94522 |
| QĐ 19/2025/QĐ-TTg | Administrative codes and names | 2025-06-15 | 2025-07-01 | https://datafiles.chinhphu.vn/cpp/files/vbpq/2025/7/19ttg.signed.pdf |
| NQ 237/NQ-UBTVQH16 | 10 Đồng Nai wards | 2026-04-14 | 2026-04-30 | https://chinhphu.vn/?classid=0&docid=217876&pageid=27160 |
| NQ 30/2026/QH16 | Establishment of Đồng Nai City | 2026-04-24 | 2026-04-30 | https://danhmuchanhchinh.nso.gov.vn/NghiDinh.aspx |
| NQ 36/2026/QH16 | Establishment of Quảng Ninh City | 2026-08-24 | 2026-09-01 | https://vanban.chinhphu.vn/?classid=1&docid=219325&orggroupid=1&pageid=27160 |
| NQ 39/2026/QH16 | Establishment of Bắc Ninh City | 2026-08-24 | 2026-09-20 | https://danhmuchanhchinh.nso.gov.vn/NghiDinh.aspx |
| NQ 388/NQ-UBTVQH16 | 12 Bắc Ninh wards | 2026-08-04 | 2026-09-20 | https://congbao.chinhphu.vn/van-ban-dang-cong-bao/uy-ban-thuong-vu-quoc-hoi-c28.htm |

Additional official/administrative references:

- National Statistics Office administrative catalog and legal timeline: https://danhmuchanhchinh.nso.gov.vn/NghiDinh.aspx
- Government publication of the 10 Đồng Nai wards: https://vpubnd.dongnai.gov.vn/vi/news/hoat-dong-chinh-quyen-nha-nuoc/thanh-lap-10-phuong-thuoc-tinh-dong-nai-142.html
- Government/official portal listing the 10 Đồng Nai wards: https://dongnai.gov.vn/vi/news/tin-tuc-su-kien/infographic-dong-nai-chinh-thuc-co-10-phuong-moi-tu-ngay-30-4-2026-61013.html
- Government policy portal, full NQ 36/2026/QH16: https://xaydungchinhsach.chinhphu.vn/toan-van-nghi-quyet-so-36-2026-qh16-thanh-lap-thanh-pho-quang-ninh-tu-1-9-2026-119260903082603583.htm
- Official Quảng Ninh portal confirming city status from 2026-09-01: https://www.quangninh.gov.vn/chuyen-de/tangtruong/Trang/ChiTietTinTuc.aspx?nid=168738
- Official National Assembly report confirming Đồng Nai became a centrally governed city and the national total remained 34 (7 cities at that point): https://quochoi.vn/hoatdongcuaquochoi/cackyhopquochoi/quochoikhoaxv/kyhopthu10/Pages/thong-tin-khac.aspx?ItemID=99487
- Official National Assembly report on 12 Bắc Ninh wards: https://quochoi.vn/hoidongdantoc/cacphienhop/pages/home.aspx/?ItemID=99668
- Official NSO page listing NQ 237, NQ 30, NQ 36, NQ 39 and NQ 388 with dates: https://danhmuchanhchinh.nso.gov.vn/NghiDinh.aspx
- Cục Thống kê administrative code notice 1123/CTK-CSCL (secondary mirror with its appendix): https://dulieuphapluat.vn/van-ban/hanh-chinh-van-ban/cong-van-1123ctk-cscl-nam-2026-ve-thong-bao-ma-so-va-ten-don-vi-hanh-chinh-moi-do-cuc-thong-ke-ban-hanh-1258982.html

## 7. Required corrections to the source data and database

The agent must apply the corrections to the actual source-of-truth data, not merely alter documentation.

### 7.1 Required sequence

1. Preserve a full backup/snapshot of the current source files and database before modification.
2. Record the current row counts and canonical checksums.
3. Locate all 22 incorrect conversion rows and their references in:
   - source JSON/CSV files,
   - metadata,
   - importer inputs,
   - verification CSVs,
   - database records,
   - tests and fixtures,
   - documentation.
4. Replace the incorrect conversion set with the 10 correct Đồng Nai wards and 12 correct Bắc Ninh wards.
5. Correct province-level names/types and the five special-zone parent relationships listed above.
6. Confirm each ward's code against the supplied official administrative-code source. For Bắc Ninh, do not invent a code if the source material does not expose it.
7. Rebuild metadata and checksums from the corrected canonical source.
8. Re-import only through the project's supported, transactional, idempotent importer.
9. Compare source data, imported database rows, and verification CSVs field by field.
10. Run all relevant backend and Flutter tests.

### 7.2 Do not do the following

- Do not edit only the Markdown report while leaving JSON, CSV, metadata, or MySQL wrong.
- Do not use the old 22 code/name pairings from Phase 3.1.2.3.
- Do not fabricate administrative codes, names, parent relationships, legal articles, or source hashes.
- Do not label a record `VERIFIED_PRIMARY` unless the supplied evidence actually supports its code, name, type, and parent.
- Do not force counts by creating synthetic records or relabeling unrelated communes.
- Do not use geocoding, OSM display names, or tourism labels as proof of legal administrative identity.
- Do not enable automatic destructive repair. Any repair mechanism must be explicit, backed up, transactional, non-destructive, and safe with foreign keys.
- Do not add `places.administrative_area_id` or begin Place backfill until the catalog correction passes the verification gate described below.
- Do not change Activity snapshots or route data.

## 8. Place integration rules after catalog correction

Once the corrected catalog passes verification, Phase 3.2 may proceed under these rules:

- `places.administrative_area_id` may be introduced as a nullable FK to the canonical administrative-area table, after schema and migration review.
- A Place may be linked only to the most specific supported current administrative area when evidence is sufficient.
- A city/province name in a free-form address is not always enough to identify a commune/ward.
- Never assign a ward based only on fuzzy name matching where multiple places or administrative areas are plausible.
- Preserve unresolved Places with a `NULL` administrative-area reference and report them as unresolved; do not guess.
- Use Place coordinates plus a trusted boundary dataset only if that geometry is already available and its provenance is documented. This task does not authorize inventing polygon boundaries.
- Historical Activity snapshots must remain unchanged and must not receive a direct AdministrativeArea FK.
- Do not delete, merge, hide, or rename Places as a side effect of administrative-area assignment.

## 9. Acceptance gates

### Gate A — correction data

- All 10 Đồng Nai conversion targets match Section 3.
- All 12 Bắc Ninh conversion targets are transcribed and verified against the official NQ 388 annex. Section 4 of this reference deliberately does not provide an unverified name/code list.
- All 34 province-level records match Section 2, including the 9/25 type distribution.
- The five special-zone parents match Section 5.
- All administrative codes are confirmed from supplied official code data; unresolved codes are explicitly reported, never guessed. The withdrawn numeric codes from the earlier draft must not be used.
- No duplicate administrative codes, orphan parent references, or invalid type/parent combinations.

### Gate B — source/database consistency

- Source JSON/CSV, metadata, verification CSVs, and MySQL agree field by field.
- Canonical checksum is recalculated and reproducible.
- Before/after row counts and checksums are recorded.
- Import is idempotent and transactional.
- No silent destructive repair occurs.

### Gate C — application regression

- Existing Place records are preserved.
- Existing Activity records and all Activity location snapshot fields are unchanged.
- Existing route behavior is unchanged.
- Backend tests and relevant Flutter tests pass without new failures.
- Existing known baseline failures are reported separately, not hidden.

### Gate D — Phase 3.2 authorization

Only after Gates A-C pass may the agent implement the nullable Place-to-AdministrativeArea relationship and a conservative backfill.

If any mandatory code, legal identity, or parent cannot be confirmed from the supplied source material, stop the affected mutation and report the unresolved rows. Do not claim full acceptance.

---

## 10. Required output

Create/update the Phase 3.1.2.4 artifacts, including:

1. `01-canonical-correction-results.md`
2. `02-province-level-reconciliation.csv`
3. `03-commune-level-correction.csv`
4. `04-source-database-integrity.md`
5. `05-place-activity-preservation.md`
6. `06-final-acceptance-report.md`

The CSVs must contain actual row-level records, not only aggregate counts. Each changed administrative record must include:

- code,
- previous name/type/parent,
- corrected name/type/parent,
- legal instrument,
- effective date,
- evidence reference,
- verification status,
- reason for change.

Also update:

- administrative-area architecture/design documents,
- project status and next steps,
- Phase 3 roadmap,
- `docs/ai/09-development-log.md` (append a dated English entry).

The final report must distinguish:

- verified corrections,
- unresolved records,
- data changes,
- code changes,
- test results,
- known baseline failures,
- remaining risks.

## 11. Git and execution safety

- Inspect and record the current branch, HEAD, tracked changes, and untracked files before work.
- Preserve all pre-existing user changes.
- Do not reset, checkout, clean, stash, or overwrite unrelated work.
- Do not commit or push.
- Do not claim a clean working tree unless `git status` proves it.
- Do not treat the previous report's test counts as current test results; rerun the relevant tests.

## 12. Final instruction to the agent

Use this file as the direct correction reference. Do not repeat web research for the facts explicitly settled here. Inspect the repository's supplied source dataset and implementation to apply these corrections safely.

Where this document explicitly marks a code as requiring source confirmation, do not invent it. Report the exact missing evidence and stop that row's import/backfill rather than silently guessing.

**The objective is a correct administrative catalog, not a cosmetically accepted report.**
