Hướng dẫn khởi chạy từng thành phần

### Cấu hình biến môi trường và bảo mật (.env)

Dự án quản lý tập trung các biến môi trường và thông tin xác thực thông qua file `.env`. Backend Spring Boot tự động nạp các biến cấu hình từ file `.env` thông qua cơ chế `spring.config.import` khi khởi chạy.

1. **Khởi tạo file `.env`:**
   Sao chép từ file mẫu `.env.example`:
   ```powershell
   Copy-Item .env.example .env
   # Hoặc nếu đang ở thư mục Travel_Planner:
   Copy-Item .env.example .env
   ```

2. **Cập nhật thông tin cấu hình:**
   Điền thông tin kết nối Database, Cloudinary, LocationIQ, OpenRouteService, TomTom... vào `.env`.
   > **Lưu ý bảo mật:** Tuyệt đối không commit file `.env` chứa credential thật vào Git (file đã được bảo vệ trong `.gitignore`).

---

### 1. Khởi chạy Backend (Spring Boot)

Backend tự động đọc thông tin xác thực từ file `.env` hoặc từ biến môi trường hệ điều hành:

1. Mở cửa sổ dòng lệnh (Terminal/PowerShell) và chuyển vào thư mục `backend`:
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

### Cấu hình upload ảnh Cloudinary
Endpoint upload yêu cầu JWT: `POST /api/media/images` với multipart field `file`.
Chấp nhận JPEG, PNG hoặc WebP tối đa 5 MiB; response chứa `secureUrl`. Backend ký trực tiếp yêu cầu upload bằng credentials từ `.env` (`CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`).

### Dữ liệu mẫu khởi tạo (Seed Data)

- Mặc định ở môi trường phát triển (Local), backend tự động khởi tạo dữ liệu mẫu thực tế và đồng nhất (10 tài khoản thử nghiệm, 20 địa điểm, 18 lịch trình, 47 ngày, 111 hoạt động, cùng các tương tác bình luận, đánh giá, yêu thích, lưu, theo dõi, chia sẻ, tải ngoại tuyến).
- Cơ chế khởi tạo hoàn toàn **idempotent** (chạy nhiều lần không trùng lặp và bảo toàn dữ liệu hiện có).
- Xem danh sách tài khoản thử nghiệm và mật khẩu tại: [docs/ai/test-accounts.md](docs/ai/test-accounts.md).
- Để tắt tự động nạp seed data:
  ```powershell
  .\mvnw.cmd spring-boot:run -Dspring-boot.run.arguments="--app.seed.enabled=false"
  ```

---

### Cấu hình CARTO Basemaps API Key (Bản đồ nền)

CARTO Basemaps yêu cầu API Key đối với các request tải raster tile (`basemaps.cartocdn.com`). Khi thiếu API Key, server CARTO trả về ảnh nền trắng kèm watermark `API KEY REQUIRED` / `TILES REQUIRED`.

- **Đăng ký API Key miễn phí:** Truy cập [https://carto.com/basemaps/apikey](https://carto.com/basemaps/apikey) để nhận API Key miễn phí (5.000.000 lượt request/tháng cho mục đích phi thương mại/học tập).
- **Cách truyền API Key:** Sử dụng tham số `--dart-define=CARTO_API_KEY=<your_api_key>` khi khởi chạy Flutter Mobile hoặc Flutter Web.
- **Phân biệt Credential:** CARTO API Key là public client key phục vụ tải tile bản đồ, **hoàn toàn độc lập** với Cloudinary credentials (`CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` dùng riêng cho backend Spring Boot ký upload ảnh). Tuyệt đối không dùng nhầm credential giữa các dịch vụ.
- **Cơ chế khi thiếu API Key:** Ứng dụng hiển thị thông báo hướng dẫn cấu hình rõ ràng, các marker địa điểm, tuyến đường, tương tác kéo/phóng to thu nhỏ vẫn hoạt động bình thường mà không bị gián đoạn.

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
   flutter run -d chrome --web-port=8081 --dart-define=CARTO_API_KEY=<your_carto_api_key>
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
   flutter run --dart-define=CARTO_API_KEY=<your_carto_api_key>
   ```

> **Lưu ý về kết nối API trên Mobile**:
>
> - **Thiết bị thật**: Chạy lần lượt các lệnh:

```powershell
adb devices
```

```powershell
adb reverse tcp:8080 tcp:8080 hoặc  & "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:8080 tcp:8080
```
