# 02. Sơ đồ cấu trúc thư mục

## Cây source
    Travel_Planner/
    ├── backend/
    │   ├── src/main/java/Travel_Planner/Travel_Planner/
    │   │   ├── config/ controller/ dto/ exception/ model/
    │   │   ├── repository/ security/ seeder/ service/ util/
    │   ├── src/main/resources/application*.properties
    │   ├── src/test/java/Travel_Planner/Travel_Planner/
    │   └── pom.xml, mvnw, mvnw.cmd
    ├── frontend/
    │   ├── mobile/lib/{core,features,shared}/, test/, android/, ios/
    │   └── web/lib/{core,features,shared}/, test/, web/
    ├── docs/{ai,feedback,plan,promts}/
    ├── src/main/ (không có file trong inventory)
    ├── .env.example, README.md, DESIGN.md, HELP.md, AGENTS.md
    └── CODEBASE_GUIDE/

Bỏ khỏi cây: .git, target, build, .dart_tool, .gradle, .idea, node_modules và artifacts sinh tự động. Root src/main đang rỗng; không nhầm với backend/src/main.

## Quy mô theo source
| Phạm vi | Source | Test |
|---|---:|---:|
| Backend Java | 149 | 27 |
| Mobile Dart | 100 | 32 |
| Web Dart | 22 | 5 |
| Tổng | 271 | 64 |

## Ý nghĩa thư mục
- Backend controller nhận HTTP; service chứa rules/orchestration; repository truy cập DB; model ánh xạ JPA; dto là API contracts; security/config/exception xử lý auth/runtime/errors.
- Flutter core chứa API/network/theme/utils; features gom theo use case; shared chứa navigation/widgets chung. Feature thường có data và presentation, không phải module nào cũng có notifier/model riêng.
- Test nằm trong từng app/package. Mobile/Web là app Flutter riêng, cùng API nhưng dependency/UI độc lập.
- docs/ chứa spec, plan, feedback và nhật ký; đây là context chứ không thay implementation.

backend/.../mapper và validation rỗng; mobile core/router chỉ có .gitkeep; features/reviews rỗng. Không mô tả chúng như module hoạt động. Thêm endpoint: DTO → service → controller/security → tests → client repository/model/UI. Thêm database field cần entity, DTO, service/repository, schema strategy và tests. Thêm feature Flutter cần data/model → notifier/coordinator → screen/widgets → navigation.
