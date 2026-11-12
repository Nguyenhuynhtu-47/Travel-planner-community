# PHASE 5.1 VERIFICATION REPORT — ATOMIC REUSE COUNT INCREMENT & CONCURRENCY HARDENING

**Dự án:** Travel Planner  
**Giai đoạn:** Phase 5.1 — Remediation & Concurrency Hardening  
**Target:** Loại bỏ rủi ro Lost Update khi nhiều người dùng clone cùng một lịch trình đồng thời  
**Branch:** `develop` | **HEAD:** `695d317`  
**Git Policy:** STRICTLY NO COMMIT, NO PUSH  
**Trạng thái nghiệm thu:** **PASS (100% Hoàn tất & Được chứng minh bằng kiểm nghiệm thực tế)**

---

## 1. HIỆN TRẠNG TRƯỚC KHI SỬA & NGUYÊN NHÂN KỸ THUẬT

### 1.1. Hiện trạng mã nguồn Phase 5
Trong quá trình triển khai Phase 5, cơ chế cập nhật số lần sao chép (`reuse_count`) của lịch trình nguồn tại `ItineraryServiceImpl.java` (dòng 670–671) được viết như sau:
```java
// Increment reuse count of original itinerary
source.setReuseCount((source.getReuseCount() != null ? source.getReuseCount() : 0) + 1);
itineraryRepository.save(source);
```

### 1.2. Phân tích nguyên nhân kỹ thuật (Root Cause Analysis)
1. **Thiếu cơ chế Optimistic Locking:**
   - Thực thể `Itinerary` trong `Itinerary.java` không có trường `@Version`. Do đó Hibernate không thực hiện kiểm tra version khi cập nhật.
2. **Hiện tượng Lost Update kinh điển:**
   - Khi có nhiều request clone cùng lúc (ví dụ Luồng A và Luồng B cho lịch trình đang có `reuse_count = 5`):
     - Luồng A đọc `reuseCount = 5`.
     - Luồng B đọc `reuseCount = 5`.
     - Luồng A tính `5 + 1 = 6` và ghi vào database: `UPDATE itineraries SET reuse_count = 6 ...`.
     - Luồng B tính `5 + 1 = 6` và ghi đè vào database: `UPDATE itineraries SET reuse_count = 6 ...`.
     - Kết quả: `reuse_count` dừng ở 6 thay vì 7. Lần clone của Luồng A bị mất (Lost Update).
3. **Mối quan hệ Persistence Context & Hibernate Dirty Checking:**
   - Khi `source` được nạp qua `itineraryRepository.findById(id)`, nó là một managed entity trong Hibernate Session.
   - Nếu gọi setter `source.setReuseCount(...)` trong Java và sau đó gọi thêm câu lệnh SQL bên ngoài, đến thời điểm transaction commit, cơ chế dirty checking của Hibernate có thể tự động sinh câu lệnh UPDATE ghi đè giá trị cũ trong bộ nhớ lên giá trị nguyên tử vừa cập nhật.
4. **Đối chiếu chuẩn thiết kế đã có trong repository:**
   - Các trường bộ đếm khác như `favoriteCount`, `ratingCount`, `commentCount` trong `ItineraryRepository.java` đều đã được chuẩn hóa bằng các câu lệnh SQL UPDATE nguyên tử:
     ```java
     @Modifying
     @Query("update Itinerary i set i.favoriteCount = i.favoriteCount + 1 where i.itineraryId = :itineraryId")
     int incrementFavoriteCount(@Param("itineraryId") Integer itineraryId);
     ```

---

## 2. GIẢI PHÁP TRIỂN KHAI & CÁC FILE THAY ĐỔI

### 2.1. File 1: `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/repository/ItineraryRepository.java`
Bổ sung query tăng nguyên tử trực tiếp ở tầng database với `flushAutomatically = true`:
```java
    @Modifying(flushAutomatically = true)
    @Query("update Itinerary i set i.reuseCount = coalesce(i.reuseCount, 0) + 1 where i.itineraryId = :itineraryId")
    int incrementReuseCount(@Param("itineraryId") Integer itineraryId);
```
- `flushAutomatically = true`: Đảm bảo mọi thay đổi chưa flush trong transaction hiện tại được đẩy xuống DB trước khi thực thi câu lệnh SQL UPDATE trực tiếp.
- `coalesce(i.reuseCount, 0) + 1`: Xử lý an toàn trường hợp `reuseCount` là `NULL` (khởi tạo về 1 thay vì ném lỗi SQL).

