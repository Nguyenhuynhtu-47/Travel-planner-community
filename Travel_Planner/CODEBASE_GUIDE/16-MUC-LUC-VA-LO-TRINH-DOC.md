# 16 — Mục lục và lộ trình đọc

## Đọc từ đầu để hiểu toàn hệ thống
1. [Tổng quan dự án](01-TONG-QUAN-DU-AN.md)
2. [Cấu trúc source](02-SO-DO-CAU-TRUC-THU-MUC.md)
3. [Backend/API/security](03-BACKEND-TONG-QUAN.md), rồi tra [Java file catalogue](04-BACKEND-DANH-MUC-FILE.md).
4. [Database và dữ liệu](05-DATABASE-VA-DU-LIEU.md).
5. [Mobile overview](06-MOBILE-TONG-QUAN.md), [Dart catalogue](07-MOBILE-CHI-TIET-TUNG-FEATURE.md), các chuyên đề [07A](07A-AUTH-TAI-KHOAN-HO-SO.md)–[07F](07F-ANH-APP-SHELL-TICH-HOP.md).
6. [Mobile core/shared](08-MOBILE-CORE-SHARED-CONFIG.md) và [Flutter Web](09-WEB-TONG-QUAN-VA-CHI-TIET.md).
7. Tests: [backend](10-BACKEND-TESTS.md), [mobile](11-MOBILE-TESTS.md), [web](12-WEB-TESTS.md).
8. [Luồng end-to-end](13-LUONG-XU-LY-CHUC-NANG.md), [chạy dự án](14-CAU-HINH-VA-CHAY-DU-AN.md), [bảo trì](15-HUONG-DAN-BAO-TRI-VA-PHAT-TRIEN.md).

## Lần theo code theo câu hỏi
- API: client repository → API constant/request/response model → backend controller/DTO → security/service → repository/entity → test.
- Activity/map: 07C, lưu ý Place catalog, Activity snapshot và itinerary saved places là ba khái niệm khác nhau; mobile `getDestinations()` là legacy unused contract.
- Comment: 07D, phân biệt comments itinerary/activity và comments community post.
- Chat and notifications: 07E/13, Messaging REST/WebSocket plus separate Notification Center API, single Home bell, announcement receipts and messaging-only FCM.
- DB/startup lỗi: 05, từng runner/config/schema/log; entity không chứng minh schema thật.

## Giới hạn
Inventory cập nhật theo source tree 2026-11-17 sau khi thêm Community navigation/user discovery: backend 268 Java, mobile 133 Dart, web 27 Dart; test lần lượt 51/43/6. Số file không đo mức hoàn tất. Kết quả chạy 2026-11-17 ghi riêng trong guide test; provider, secrets, DB schema và feature flag runtime phải kiểm tra trong môi trường đang chạy; không ghi secrets vào guide.
