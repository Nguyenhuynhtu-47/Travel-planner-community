# POST PHASE 6A — MOBILE BASELINE TEST REMEDIATION REPORT

**Date:** 2026-11-12  
**Target Platform:** Flutter Mobile (`Travel_Planner/frontend/mobile`)  
**Status:** COMPLETED — 100% PASS (413 / 413 Mobile Tests)  
**Git Policy Compliance:** STRICTLY NO COMMIT, NO PUSH. Zero MySQL / Backend schema changes.

---

## 1. Executive Summary & Verification Metrics

Prior to Phase 6A, 3 Flutter Mobile test failures were repeatedly documented as persistent baseline failures across Phase 4, Phase 5, and Phase 6A. Following the completion of Phase 6A UX and integration tests, this task systematically investigated, diagnosed, and remediated all 3 baseline test failures.

### Baseline Arithmetic Comparison

| Metric | Pre-Remediation Baseline | Post-Remediation Status | Delta |
| :--- | :--- | :--- | :--- |
| **Mobile Tests Passed** | 410 PASS | **413 PASS** | +3 |
| **Mobile Tests Failed** | 3 FAIL | **0 FAIL** | -3 |
| **Mobile Tests Skipped** | 0 | **0** | 0 |
| **Phase 6A Itinerary Suite** | 36 PASS | **36 PASS** | 0 (No regression) |
| **Static Analysis (`flutter analyze`)** | 0 errors | **0 errors** | Clean |
| **Total Test Suite Health** | 99.27% (410/413) | **100.0% (413/413)** | Clean Baseline Achieved |

---

## 2. Root Cause Analysis & Remediation Details

### ISSUE 1: `test/explore_test.dart:96` — `CreatorSummary displayName Fallback`

- **Test Name:** `CreatorSummary falls back to username when fullName is null or empty`
- **Initial Error:**
  ```text
  Expected: 'traveller_bob'
    Actual: 'Người dùng'
     Which: is different.
            Expected: traveller_bob
              Actual: Người dùng
  ```
- **Investigation & Root Cause:**
  - In Phase 3 (commit `9fa59dc`), the engineering team intentionally implemented a security and privacy enhancement decoupling authentication login credentials (`username`) from public identity (`handle`, `fullName`, `displayName`).
  - The business requirement explicitly mandated that public views must NEVER expose an author's private `username`.
  - The production model `CreatorSummary` in `lib/features/explore/data/models/creator_summary.dart` correctly implements this privacy contract:
    ```dart
    String get displayName {
      if (fullName != null && fullName!.trim().isNotEmpty) {
        return fullName!.trim();
      }
      if (handle != null && handle!.trim().isNotEmpty) {
        return '@${handle!.trim()}';
      }
      return 'Người dùng';
    }
    ```
  - While `test/features/profile/user_handle_test.dart:295-320` verified this behavior (`CreatorSummary displayName prefers fullName, falls back to @handle, never username`), the legacy test in `test/explore_test.dart` had remained unchanged from pre-Phase 3, asserting that `displayName` should expose raw `username`.
- **Decision & Fix:**
  - **Layer:** Test layer update (`test/explore_test.dart`). The implementation strictly adheres to the privacy specification and must not be altered to leak private credentials.
  - **Change:** Updated `test/explore_test.dart` to assert that when `fullName` is empty, `displayName` prefers `@handle` (e.g. `@bob_the_traveler`), and when both `fullName` and `handle` are empty, it safely defaults to `'Người dùng'`, never leaking `username`.

---

### ISSUE 2: `test/features/social/rating_ui_layout_test.dart:153` — `Rating Dialog RenderFlex Overflow on 360x640`

- **Test Name:** `1. Rating Dialog - Layout & RenderFlex Overflow Prevention Dialog renders cleanly without RenderFlex overflow on standard 360x640 screen`
- **Initial Error:**
  ```text
  The following TestFailure was thrown running a test:
  Expected: exactly one matching candidate
    Actual: _TypeWidgetFinder:<Found 0 widgets with type "AlertDialog": []>
  ```
  Preceded by Flutter framework warning:
  ```text
  A RenderFlex overflowed by ... / Cannot hit test because tap offset Offset(98.6, 651.6) is outside viewport bounds Size(360.0, 640.0)
  ```
- **Investigation & Root Cause:**
  - Commit `a9efc92` initially introduced `rating_ui_layout_test.dart` with a vertical scroll drag offset of `Offset(0, -900)`.
  - Subsequently, commits `0ded0d8` and `5bf77fe` added the `_buildItinerarySavedPlaces` section and `ItineraryMapPreviewCard` to `ItineraryDetailScreen`.
  - These two additional sections increased the preceding scroll content height by ~350px.
  - Consequently, the `-900` drag was no longer sufficient to bring the "Chỉnh sửa" rating button into the 360x640 viewport. The button rested at vertical coordinate `Y = 651.6`, just below the bottom edge (640).
  - Calling `tester.tap(editBtnFinder)` failed to deliver the pointer event because the widget was offscreen, preventing `_openRatingDialog` from executing and resulting in 0 `AlertDialog` widgets found.
