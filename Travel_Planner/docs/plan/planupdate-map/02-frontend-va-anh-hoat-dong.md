# 02. Kế hoạch frontend và ảnh hoạt động

Trạng thái: MVP mobile/backend đang được triển khai theo các mục tương ứng. LocationIQ search giới hạn Việt Nam và nhận ngữ cảnh `itinerary.location`; nearby có filter và ảnh upload Cloudinary đã nối. Phần tìm kiếm catalog + online hợp nhất, assetId/ownership và tích hợp map tổng vào ngày vẫn là công việc tiếp theo. Không tạo thêm ứng dụng web mới hoặc đưa React vào dự án Flutter.

## 1. Danh sách file cần tác động

| Khu vực | File hiện có | Thay đổi dự kiến |
|---|---|---|
| Model search | features/location/data/models/location_search_result.dart | Giữ legacy; thêm model suggestion/envelope riêng |
| Repository | features/location/data/location_repository.dart | Thêm suggestions/discover, context, lỗi một phần |
| Picker | features/location/presentation/widgets/location_picker_sheet.dart | Search thống nhất, category, context, state đúng |
| Form | features/itinerary/presentation/widgets/activity_form_dialog.dart | Chọn địa điểm là thao tác chính; tên gợi ý; ảnh |
| Request activity | features/itinerary/data/models/create_activity_request.dart và update_activity_request.dart | Trường ảnh với absent/null rõ ràng |
| Response activity | features/itinerary/data/models/activity_detail.dart | resolvedLocation, locationSource, coverImage |
| API ghi | features/itinerary/data/itinerary_crud_repository.dart | Truyền contract mới, tương thích legacy |
| Timeline | features/itinerary/presentation/widgets/activity_timeline_item.dart | Thumbnail hoạt động dùng chung các nguồn |
| Map | features/itinerary/presentation/screens/itinerary_map_screen.dart | Thêm địa điểm vào ngày, chọn activity, refresh đúng |
| Helper | itinerary_map_helper.dart; itinerary_map_preview_card.dart | Chung quy tắc vị trí, tọa độ thật và marker |
| Ảnh | shared/services/image_picker_service.dart; shared/widgets/image_upload_preview.dart | Tái sử dụng chọn/preview, nối assetId |
| Tile | core/constants/map_tile_provider_config.dart; map_constants.dart; shared/widgets/app_base_map.dart | Chỉ đổi cấu hình nếu nhà cung cấp được chốt |
| Web admin | frontend/web/lib/features/locations và shared/widgets/web_map_view.dart | Kiểm tra tương thích, attribution và hidden catalog |

Các đường dẫn không có prefix thuộc frontend/mobile/lib/. Chỉ tách widget/controller mới khi giúp giảm độ lớn của picker/form hiện tại; tránh xây một kiến trúc state management mới cho một tính năng.

## 2. State của picker

Tách tối thiểu:

- viewportCenter: nơi camera nhìn, không phải lựa chọn.
- query và category: nội dung tìm.
- searchState: idle/loading/data/empty/partial/error.
- selectedLocation: một đối tượng nguyên khối gồm source, tên, địa chỉ, cặp tọa độ, ID.
- selectionRevision: thay đổi khi chọn item/ghim/xóa/đóng.
- searchRevision: thay đổi ngay khi text/filter/context thay đổi.
- imageDraft: file mới, asset đã upload, ảnh tự động hoặc NONE.

Không giữ rời rạc tên của địa điểm mới với tọa độ cũ. Dùng đối tượng immutable để thay nguyên bộ selectedLocation.

## 3. Sửa race condition trước khi thêm UI

Khi người dùng nhập ký tự:

1. Tăng searchRevision ngay lập tức và hủy timer cũ.
2. Nếu query ngắn hơn hai ký tự: dọn kết quả, giữ selectedLocation trừ khi người dùng chủ động bỏ chọn.
3. Timer 400 ms giữ revision hiện tại.
4. Trước và sau request, kiểm tra mounted/revision/query/context.
5. Chỉ kết quả tương ứng revision mới được cập nhật.

Khi chọn item: hủy timer, tăng searchRevision và selectionRevision, vô hiệu hóa reverse cũ, xác nhận cặp tọa độ rồi thay selectedLocation nguyên khối.

Khi ghim: tăng selectionRevision, đặt tọa độ ghim ngay, metadata tạm; reverse có revision và tọa độ đã chụp. Chỉ áp tên/địa chỉ khi revision vẫn khớp. Không đổi tọa độ ghim theo tọa độ tâm đường hoặc tòa nhà do reverse trả về.

Khi xóa/đóng/dispose: vô hiệu hóa mọi callback; dispose controller. Có thể hủy HTTP nếu client hỗ trợ nhưng generation guard vẫn bắt buộc.

Kết quả thiếu tọa độ không được giữ điểm cũ hoặc fallback (0,0). Vô hiệu hóa chọn và gợi ý xác nhận vị trí thủ công.

## 4. Thêm địa điểm từ map hoặc từ ngày

