# 02. Destination và Activity: nên lưu tọa độ ở đâu?

## 1. Phân biệt ba khái niệm

- **Khu vực chuyến đi:** “Đà Lạt”, đang nằm ở Itinerary.location dạng chuỗi. Không phải ID của một địa điểm.
- **Địa điểm:** “Quảng trường Lâm Viên”, là nơi có tên, địa chỉ, tọa độ và có thể có ảnh.
- **Hoạt động:** “Chụp ảnh lúc 08:00 tại Quảng trường Lâm Viên”, có thời gian, chi phí, ghi chú, thứ tự trong ngày.

Một địa điểm có thể xuất hiện trong nhiều hoạt động và nhiều ngày. Không đặt unique cho địa điểm trong một ngày: người dùng có thể ăn sáng và ăn tối tại cùng khách sạn.

## 2. Hiện tại có trùng dữ liệu không?

| Trạng thái hiện tại | destination_id | Tọa độ Activity | Nguồn tọa độ hiển thị |
|---|---|---|---|
| Danh mục | Có | Null | Destination |
| Vị trí riêng | Null | Đủ latitude + longitude | Activity |
| Không vị trí | Null | Null | Không vẽ marker |

ItineraryServiceImpl.applyLocation đang cưỡng chế ba trạng thái trên. Vì vậy xóa latitude/longitude khỏi Activity ngay sẽ làm mất khả năng lưu điểm ngoài danh mục. Ngược lại, copy tọa độ Destination vào Activity mọi lúc sẽ tạo hai nguồn cần đồng bộ nếu chưa định nghĩa snapshot.

Ví dụ đúng:

- Activity A: “Check-in”, destination_id=15; tọa độ lấy từ Destination 15.
- Activity B: “Gặp bạn tại cổng phụ”, destination_id=null; lưu tọa độ ghim riêng.
- Activity C: “Nghỉ trưa”, không cần vị trí.

Hai bảng đều có cột tọa độ là **mô hình hợp lệ**, nhưng cách đặt tên và API hiện tại khiến người đọc khó nhận ra đó là hai nhánh loại trừ nhau.

## 3. So sánh hướng thay đổi

| Hướng | Ưu điểm | Chi phí/vấn đề | Kết luận |
|---|---|---|---|
| Giữ ba trạng thái, chuẩn hóa API đọc và UI | Ít migration, tận dụng test, thêm địa điểm nhanh | Vị trí riêng vẫn có thể lặp giữa hoạt động | **Ưu tiên cho MVP** |
| Mọi kết quả tìm kiếm tự thành Destination | Một đường FK | Làm bẩn danh mục admin; lộ địa chỉ riêng; khó phân quyền và khử trùng | Không chọn |
| Tách places dùng chung và activity_locations dạng snapshot | Rõ danh tính địa điểm và lịch sử mỗi lần ghé | Nhiều bảng, migration, vòng đời và điều khoản lưu dữ liệu | Cân nhắc khi có nhu cầu thật |
| Chỉ lưu tọa độ tại Activity, bỏ Destination | Dễ hiểu từng hoạt động | Mất danh mục dùng chung và quản trị hiện có | Không phù hợp hiện trạng |

**Quyết định đề xuất:** không đổi schema địa điểm lớn trong phiên bản đầu. Sửa quy tắc và contract trước; thêm schema ảnh độc lập. Nếu mục tiêu sau này là thư viện địa điểm cá nhân, nhiều nguồn POI hoặc lịch sử bất biến thì chuyển mô hình ở mục 6 bằng migration riêng.

## 4. Mô hình MVP nên diễn đạt rõ

Giữ các cột hiện có; bổ sung trường đọc locationSource gồm CATALOG, PROVIDER, MANUAL_PIN, NONE. Không suy luận provider chỉ từ tên địa điểm.

- CATALOG: một destination_id hợp lệ; mọi trường custom null.
- PROVIDER: không destination_id; đủ tọa độ; provider và danh tính upstream nếu có. Lưu tên/địa chỉ đã chọn theo quyền lưu của nguồn.
- MANUAL_PIN: tọa độ người dùng chọn. ID của một POI lân cận từ reverse không được tự coi là danh tính của điểm ghim.
- NONE: toàn bộ dữ liệu vị trí null; vẫn được tạo hoạt động.

