# 02. Sơ đồ cấu trúc thư mục

## Cây source
    Travel_Planner/
    ├── backend/src/main/java/Travel_Planner/Travel_Planner/
    │   ├── config/ controller/ dto/ exception/ model/
    │   ├── repository/ security/ seeder/ service/ util/
    │   ├── resolver/ và các package con
    │   ├── src/main/resources/{application*.properties,db/...}
    │   └── src/test/java/Travel_Planner/Travel_Planner/
    ├── frontend/mobile/{lib/{core,features,shared},test,android,ios}/
    ├── frontend/web/{lib/{core,features,shared},test,web}/
    ├── docs/{ai,architecture,feedback,plan,promts}/
    ├── CODEBASE_GUIDE/
    └── README.md, DESIGN.md, AGENTS.md, .env.example

Bỏ khỏi cây: `.git`, `target`, `build`, `.dart_tool`, `.gradle`, `.idea` và file sinh tự động. Root `src/main` nếu tồn tại không phải backend entry point.

## Quy mô theo source (2026-11-16)
| Phạm vi | Source | Test |
|---|---:|---:|
| Backend Java | 265 | 50 |
| Mobile Dart | 128 | 42 |
| Web Dart | 27 | 6 |
| Tổng | 420 | 98 |

## Ý nghĩa thư mục
- Backend `controller` định tuyến HTTP; `service` xử lý nghiệp vụ/provider; `repository` truy vấn; `model` ánh xạ JPA; `dto` định nghĩa hợp đồng; `security`, `config`, `exception` xử lý runtime/auth/lỗi. Có các runner khởi động phục vụ nâng cấp dữ liệu cũ; không đồng nhất chúng với Flyway/Liquibase.
- Mobile `core` chứa API/network/theme; `features` theo use case; `shared` chứa shell/widgets dùng chung. Phần lớn state đi qua notifier/repository và `ChangeNotifier`.
- Web dùng chung backend nhưng có thư mục source và client riêng. Directory tồn tại không bảo đảm feature đã hoàn thiện; kiểm tra `main.dart`, routes và implementation.
- `docs` và `CODEBASE_GUIDE` giải thích thiết kế, không thay source hay schema đang chạy.

Với thay đổi API, lần theo DTO → controller/security → service/repository/entity → backend tests, rồi mobile API constant → repository/model → state/widget → mobile test. Xác minh cả request lẫn response; tên endpoint cũ trong client có thể là dead code.
