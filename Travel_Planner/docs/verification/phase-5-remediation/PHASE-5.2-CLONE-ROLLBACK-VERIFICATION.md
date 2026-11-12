# PHASE 5.2 VERIFICATION REPORT — CLONE TRANSACTION ROLLBACK VERIFICATION

**Dự án:** Travel Planner  
**Giai đoạn:** Phase 5.2 — Remediation & Rollback Verification  
**Target:** Kiểm chứng thực nghiệm cơ chế Transaction Rollback khi quá trình clone thất bại giữa chừng  
**Branch:** `develop` | **HEAD:** `695d317`  
**Git Policy:** STRICTLY NO COMMIT, NO PUSH  
**Trạng thái nghiệm thu:** **PASS (100% Hoàn tất & Được chứng minh bằng kiểm nghiệm thực tế)**

---

## 1. MỤC TIÊU & PHẠM VI KIỂM CHỨNG

Mục tiêu của Phase 5.2 là chứng minh bằng thực nghiệm:
Khi thao tác sao chép lịch trình (`cloneItinerary`) gặp sự cố kỹ thuật hoặc ngoại lệ (`RuntimeException`) ở bất kỳ thời điểm nào giữa chừng (sau khi một phần dữ liệu đã được ghi xuống cơ sở dữ liệu), hệ thống quản lý giao dịch của Spring Boot và MySQL bắt buộc phải:
1. Rollback toàn bộ dữ liệu mới tạo (bản ghi lịch trình mới, các ngày mới, các hoạt động mới, các địa điểm đã lưu mới).
2. Phục hồi giá trị trường `reuse_count` của lịch trình nguồn về đúng trạng thái ban đầu trước khi clone.
3. Không để lại bất kỳ bản ghi mồ côi (orphan records) nào trong toàn bộ cơ sở dữ liệu.
4. Bảo đảm tính toàn vẹn tuyệt đối (All-or-Nothing / ACID Invariant) của lịch trình nguồn.

---

## 2. AUDIT KIẾN TRÚC GIAO DỊCH (TRANSACTION ARCHITECTURE AUDIT)

### 2.1. Phân tích ranh giới giao dịch (Transaction Boundary)
- Phương thức `cloneItinerary(Integer id, String currentUsername)` trong `ItineraryServiceImpl.java` được đánh dấu với `@Transactional` ở mức class (`@Service @Transactional`).
- **Transaction Manager:** Sử dụng `JpaTransactionManager` mặc định của Spring Boot, quản lý kết nối JDBC từ `HikariDataSource` trỏ vào MySQL database.
- **Tính thống nhất giao dịch (Single Transaction Context):**
  - Mọi thao tác:
    1. Đọc và validate lịch trình nguồn (`itineraryRepository.findById`).
    2. Tăng nguyên tử bộ đếm (`itineraryRepository.incrementReuseCount`).
    3. Lưu bản ghi lịch trình mới (`itineraryRepository.save(clonedItinerary)`).
    4. Lưu các ngày nhân bản (`itineraryDayRepository.save(clonedDay)`).
    5. Lưu các hoạt động nhân bản (`activityRepository.save(clonedAct)`).
    6. Lưu các liên kết địa điểm (`itineraryPlaceRepository.save(clonedPlace)`).
  - Tất cả các thao tác trên **đều chạy chung trong cùng một Transaction context**.
  - Không có bất kỳ thao tác nào sử dụng `Propagation.REQUIRES_NEW`, `@Async`, luồng nền riêng hay secondary transaction manager.
  - Không có khối `try-catch` nào nuốt ngoại lệ (exception swallowing) làm cản trở quá trình rollback.

### 2.2. Cơ chế kích hoạt Rollback
- Theo mặc định của Spring Declarative Transaction Management (`TransactionAspectSupport` / `RuleBasedTransactionAttribute`), bất kỳ ngoại lệ nào kế thừa từ `java.lang.RuntimeException` hoặc `java.lang.Error` đều tự động đánh dấu transaction là `setRollbackOnly` và gửi lệnh JDBC `ROLLBACK` xuống MySQL.

---

## 3. CƠ CHẾ GÂY LỖI CHỦ ĐỘNG (FAULT INJECTION) & TRIỂN KHAI TEST HOOK

Để kiểm chứng tính toàn vẹn của rollback, test bắt buộc phải gây lỗi **SAU KHI một phần dữ liệu đã thực sự được ghi xuống DB**.

