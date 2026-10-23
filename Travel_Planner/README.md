Hướng dẫn khởi chạy từng thành phần

### 1. Khởi chạy Backend (Spring Boot)

1. Mở cửa sổ dòng lệnh (Terminal/PowerShell) và cd vào thư mục `backend`:
   ```powershell
   cd Travel_Planner/backend
   ```

2. (Tùy chọn) Chạy bộ kiểm thử tự động để xác nhận toàn bộ hệ thống hoạt động:
   ```powershell
   .\mvnw.cmd test
   ```

3. Khởi động server Spring Boot:
   ```powershell
   .\mvnw.cmd spring-boot:run
   ```

- Backend sẽ khởi chạy tại: **`http://localhost:8080`**
- Kiểm tra trạng thái dịch vụ (Health Check): `http://localhost:8080/api/health`

### Dữ liệu mẫu khởi tạo (Seed Data)
- Mặc định ở môi trường phát triển (Local), backend tự động khởi tạo dữ liệu mẫu thực tế và đồng nhất (10 tài khoản thử nghiệm, 20 địa điểm, 18 lịch trình, 47 ngày, 111 hoạt động, cùng các tương tác bình luận, đánh giá, yêu thích, lưu, theo dõi, chia sẻ, tải ngoại tuyến).
- Cơ chế khởi tạo hoàn toàn **idempotent** (chạy nhiều lần không trùng lặp và bảo toàn dữ liệu hiện có).
- Xem danh sách tài khoản thử nghiệm và mật khẩu tại: [docs/ai/test-accounts.md](docs/ai/test-accounts.md).
- Để tắt tự động nạp seed data:
  ```powershell
  .\mvnw.cmd spring-boot:run -Dspring-boot.run.arguments="--app.seed.enabled=false"
  ```
---


### 2. Khởi chạy Frontend Web (Flutter Web)

1. Mở cửa sổ dòng lệnh mới và chuyển vào thư mục `frontend/web`:
   ```powershell
   cd Travel_Planner/frontend/web
   ```

2. Tải các thư viện phụ thuộc:
   ```powershell
   flutter pub get
   ```

3. Chạy ứng dụng trên trình duyệt Chrome tại cổng **`8081`**:
   ```powershell
   flutter run -d chrome --web-port=8081
   ```
---

### 3. Khởi chạy Frontend Mobile (Flutter Mobile)

1. Mở cửa sổ dòng lệnh mới và chuyển vào thư mục `frontend/mobile`:
   ```powershell
   cd Travel_Planner/frontend/mobile
   ```

2. Tải các thư viện phụ thuộc:
   ```powershell
   flutter pub get
   ```

3. Khởi chạy trên máy ảo Android hoặc thiết bị thật:
   ```powershell
   flutter run
   ```

> **Lưu ý về kết nối API trên Mobile**:
> - **Thiết bị thật**:  Chạy lần lượt các lệnh:

```powershell
adb devices
```
```powershell
adb reverse tcp:8080 tcp:8080
```

```powershell
flutter run -d RFCW8105T0H --dart-define=API_BASE_URL=http://localhost:8080
```
---