Đề xuất resolvedLocation trên response để UI và route dùng cùng ngữ nghĩa. Không phối latitude của nguồn A với longitude của nguồn B. Kiểm tra số hữu hạn và phạm vi hợp lệ.

locationProvider hiện là chuỗi tùy ý có giới hạn độ dài; nâng cấp cần allowlist và phân biệt “tọa độ do ai xác định” với “địa chỉ gợi ý từ đâu”. Trong MVP có thể giữ pin là MANUAL_PIN và không gắn placeId khi reverse chỉ trả đối tượng gần nhất. Nếu lưu địa chỉ reverse lâu dài phải ghi nhận provenance tương ứng; không gắn nhãn thủ công để bỏ qua chính sách nguồn.

## 5. Quy tắc sửa, ẩn, ảnh và bản sao

- Chọn địa điểm mới thay thế toàn bộ nhóm location, không patch vài tọa độ.
- Đổi tên hoạt động không đổi tên Destination dùng chung.
- Ghim riêng không sửa Destination; chọn catalog không tự tạo bản sao tọa độ.
- Catalog được sửa: MVP giữ hành vi tham chiếu sống. UI lấy dữ liệu mới khi tải lại; route tính từ tọa độ mới.
- Destination HIDDEN: không được chọn mới. Với hoạt động đã gắn, đề xuất giữ liên kết để không phá chuyến đi; không vô tình xóa vị trí khi chỉ sửa giờ. Cần ngoại lệ validation “giữ nguyên liên kết cũ” và test riêng. Nếu ẩn vì riêng tư hoặc vi phạm nội dung, chính sách che nội dung phải được xử lý riêng; chưa suy diễn rằng mọi ảnh cũ đều được tiếp tục công khai.
- Ảnh riêng Activity không làm thay đổi ảnh Destination.
- Đổi địa điểm: ảnh tự lấy theo địa điểm phải đổi/xóa; ảnh người dùng tải lên chỉ giữ sau khi người dùng có cơ hội kiểm tra.
- Sao chép lịch trình sau này: sao chép dữ liệu activity độc lập, không nhân bản catalog. Ảnh dùng chung phải có tham chiếu an toàn, không xóa asset khi một bản sao bị xóa.
- Không dùng tên giống nhau làm điều kiện hợp nhất địa điểm. Ưu tiên namespace provider + ID; tên + khoảng cách chỉ là gợi ý cần xem lại.

## 6. Mô hình dài hạn nếu thực sự cần chuẩn hóa

~~~mermaid
erDiagram
    destinations }o--o| places : "catalog tham chieu"
    activities ||--o| activity_locations : "snapshot tuy chon"
    places ||--o{ activity_locations : "nguon tuy chon"
    places ||--o{ place_external_refs : "danh tinh theo provider"
~~~

Đây là mô hình **đề xuất về sau**, chưa phải schema sẽ tạo trong MVP:

- places: danh tính địa điểm nội bộ, nguồn dữ liệu được phép dùng, khả năng hiển thị và quản trị.
- place_external_refs: provider + external_id, unique theo namespace; phân biệt osm node/way/relation.
- destinations: lớp tuyển chọn nội dung bởi admin, có thể liên kết places.
- activity_locations: tối đa một bản ghi mỗi activity, có snapshot tên/địa chỉ/tọa độ khi chính sách nguồn cho phép, source, selected_at. place_id nội bộ có thể null cho pin riêng.
- Không bắt buộc pin nhà riêng phải xuất hiện trong places công khai.
- Nếu nguồn cấm snapshot lâu dài, dùng reference và resolver theo chính sách nguồn; không thiết kế snapshot chung rồi coi mọi provider đều hợp lệ.

Nếu áp dụng: backfill theo trạng thái cũ, kiểm kê dữ liệu mâu thuẫn, so sánh kết quả map trước/sau, chuyển đọc sau feature flag, giữ cột cũ qua ít nhất một đợt phát hành. Không drop/rename bằng ddl-auto=update và không coi một đề xuất migration là quyền thực thi trên DB.
