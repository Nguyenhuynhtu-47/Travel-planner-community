# Backend API và dữ liệu — kế hoạch refactor

## Hiện trạng đã truy vết

Trước refactor, `/api/locations/search` nhận `provider`, latitude và longitude từ client; TomTom Discover có route riêng. `LocationServiceImpl` định tuyến theo provider client hoặc LocationIQ primary, optional HERE có thể được gộp/xếp hạng cùng IQ. IQ flow còn phân tích query, two-stage area search, root-word/food fallback, locality fallback, ranking/dedup và cache 24 giờ. TomTom Suggest có thể nhận tọa độ client để gửi `origin`.

Code hiện tại dùng một `/api/locations/search` route với `mode=SUGGEST|SEARCH`. Controller không nhận provider hay search coordinates. TomTom enabled+key dùng Suggest/Discover tương ứng; nếu tắt thì IQ. Route TomTom Discover riêng đã gỡ; Details và reverse-geocode vẫn giữ.

TomTom mapping đã có `provider`, providerId/type, requiresDetails, sessionId; title/subtitles/address và position được map vào DTO. Search result TomTom không được cache backend. Details có allow-list type. Activity DB/DTO đủ cột location, không cần migration.

## Kiến trúc hợp đồng đích

### Search route thống nhất

Giữ `GET /api/locations/search`; thay lựa chọn `provider` từ client bằng `mode`:

- `query`: nguyên văn query đã trim đầu/cuối, dài 2–100 ký tự.
- `mode=SUGGEST|SEARCH`; default `SUGGEST` để tương thích autocomplete.
- `sessionId`: UUID 36 ký tự tùy chọn cho flow TomTom.
- Không nhận latitude/longitude/context từ picker.
- Backend chọn duy nhất một provider: nếu TomTom enabled và có key thì dùng TomTom; nếu TomTom tắt/không cấu hình thì dùng LocationIQ. Không gọi và ghép cả hai cho một response. Lỗi TomTom hiển thị trạng thái lỗi; không fallback âm thầm để tránh dữ liệu/ordering từ hai search service bị trộn.

Response vẫn là `List<LocationSearchResultResponse>` để giữ contract list. DTO hiện tại được mở rộng/giữ nullable: `placeId`, `name`, `formattedAddress`, `latitude`, `longitude`, `category`, `type`, `importance`, `boundingBox`, `provider`, `providerId`, `providerType`, `requiresDetails`, `sessionId`. Không thêm envelope hay model trùng.

### TomTom

- `SUGGEST`: `POST https://api.tomtom.com/maps/orbis/places/suggest`; body chỉ `{query,maxResults,filters:{countryCodesIso2:["VN"]}}`; maxResults ≤10. Headers phải có Accept JSON, language vi-VN, API version 3, key server-side, Content-Type JSON, Attributes hẹp gồm id/type/title/subtitles/more.
- `SEARCH`: `POST .../places/discover`; body chỉ query, maxResults và country filter VN; Attributes gồm id/type/title/subtitles/position/address và metadata thực sự dùng. Đây là request so sánh API Explorer, không thêm poiTypes/geometry/preferences/origin.
- `Details`: giữ route hiện tại; validate type allow-list và ID, encode path segment; gọi chỉ khi selected suggestion không có tọa độ. Lấy title/address/position/type/id.
- `discoverAction`: chuyển sang `mode=SEARCH` trên cùng route; backend tự gọi Discover. Không nhận arbitrary filter từ client và không gửi mapCenter.
- Giữ thứ tự TomTom và nội dung tên; không rank, dedupe hoặc merge với IQ. Session UUID được kiểm tra, chỉ gửi header Session-Id, không lưu DB.
- Errors 401/403, 429, 5xx/timeout phải trở thành trạng thái API rõ; không giả thành danh sách rỗng, không log key.

### LocationIQ

Giữ adapter, API key, reverse-geocode, xử lý query/cache và language hiện có. Từ luồng picker không truyền tọa độ, context, bounds hoặc viewport, do đó không tạo `viewbox`, `bounded`, lat/lon autocomplete. `countrycodes=vn` tiếp tục là giới hạn mặc định. Query của người dùng được chuyển nguyên vẹn; chỉ xử lý nội bộ hiện hữu trong chế độ LocationIQ. IQ cache 24h hiện tại thấp hơn mức request-response cache free 48h trong Terms; response data có thể được lưu theo Terms công khai.

Optional HERE hiện là secondary trong standard search. Không để HERE tham gia khi TomTom là provider đã chọn. Giữ code HERE ngoài refactor tối thiểu nếu còn được cấu hình/được test sử dụng; trước khi xóa phải xác nhận toàn bộ references. Không được để HERE/IQ ghi đè hoặc đổi thứ tự response TomTom.

### Details/Discover route

- Giữ `GET /api/locations/providers/tomtom/details?type={providerType}&id={providerId}&sessionId={uuid}`.
- Submit và discoverAction gọi `GET /api/locations/search` với `mode=SEARCH`; route TomTom Discover riêng đã xóa sau khi kiểm tra caller.
- Không tạo route mới nếu route hiện tại đáp ứng.

## Ranking, dedupe, cache và rate limit

