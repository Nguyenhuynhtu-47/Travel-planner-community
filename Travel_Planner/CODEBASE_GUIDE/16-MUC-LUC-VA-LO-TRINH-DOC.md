# 16 — Mục lục và lộ trình đọc

## Đọc từ đầu để hiểu toàn hệ thống

1. [Tổng quan sản phẩm và kiến trúc](01-TONG-QUAN-DU-AN.md)
2. [Sơ đồ cấu trúc thư mục](02-SO-DO-CAU-TRUC-THU-MUC.md)
3. [Backend overview](03-BACKEND-TONG-QUAN.md), sau đó tra từng Java file trong [backend file catalogue](04-BACKEND-DANH-MUC-FILE.md).
4. [Database và các quan hệ dữ liệu](05-DATABASE-VA-DU-LIEU.md).
5. [Mobile overview](06-MOBILE-TONG-QUAN.md), [feature catalogue](07-MOBILE-CHI-TIET-TUNG-FEATURE.md), rồi đọc phần liên quan: [auth/profile](07A-AUTH-TAI-KHOAN-HO-SO.md), [explore/community](07B-EXPLORE-COLLECTION-CONG-DONG.md), [itinerary/activity/map](07C-LICH-TRINH-ACTIVITY-MAP.md), [comment threads](07D-BINH-LUAN-THREAD.md), [social/profile/notifications](07E-HO-SO-XA-HOI-THONG-BAO.md), [ảnh/app shell](07F-ANH-APP-SHELL-TICH-HOP.md).
6. [Mobile core/shared/config](08-MOBILE-CORE-SHARED-CONFIG.md).
7. [Flutter Web](09-WEB-TONG-QUAN-VA-CHI-TIET.md).
8. Tests: [backend](10-BACKEND-TESTS.md), [mobile](11-MOBILE-TESTS.md), [web](12-WEB-TESTS.md).
9. [Luồng nghiệp vụ end-to-end](13-LUONG-XU-LY-CHUC-NANG.md), [cấu hình và chạy](14-CAU-HINH-VA-CHAY-DU-AN.md), [bảo trì/phát triển](15-HUONG-DAN-BAO-TRI-VA-PHAT-TRIEN.md).

## Lần theo code theo câu hỏi

- Muốn hiểu API: controller → service → repository/entity/DTO; xem mapping và security ở backend.
- Muốn sửa Flutter: screen → notifier → repository → model → API; mở test feature để hiểu hành vi mong đợi.
- Muốn đổi dữ liệu: entity → repository/service → schema thực tế và persistence test.
- Muốn sửa map: 07C → picker/repository → LocationController/provider → tests. Tách map tile, tìm kiếm POI, reverse geocoding, routing và ảnh thành các luồng độc lập.
- Muốn sửa bình luận: 07D → controller/service parent-root semantics → notifier/widget → tests.
- Muốn kiểm tra lỗi: xác minh base URL, token, provider config và log status trước khi kết luận source gây lỗi. Không ghi secrets vào log/chia sẻ.

## Giới hạn và cách dùng

Đây là bản đồ đọc source để người mới lần theo dự án, không thay thế mã nguồn. Danh mục tự trích chữ ký có thể bỏ sót khai báo đa dòng và members sinh bởi Lombok. Chưa chạy test trong lượt lập guide nên không khẳng định test đang pass. Thống kê phản ánh inventory ngày 2026-11-10; provider thực tế và secret phụ thuộc môi trường local.