- **Decision & Fix:**
  - **Layer:** Test scroll calibration (`test/features/social/rating_ui_layout_test.dart`).
  - **Change:** Adjusted the scroll drag offset from `-900` to `-1200` to accommodate the expanded itinerary header sections.
  - **Verification:** Once tapped, the `AlertDialog` opened cleanly without any RenderFlex overflow on standard 360x640 and ultra-narrow 320x480 viewports.

---

### ISSUE 3: `test/features/social/rating_ui_layout_test.dart:274` — `Section Ordering: Comments Precedes Ratings`

- **Test Name:** `2. Section Order - Comments Section precedes Rating Section CommentsSection is rendered BEFORE RatingSection in the scroll tree`
- **Initial Error:**
  ```text
  Expected: exactly one matching candidate
    Actual: _TextWidgetFinder:<Found 0 widgets with text "Đánh giá (5)": []>
  ```
- **Investigation & Root Cause:**
  - `ItineraryDetailScreen` sliver hierarchy in `lib/features/itinerary/presentation/screens/itinerary_detail_screen.dart:1434-1446` is structured as:
    ```dart
    if ((itinerary.status == 'ACTIVE' || itinerary.status == 'PUBLISHED') && itinerary.visibility == 'PUBLIC') ...[
      if (!isOwner)
        SliverToBoxAdapter(
          child: ItineraryCommentsSection(
            itineraryId: itinerary.itineraryId,
            ...
          ),
        ),
      SliverToBoxAdapter(child: _buildRatingSection(itinerary, isOwner)),
    ],
    ```
  - The implementation already orders `ItineraryCommentsSection` strictly BEFORE `_buildRatingSection`.
  - In `rating_ui_layout_test.dart:267`, the test executed `await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));`.
  - Due to the addition of Saved Places and Map Preview cards earlier in the sliver list, a `-350` scroll brought `ItineraryCommentsSection` into the viewport cache, but the rating header `'Đánh giá (5)'` remained well below the viewport extent and was not yet built by Flutter's lazy sliver viewport.
- **Decision & Fix:**
  - **Layer:** Test scroll calibration (`test/features/social/rating_ui_layout_test.dart`).
  - **Change:** Adjusted the scroll drag offset from `-350` to `-700`.
  - **Verification:** Both `ItineraryCommentsSection` and `_buildRatingSection` are rendered simultaneously, allowing the assertion `expect(commentsTop, lessThan(ratingTop))` to verify that Comments section top coordinate (Y=408.0) is positioned above Rating section top coordinate (Y=664.0).

---

## 3. Comprehensive Verification & Regression Evidence

### A. Targeted Social Suite
```powershell
flutter test test/features/social/
# Output:
# 00:03 +14: All tests passed!
```

### B. Explore Test Suite
```powershell
flutter test test/explore_test.dart
# Output:
# 00:02 +16: All tests passed!
```

### C. Phase 6A Regression Verification
```powershell
flutter test test/features/itinerary/
# Output:
# 00:09 +36: All tests passed!
```
All 36 tests for Phase 6A (Itinerary Picker, Day Picker, Prefill, Boundary exclusion, and E2E integration) passed with 100% success.

### D. Full Mobile Test Suite
```powershell
flutter test
# Output:
# 01:01 +413: All tests passed!
```
- Total tests: **413**
- Passed: **413**
- Failed: **0**
- Errors: **0**

### E. Static Analysis
```powershell
flutter analyze --no-pub
# Output:
# 0 errors found across the entire mobile package.
```

---

## 4. Modified Files Summary

| File Path | Modification Type | Description |
| :--- | :--- | :--- |
| `Travel_Planner/frontend/mobile/test/explore_test.dart` | Test Update | Aligned `CreatorSummary` test with privacy decoupling (fallback to `@handle` or `'Người dùng'`, never `username`). |
| `Travel_Planner/frontend/mobile/test/features/social/rating_ui_layout_test.dart` | Test Calibration | Calibrated scroll drag offsets (`-900 -> -1200`, `-350 -> -700`) to account for Saved Places and Map Preview sections. |

---

## 5. Conclusion & Readiness

With all 3 persistent baseline failures resolved, the Flutter Mobile test suite has reached **100% PASS (413/413)**. The codebase is clean, robust, and fully verified for Phase 6A completion and ready for Phase 6B planning.