### 2.2. File 2: `Travel_Planner/backend/src/main/java/Travel_Planner/Travel_Planner/service/impl/ItineraryServiceImpl.java`
1. Thay thế hoàn toàn thao tác read-modify-write (`source.setReuseCount(...)` và `save(source)`):
```java
        // Increment reuse count of original itinerary atomically in database
        int updatedRows = itineraryRepository.incrementReuseCount(id);
        if (updatedRows == 0) {
            throw new ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa");
        }
        if (entityManager != null) {
            entityManager.refresh(source);
        }
```
2. **Kiểm soát chặt chẽ Persistence Context:**
   - Không gọi bất kỳ setter nào trên `source`, giữ `source` sạch (không bị Hibernate coi là dirty).
   - Gọi `entityManager.refresh(source)`: Nạp lại trạng thái thực tế vừa được cập nhật từ DB vào thực thể `source` trong session. Nhờ đó, nếu các logic tiếp theo trong cùng transaction đọc `source.getReuseCount()`, giá trị luôn đồng nhất với database mà không gây ra bất kỳ câu lệnh ghi đè nào lúc commit.
   - Kiểm tra `updatedRows == 0`: Nếu lịch trình nguồn đã bị xóa bởi giao dịch khác, ném `ResourceNotFoundException` ngay lập tức, không để quá trình clone diễn ra âm thầm.

### 2.3. File 3: `Travel_Planner/backend/src/test/resources/application.properties`
Cấu hình mở rộng connection pool của HikariCP phục vụ kiểm thử concurrency:
```properties
# Hikari connection pool for concurrency test support
spring.datasource.hikari.maximum-pool-size=25
spring.datasource.hikari.minimum-idle=5
```

---

## 3. KIỂM THỬ CONCURRENCY & BẰNG CHỨNG THỰC TẾ

### 3.1. Thiết kế bài kiểm thử Concurrency thực nghiệm
File kiểm thử: `Travel_Planner/backend/src/test/java/Travel_Planner/Travel_Planner/CloneConcurrencyAndRollbackTest.java`  
Phương thức: `testConcurrentClone_TenSimultaneousRequests_IncrementsReuseCountExactlyTen`

**Cấu hình kịch bản:**
- 10 tài khoản người dùng độc lập (`cloner_concurrent_1` đến `cloner_concurrent_10`), đều ở trạng thái `ACTIVE`.
- 1 lịch trình nguồn công khai hoàn chỉnh: có 2 ngày (`ItineraryDay`), 2 hoạt động (`Activity`), 2 địa điểm lưu (`ItineraryPlace`), `reuse_count` ban đầu = 0.
- Khởi tạo thread pool 10 worker threads song song bằng `Executors.newFixedThreadPool(10)`.
- Áp dụng kỹ thuật kích nổ đồng thời:
  - `CountDownLatch readyLatch = new CountDownLatch(10)`: Chờ toàn bộ 10 thread sẵn sàng.
  - `CountDownLatch startLatch = new CountDownLatch(1)`: Khóa tất cả các thread tại cùng một rào chắn.
  - Gọi `startLatch.countDown()` để phát tín hiệu cho cả 10 thread lao vào thực thi `cloneItinerary` tại **cùng một mili-giây**.
  - `CountDownLatch doneLatch = new CountDownLatch(10)`: Đồng bộ kết quả hoàn tất.

### 3.2. Kết quả kiểm thử thực nghiệm
Chạy lệnh kiểm thử với Maven Wrapper:
```bash
.\mvnw.cmd test -Dtest=CloneConcurrencyAndRollbackTest
```

**Bằng chứng log thực tế:**
```text
>>> Phase 5.1 Concurrency Verification PASSED: 10 concurrent clones completed in 557ms with reuse_count = 10
[INFO] Tests run: 2, Failures: 0, Errors: 0, Skipped: 0, Time elapsed: 22.34 s -- in Travel_Planner.Travel_Planner.CloneConcurrencyAndRollbackTest
[INFO] BUILD SUCCESS
```

### 3.3. Các chỉ số bất biến được xác minh sau bài test
1. `updatedSource.getReuseCount() == 10`: **CHÍNH XÁC 10/10** (Tăng từ 0 lên đúng 10, **HOÀN TOÀN KHÔNG CÓ LOST UPDATE**).
2. `itineraryRepository.count()` tăng chính xác từ 1 lên 11 (10 bản sao mới được ghi nhận độc lập trong DB).
3. Cả 10 bản sao đều mang `original_itinerary_id` trỏ đúng về ID của lịch trình nguồn.
4. Cả 10 bản sao đều sở hữu đầy đủ 2 ngày và 2 hoạt động riêng biệt, không có hiện tượng xung đột dữ liệu hay deadlock.
5. Thời gian thực thi toàn bộ 10 clone song song chỉ mất **557 ms**.

---

## 4. KẾT LUẬN

Hạng mục **Phase 5.1 — Atomic reuse_count Increment** đạt kết quả **PASS**.
- Loại bỏ hoàn toàn mô hình read-modify-write.
- Đảm bảo tính nguyên tử tuyệt đối tại tầng database.
- Được chứng minh bằng integration test đồng thời 10 thread thực tế trên cơ sở dữ liệu MySQL.