Search hoạt động nhận `itinerary.location` làm ngữ cảnh tỉnh/thành. Ví dụ lịch trình có địa điểm “Hà Nội”, khi người dùng gõ “Hồ Hoàn Kiếm”, query gửi đến backend là “Hồ Hoàn Kiếm, Hà Nội”; backend giữ `countrycodes=vn` khi gọi LocationIQ. Ngữ cảnh chỉ bias kết quả, không bảo đảm lọc cứng theo địa giới hành chính.

Cùng một luồng chọn cho hai điểm vào:

- Từ ngày: đã biết dayId; chọn xong mở form tối giản với địa điểm.
- Từ map tổng: chọn ngày đích trước khi commit. Không tự chọn “ngày 1” khi đang xem tất cả.
- Chọn địa điểm tự điền tên hoạt động nếu tên trống hoặc còn là tên tự sinh; không ghi đè tên người dùng đã sửa.
- Giờ, chi phí, ghi chú và ảnh là tùy chọn; giữ validation thời gian/chi phí hiện có.
- Chặn double submit khi POST đang chạy.
- Hủy picker không thay đổi dữ liệu form trước đó.
- Tìm thấy cùng địa điểm đã có trong ngày: gợi ý “Đã có trong ngày này”, vẫn cho thêm một lần ghé khác.

Tách chọn khu vực khỏi chọn điểm. Không cần xin GPS để lập kế hoạch đến một thành phố khác.

## 5. Quy trình ảnh

1. Người dùng chọn file bằng service có sẵn.
2. Kiểm tra sơ bộ dung lượng/định dạng, preview.
3. Upload khi xác nhận form hoặc bằng hành động upload rõ ràng; không tải lại mỗi lần widget rebuild.
4. Nhận secureUrl + assetId; lưu assetId trong request activity.
5. Lưu activity; nếu lỗi giữ assetId để người dùng thử lại, tránh upload trùng.
6. Nếu bỏ form sau upload: asset tạm được xử lý theo chính sách orphan của backend.

ImageSource UI: USER_UPLOAD, DESTINATION, OPEN_LICENSE (sau này), NONE. source trả từ backend; không cho client tự nhận nguồn “Google” hay “đã cấp phép”.

Hiển thị dùng một component thumbnail: kích thước ổn định, loading/error placeholder, semantic label. Thumbnail timeline không cần gallery. Ảnh upload không làm điều kiện bắt buộc tạo hoạt động.

Nếu bổ sung Commons sau này, chỉ gọi lấy ảnh sau khi người dùng chọn địa điểm hoặc mở chi tiết, không gọi cho mọi gợi ý theo từng ký tự. Metadata license phải đi cùng ảnh; khi không xác minh được thì bỏ ảnh tự động.

## 6. Đồng bộ timeline, map và route

- Sau create/update/delete/reorder: lấy dữ liệu chuẩn từ server hoặc cập nhật notifier nhất quán.
- Giữ selectedActivityId nếu activity còn tồn tại; xóa selection khi bị xóa.
- Cache client dùng dayId + mode + revision/tọa độ theo thứ tự, không chỉ dayNumber.
- Đổi tên/ảnh không buộc gọi ORS nếu tọa độ và thứ tự không đổi; nội dung thẻ phải cập nhật.
- Đổi tọa độ/thứ tự/ngày: invalidate tuyến bị ảnh hưởng.
- Request tuyến theo ngày có generation riêng hoặc một generation cho lần tải snapshot toàn bộ; tránh request ngày B vô tình làm ngày A treo loading.
- Route server giữ kiểm tra quyền trước cache; không dùng route cache để trả thông tin lịch trình riêng tư.
- Đường thẳng fallback được gắn nhãn ước lượng, không hiển thị ETA giả.
- Chỉ dùng tọa độ thật cho lưu/route/navigation; tọa độ giãn marker chỉ ở lớp vẽ.

## 7. Giao diện theo thiết kế dự án

Dùng Theme/AppColors và widget chung; ảnh nhỏ, khoảng trắng đủ, không lặp nhiều card lồng nhau. Primary CTA rõ “Thêm vào ngày …” hoặc “Lưu thay đổi”.

Search cập nhật trực tiếp, không layout animation. Sheet dùng motion nhẹ Flutter-native, tắt khi disableAnimations. Không thêm package animation. Tất cả hit area >=48 dp, kiểm tra 320 px, bàn phím, text scale và tên dài.

Web admin giữ bảng địa điểm, ảnh, trạng thái, form và map. Không cần làm màn timeline cho web trong MVP. Nếu thay tile, kiểm tra CORS, token public và attribution của cả web/mobile.

Thông báo người dùng không chứa key, tên biến môi trường hoặc câu lệnh cấu hình. Cấu hình thiếu được ghi log phù hợp cho lập trình viên và hiện thông báo dễ hiểu trong UI.

## 8. Tương thích client cũ

Mobile mới chỉ dùng suggestions nếu backend hỗ trợ; feature flag triển khai sau backend. Không fallback sang endpoint cũ cho mọi lỗi, vì 401/429/503 cần xử lý đúng. Fallback legacy chỉ khi xác định server cũ/flag tắt.

Ảnh: serializer phân biệt không gửi và gửi null theo contract. Response thiếu resolvedLocation/coverImage được đọc bằng dữ liệu cũ. Không ép cập nhật app chỉ vì backend thêm trường tùy chọn.