### 3.1. Thiết kế Test Hook không ảnh hưởng Production
Trong `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/ItineraryServiceImpl.java`:
```java
    // Test hook for transaction rollback verification
    Runnable cloneFaultInjector;

    public void setCloneFaultInjector(Runnable cloneFaultInjector) {
        this.cloneFaultInjector = cloneFaultInjector;
    }
```
Vị trí kích hoạt hook được đặt bên trong vòng lặp sao chép ngày (`sourceDays`), ngay sau khi Ngày 1 và Hoạt động 1 đã được `save()` thành công:
```java
            for (Activity sourceAct : sourceActivities) {
                Activity clonedAct = Activity.builder()...build();
                activityRepository.save(clonedAct);
            }

            // Fault injection point after partial clone data has been persisted
            if (cloneFaultInjector != null) {
                cloneFaultInjector.run();
            }
```
**Tính an toàn của Test Hook:**
- Trong môi trường chạy thực tế (Production), biến `cloneFaultInjector` luôn là `null`.
- Lệnh kiểm tra `if (cloneFaultInjector != null)` chỉ tiêu tốn < 1 nanosecond, không tạo ra bất kỳ side effect nào.
- Hoàn toàn không mở bất kỳ endpoint REST, HTTP parameter hay cấu hình debug nào ra bên ngoài.

---

## 4. KẾT QUẢ KIỂM THỬ THỰC NGHIỆM TRÊN MYSQL

### 4.1. Kịch bản kiểm thử
File: `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/CloneConcurrencyAndRollbackTest.java`  
Phương thức: `testCloneRollback_FailureMidWay_RollsBackAllDataAndPreservesBaseline`

**Quy trình thực hiện:**
1. Khởi tạo một lịch trình nguồn công khai với 2 ngày, 2 hoạt động và 2 địa điểm đã lưu.
2. Ghi nhận toàn bộ số lượng bản ghi baseline trong database trước khi clone:
   - Số lượng `itineraries`: 1
   - Số lượng `itinerary_days`: 2
   - Số lượng `activities`: 2
   - Số lượng `itinerary_places`: 2
   - Số lượng `places`: 2
   - Số lượng `users`: 2
   - `reuse_count` của lịch trình nguồn: 0
3. Thiết lập fault injector ném ngoại lệ giữa chừng:
   ```java
   serviceImpl.setCloneFaultInjector(() -> {
       hookInvocations.incrementAndGet();
       throw new RuntimeException("FAULT_INJECTION: Giả lập sự cố database giữa chừng trong quá trình nhân bản!");
   });
   ```
4. Gọi `serviceImpl.cloneItinerary(...)` và bắt `RuntimeException`.
5. Thực hiện truy vấn trực tiếp cơ sở dữ liệu MySQL sau rollback và so sánh với baseline.

### 4.2. Bằng chứng thực thi thực tế
Chạy lệnh kiểm thử với Maven Wrapper:
```bash
.\mvnw.cmd test -Dtest=CloneConcurrencyAndRollbackTest
```

**Bằng chứng log thực tế:**
```text
>>> Phase 5.2 Transaction Rollback Verification PASSED: All partial clone records, days, activities, and counter cleanly rolled back to pristine baseline.
>>> Phase 5.1 Concurrency Verification PASSED: 10 concurrent clones completed in 557ms with reuse_count = 10
[INFO] Tests run: 2, Failures: 0, Errors: 0, Skipped: 0, Time elapsed: 22.34 s -- in Travel_Planner.Travel_Planner.CloneConcurrencyAndRollbackTest
[INFO] BUILD SUCCESS
```

### 4.3. Đối chiếu các chỉ số bất biến sau Rollback

| Chỉ số kiểm tra | Baseline trước khi clone | Trạng thái sau khi clone lỗi | Kết quả xác minh |
| :--- | :---: | :---: | :--- |
| **Số lượng `itineraries`** | 1 | 1 | **TRÙNG KHỚP 100%** (Bản ghi clone bị rollback hoàn toàn) |
| **Số lượng `itinerary_days`** | 2 | 2 | **TRÙNG KHỚP 100%** (Ngày của bản clone bị xóa sạch) |
| **Số lượng `activities`** | 2 | 2 | **TRÙNG KHỚP 100%** (Hoạt động của bản clone bị xóa sạch) |
| **Số lượng `itinerary_places`** | 2 | 2 | **TRÙNG KHỚP 100%** (Không sinh liên kết địa điểm rác) |
| **Số lượng `places` catalog** | 2 | 2 | **TRÙNG KHỚP 100%** (Danh mục địa điểm không đổi) |
| **Số lượng `users`** | 2 | 2 | **TRÙNG KHỚP 100%** |
| **`reuse_count` của lịch trình nguồn** | 0 | 0 | **TRÙNG KHỚP 100%** (Counter được rollback về 0) |
| **Metadata lịch trình nguồn** | Nguyên vẹn | Nguyên vẹn | **TRÙNG KHỚP 100%** |
| **Bản ghi mồ côi (Orphan records)** | 0 | 0 | **KHÔNG CÓ BẢN GHI MỒ CÔI** |

---

## 5. KẾT LUẬN

Hạng mục **Phase 5.2 — Clone Transaction Rollback Verification** đạt kết quả **PASS**.
- Chứng minh đầy đủ bằng thực nghiệm rằng Spring Transaction và MySQL InnoDB đã phối hợp xử lý rollback toàn diện.
- Khi xảy ra lỗi giữa chừng, toàn bộ các bảng ghi mới tạo và counter `reuse_count` đều bị thu hồi, đưa cơ sở dữ liệu về trạng thái sạch sẽ tuyệt đối như trước khi thực hiện clone.

