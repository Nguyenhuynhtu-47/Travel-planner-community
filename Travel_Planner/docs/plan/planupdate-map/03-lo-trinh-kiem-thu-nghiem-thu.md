# Lộ trình, kiểm thử và nghiệm thu

## Giai đoạn 1 — plan (hoàn tất trước source)

- Đọc bốn plan hiện hữu và lần theo picker, repository, Activity form/detail screen, controller/service/adapters, entity/DTO.
- Ghi trực tiếp nguyên nhân: itinerary.location bị ghép vào query; map viewport bị gửi thành geo-bias; app default IQ và dùng Suggest, trong khi API Explorer có thể gọi Discover; LocationIQ dùng IQ search + khi cần autocomplete/ranking/two-stage logic; TomTom được trả direct nhưng UI buộc đổi nguồn.
- Ghi policy constraint TomTom về không gộp/đổi thứ tự search result; chọn một provider mỗi response. Ghi TomTom persistence/account terms là release gate chưa xác minh.
- Không sửa README theo chỉ dẫn người dùng.

## Giai đoạn 2 — backend

1. Thêm `mode=SUGGEST|SEARCH` vào route search đang có; route/controller không nhận itinerary context, lat/lon hay provider do UI chọn.
2. Chọn một provider server-side: enabled+key → TomTom; disabled/missing → LocationIQ. Không merge nguồn. Lỗi upstream TomTom không biến thành empty và không âm thầm đổi sang IQ.
3. TomTom Suggest giữ query chính xác, VN only, no origin. TomTom Discover cho submit, query chính xác, VN only, no geometry/origin/POI filter mặc định. Headers version/language/key/attributes; session UUID nhất quán.
4. Giữ Details sau user selection khi thiếu tọa độ; validate type/id/session; no extra Details sau Discover có position.
5. Giữ IQ flow khi TomTom off, không nhận picker coordinates. Giữ reverse. Bỏ nearby backend chỉ sau `rg` chứng minh không còn consumer.
6. DTO mapping giữ thứ tự TomTom, không rank/dedupe/merge TomTom. Không log token/raw payload.

## Giai đoạn 3 — Flutter

1. Bỏ truyền itinerary.location và camera coordinates khỏi Activity picker; xóa formatQueryWithContext và tests liên quan.
2. Một ô input gọi mode Suggest; keyboard/nút Search gọi mode Search; một danh sách dùng cùng widget/model; bỏ nút chuyển provider và nearby/category UI/code đã xác nhận chết.
3. Duy trì debounce 400–500ms, min 2 chars, request revision guards, state loading/empty/error/retry và một UUID/session mỗi picker.
4. Chọn result: nếu cần mới gọi Details; validate tọa độ; atomically update title/address/id/provider/marker; manual map tap clears old POI identity.
5. Activity form chỉ auto-fill tên nếu title blank hoặc còn bằng giá trị lần auto-fill trước; name đã sửa tay giữ nguyên. Không auto-fill POI name khi manual pin.
6. Activity save/edit/read dùng contract và schema hiện tại; không thêm catalog Destination; ảnh upload giữ nguyên.

## Test bắt buộc

### Backend

- Controller mode validation và query giữ Unicode; không nhận/dùng latitude/longitude/context ở search.
- TomTom enabled → duy nhất Suggest/Discover tương ứng; LocationIQ không được gọi; TomTom disabled → IQ path.
- Query `Hồ Hoàn Kiếm` gửi nguyên văn, kể cả itinerary là Đà Lạt; body chỉ query/maxResults/country VN; không origin/preferences/geometry/poiTypes.
- Suggest headers Accept JSON, vi-VN, version 3, API key header, Attributes hẹp, Session-Id UUID; query/ID/type/title/subtitles/more mapping giữ thứ tự.
- Suggest không tọa độ → Details chỉ sau choose; Discover có coords → không Details; `[lon,lat]` map đúng; reject invalid/missing coords.
- 400/403/429/5xx/timeout phản ánh đúng; không cache error as empty; key không xuất hiện log/JSON.
- LocationIQ path giữ VN filter/reverse, không nhận coordinates từ Activity picker; regression cache/ranking tests.
- Activity create/update/get: name/address/coordinates/provider/id; catalog/custom/none exclusive; user image unchanged; no provider call on save/read.

### Flutter

- Query `Hồ Hoàn Kiếm` đúng nguyên văn; itinerary location `Đà Lạt` không xuất hiện trong query/request.
- Repository URI không có provider toggle, latitude, longitude, context, bounds; Suggest vs Search mode đúng; Unicode được encode/decode chuẩn.
- Một input/list; không source switch/category chips/nearby request; không tự chọn item đầu.
- Debounce, response cũ, change query, picker close, Details/reverse stale response.
- Result thiếu coords gọi Details sau chọn; cancel/failure không giữ marker POI cũ; Discover result không gọi Details lại.
- Title trống auto-fill; chọn POI B cập nhật title auto A; sửa title thủ công không ghi đè; manual pin không gán POI cũ.
- Confirm/cancel, create/edit/reopen Activity và CARTO marker giữ đúng vị trí. Activity data test TomTom chỉ chạy khi persistence gate được xác minh; nếu chưa, kiểm tra UI và không lưu provider payload.

### Hồi quy

- Tạo/sửa itinerary, thêm ngày/hoạt động, chỉnh activity, detail map, manual pin, destination catalog, image upload, CARTO tiles và ORS route.
- Chạy backend `mvnw test`, mobile `flutter analyze`, test liên quan rồi `flutter test`; `dart format` chỉ trên file Dart đổi.

## Cổng pháp lý / phát hành

TomTom AUP công khai cấm đổi thứ tự kết quả search và combine với search services khác. Vì thế không nghiệm thu merged list IQ+TomTom nếu chưa có ngoại lệ account-specific bằng văn bản. Thiết kế một API/UI dùng một provider per response là phương án mặc định.

TomTom terms cụ thể cho quyền lưu/share POI results vào MySQL và hiển thị trên CARTO chưa xác minh theo key/account. Tới khi xác minh: không persist TomTom response data lâu dài; chỉ manual pin và dữ liệu user tự viết được phép lưu theo model hiện tại. Không tự diễn giải điều khoản thay người dùng.

TomTom pricing công bố free monthly requests/no credit card theo từng API nhưng hạn mức/billing thay đổi; kiểm tra dashboard/account. Không coi limiter RAM hay quota marketing là hard spending cap.

## Rollback

- Giữ schema/API Activity cũ, nên rollback source không cần migration.
- Có thể tắt TomTom bằng cờ hiện tại, unified API tự dùng LocationIQ.
- Nếu TomTom request parity hoặc terms có vấn đề, TomTom server flag off; giữ một ô search và manual pin hoạt động.
- Không rollback bằng cách khôi phục locationContext/viewport bias vào picker.

## Trạng thái nghiệm thu

- Đã cập nhật bốn file plan trước khi sửa source; README dự án không chỉnh trong đợt này.
- Flutter: `flutter.bat test test/location_picker_test.dart test/location_repository_test.dart` — pass (35 tests); `flutter.bat analyze` — no issues found.
- Backend: `mvnw.cmd test` — pass (250 tests, 0 failures). `LocationServiceTest` riêng — pass (39 tests).
- Chưa chạy end-to-end trên app/device với TomTom key; cấu hình thật và quyền lưu kết quả TomTom theo tài khoản chưa xác minh.
- Chưa chạy toàn bộ regression suite mobile hoặc end-to-end trên app/device với TomTom key.
