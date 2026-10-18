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
> - **Thiết bị thật**: Ứng dụng mặc định gọi máy tính phát triển tại `http://192.168.1.9:8080`. Điện thoại và máy tính cần cùng Wi-Fi; nếu IP máy tính thay đổi, chạy lại app với `flutter run --dart-define=API_BASE_URL=http://<IP-máy-tính>:8080`.
> - **Máy ảo Android (Emulator)**: Chạy `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080` (`10.0.2.2` là địa chỉ máy host bên trong Android Emulator).
> - Khi đóng gói APK, dùng cùng tham số `--dart-define=API_BASE_URL=http://<IP-máy-tính>:8080`. Cần cài lại app sau khi đổi địa chỉ API.
> - Android được cấu hình cho phép HTTP để kết nối backend phát triển trong mạng nội bộ.

---