- TomTom: giữ nguyên thứ tự endpoint; không chạy `LocationRankingService`, dedupe theo tên, hoặc hợp nhất IQ/HERE. Đây là ràng buộc từ [TomTom AUP](https://www.tomtom.com/en-gb/legal/acceptable-use-policy/), cấm đổi thứ tự kết quả search và kết hợp với dịch vụ tìm kiếm khác.
- LocationIQ: giữ ranking/cache hiện có trong phạm vi IQ-only; request không nhận itinerary coords. Cache key phải có mode/query/locale/provider để không trả nhầm Suggest/Search hoặc provider. Không cache lỗi thành empty.
- Debounce 400–500 ms và min 2 ký tự ở mobile; max 10 TomTom suggest; backend rate limiter giữ nguyên. Không thêm in-memory monthly quota giả.

## MySQL / Activity

Schema hiện tại đáp ứng: `activities.name` là tiêu đề, `custom_location_name`/`custom_address` là location, `latitude`/`longitude`, `place_id`/`location_provider`; `destination_id` dùng catalog riêng. `Itinerary.location` chỉ là chuỗi mô tả. `applyLocation` đang bảo đảm destination-vs-custom, cặp tọa độ, bounds và clear field đúng. Không insert Destination khi search, không migration, không upstream call khi save/read.

TomTom Terms account-specific chưa xác minh quyền lưu/share kết quả đã chọn. Theo yêu cầu, persistence TomTom là gate release: không ghi tên/địa chỉ/ID/coordinates TomTom lâu dài trước khi xác nhận terms của key/account. Khi gate đóng, picker vẫn có manual pin + reverse chỉ để gợi ý, người dùng nhập dữ liệu do mình xác lập; Activity.name do user viết được giữ. LocationIQ persistence theo Terms công khai hiện cho phép response data lưu lâu dài. Không áp dụng giả định đó cho TomTom.

## File backend cần sửa

| File | Hiện trạng | Thay đổi | Giữ/Xóa | Test |
|---|---|---|---|---|
| `backend/src/main/java/Travel_Planner/Travel_Planner/controller/LocationController.java` | Trước đây search nhận provider/lat/lon và có route Discover | Search unified nhận mode; Details/reverse giữ | Route Discover riêng đã xóa; nearby backend legacy còn | controller mode, params, validation, auth/rate limit |
| `.../service/LocationService.java` | overload provider + geo params; nearby | chữ ký unified query/mode/session; giữ reverse/nearby chỉ nếu call-site còn | bỏ overload cũ sau khi cập nhật mọi caller/test | AUTO provider decision, disabled config |
| `.../service/impl/LocationServiceImpl.java` | IQ/HERE two-stage and rank; TomTom explicit branch; cache | chọn một provider/mode; bỏ geo params từ activity; TomTom passthrough; cache IQ tách mode | không sửa ranking IQ ngoài mức cần thiết; bỏ cũ nếu dead | exact query, no cross-provider merge, errors, cache |
| `.../service/impl/TomTomPlacesProvider.java` | Suggest/Details/Discover, optional origin and POI filter | remove origin/poi filter from user query path; Accept; exact query; preserve order; detail only as needed | keep adapter and validation | mock upstream endpoint/body/header/DTO/error/Unicode |
| `.../controller/LocationController.java` + `.../dto/response/LocationSearchResultResponse.java` | list response plus provider metadata | stable nullable DTO; validate mode/session | no duplicate DTO | JSON contract |
| `.../config/MapProperties.java`, `backend/src/main/resources/application.properties` | TomTom flag/key/timeout | giữ server-only config, default-off; README unchanged | giữ LocationIQ settings | property binding |
| `.../service/impl/LocationIqGeocodingProvider.java` | IQ search/autocomplete, optional coordinate viewbox, reverse/nearby | giữ reverse; picker không gửi coordinates; remove only dead nearby after whole-repo reference audit | preserve free cache/language behavior | exact query, no viewbox from picker, existing provider tests |
| `.../service/impl/ItineraryServiceImpl.java`, `.../model/Activity.java`, create/update/read DTO | lưu và trả custom location | chỉ đổi nếu round-trip test phát hiện lỗi; không gọi provider ở đây | schema + image upload giữ nguyên | create/update/get and catalog/custom exclusivity |
| `backend/src/test/java/.../LocationServiceTest.java`, `TomTomPlacesProviderTest.java`, activity tests | explicit provider + nearby/ranking tests | update/add unified provider, request parity, activity tests; xóa test obsolete sau reference audit | keep unrelated geocoding/rate/routing tests | see 03 |

## Điều khoản/nguồn

- TomTom API Explorer docs cho Suggest/Discover/Details: https://docs.tomtom.com/places-search-api/documentation/places-search/suggest, https://docs.tomtom.com/places-search-api/documentation/places-search/discover, https://docs.tomtom.com/places-search-api/documentation/places-search/details.
- TomTom AUP: https://www.tomtom.com/en-gb/legal/acceptable-use-policy/ — không đổi thứ tự search result, không kết hợp với search service khác.
- TomTom pricing: https://docs.tomtom.com/pricing — free requests theo từng API/no card được công bố, quota/billing phải kiểm tra dashboard; không tuyên bố hard cap.
- LocationIQ Terms: https://api.locationiq.com/tos — free response-pair cache tới 48h; terms công bố có thể lưu response data lâu dài.
- Không xác minh được quyền persist/share TomTom theo tài khoản trong phiên rà soát; ghi release gate, không diễn giải thay hợp đồng.
