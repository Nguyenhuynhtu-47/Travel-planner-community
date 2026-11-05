# 01. Kế hoạch backend, hợp đồng API và dữ liệu

**Toàn bộ bổ sung dưới đây là đề xuất.** Các endpoint hiện tại được đánh dấu riêng để không nhầm với API đã có.

## 1. Giữ nền nghiệp vụ hiện tại

Dùng package Travel_Planner.Travel_Planner; controller mỏng, business rule ở service, transaction cho ghi DB. Tận dụng GeocodingProvider, LocationService, LocationRateLimiter và các repository hiện có. Không đổi root package hoặc nâng framework.

Giữ API hoạt động và reverse-geocode. Không gọi upstream trong transaction ghi hoạt động. Một hoạt động dùng dữ liệu điểm đã chọn không cần gọi lại search khi lưu.

## 2. Bản đồ endpoint

| Endpoint | Tình trạng | Cách xử lý |
|---|---|---|
| GET /api/destinations?keyword=... | Đã có | Giữ nguồn catalog |
| GET /api/locations/search | Đã có, trả List | Giữ tương thích, sửa parser và limiter dùng chung |
| GET /api/locations/reverse-geocode | Đã có | Giữ; tách reverse gợi ý khỏi danh tính pin |
| GET /api/locations/nearby | Đã triển khai | Tìm POI theo category/radius; opt-in bằng `LOCATIONIQ_NEARBY_ENABLED` |
| GET /api/locations/suggestions | **Đề xuất mới** | Envelope hợp nhất catalog + online |
| GET /api/locations/discover | **Đề xuất mới** | Gợi ý POI theo category và vùng, không cần query tên |
| POST /api/itineraries/{id}/days/{dayId}/activities | Đã có | Có trường `imageUrl` tùy chọn, chỉ nhận URL Cloudinary HTTPS |
| PUT /api/itineraries/{id}/days/{dayId}/activities/{activityId} | Đã có | Giữ semantics location; ảnh có quy tắc presence riêng |
| GET /api/itineraries/{id}/days/{dayId}/route | Đã có | Giữ API, dùng resolver tọa độ chung |
| POST /api/media/images | Đã có | Tận dụng upload; mở rộng tracking asset có tương thích |
| GET /api/locations/thumbnail | Chưa làm MVP | Chỉ cân nhắc khi triển khai nguồn ảnh mở |

Không đổi endpoint search cũ từ array sang object trong một lần phát hành.

## 3. Contract tìm kiếm đề xuất

GET /api/locations/suggestions?query=lam%20vien&latitude=11.94&longitude=108.44&category=ALL&limit=10

- query: trim, 2–100 ký tự theo giới hạn hiện tại.
- limit: 1–20; giới hạn này là API ứng dụng, adapter phải clamp theo khả năng provider.
- latitude/longitude: tùy chọn nhưng phải có cả hai; hữu hạn, đúng phạm vi.
- category: ALL, ATTRACTION, FOOD, CAFE, STAY, TRANSPORT; mapping provider cấu hình ở backend.
- Không giả định mọi provider hỗ trợ các category giống nhau.
- Không thêm country filter mới trên UI nếu vẫn cố định Việt Nam ở backend; ghi rõ phạm vi MVP là Việt Nam.

Ví dụ minh họa, ID và số liệu không phải kết quả API thật:

~~~json
{
  "items": [
    {
      "key": "catalog:15",
      "source": "CATALOG",
      "destinationId": 15,
      "provider": null,
      "placeId": null,
      "name": "Quảng trường Lâm Viên",
      "formattedAddress": "Đà Lạt, Lâm Đồng",
      "latitude": 11.94,
      "longitude": 108.44,
      "category": "ATTRACTION",
      "thumbnail": null
    }
  ],
  "onlineStatus": "AVAILABLE",
  "attributions": [],
  "retryAfterSeconds": null
}
~~~

onlineStatus: AVAILABLE, DISABLED, RATE_LIMITED, UNAVAILABLE. AVAILABLE + items rỗng mới có nghĩa không có kết quả phù hợp. Nếu catalog thành công nhưng online lỗi, trả 200 kèm kết quả một phần và trạng thái. Nếu chính request vi phạm limiter của ứng dụng, trả 429 và Retry-After; request sai trả 400. Không trả HTTP 200 “thành công” cho mọi lỗi xác thực hoặc hệ thống.

attributions chứa nhãn và liên kết nguồn do server kiểm soát. Client hiển thị theo dữ liệu thực sử dụng.

discover dùng latitude, longitude, radiusMeters, category, limit; đề xuất radius 500–20.000 m, limit tối đa 20 để kiểm soát chi phí. Giá trị này là thiết kế ứng dụng cần thử nghiệm, không phải giới hạn gốc của provider. Chưa hỗ trợ pagination sâu hoặc quét toàn thành phố.

## 4. Xử lý dữ liệu tìm kiếm

Pipeline: validate → tìm catalog → cache online → quota provider → adapter → kiểm tra kết quả → chuẩn hóa → khử trùng → xếp hạng → trả attribution.

- Tọa độ null/chuỗi lỗi/NaN/Infinity/out-of-range: bỏ item, không thay bằng 0.
- Giữ phân loại gốc và category chuẩn riêng nếu cần; không mất type vì chỉ đọc class.
- Không tự tạo external ID theo timestamp. Không có ID thì key tạm chỉ dùng trong response/session; không khẳng định danh tính lâu dài.
- OSM ID phải gồm node/way/relation. provider ID không trộn namespace với Google.
- Catalog chỉ trả mục ACTIVE khi chọn mới.
- Khử trùng chắc chắn bằng ID nguồn đã biết. Với catalog thiếu external ID, không tự gộp chỉ vì tên giống; có thể giữ hai nguồn hoặc đề xuất match bằng tên/địa chỉ/khoảng cách để quản trị xác nhận.
- Không đẩy dữ liệu private activity vào suggestions cho người khác.
- Query cache gồm provider, query chuẩn hóa, ngôn ngữ, quốc gia, vùng/bias, category và limit; TTL theo chính sách nguồn.
- Gộp các cache miss cùng key đang chạy; không lưu response có lỗi thành “không có kết quả”.

Nếu cần Geoapify Places, thêm adapter với capability rõ ràng thay vì ép API nearby thành autocomplete tên. Không tự gọi cả hai provider cho mọi lần gõ.

## 5. Quy tắc lưu vị trí

MVP giữ request location hiện tại: destinationId hoặc nhóm custom; không đổi thành schema nested ở client cũ.

Bổ sung **response** locationSource và resolvedLocation. Ví dụ:

~~~json
{
  "locationSource": "MANUAL_PIN",
  "resolvedLocation": {
    "name": "Cổng phụ",
    "address": null,
    "latitude": 11.94,
    "longitude": 108.44,
    "provider": "MANUAL_PIN",
    "placeId": null
  }
}
~~~

Các trường cũ vẫn còn. Backend resolver là nơi quyết định cặp tọa độ. Mobile mới ưu tiên resolvedLocation, fallback legacy khi server chưa nâng cấp. Route gọi cùng resolver thay vì tự có một quy tắc khác.

Cần xác định provenance cho dữ liệu reverse. Không tự gắn ID của đối tượng gần nhất cho pin tùy chỉnh. Có thể bổ sung metadata nguồn địa chỉ ở bước sau nếu phải giữ cả provenance tọa độ và địa chỉ.

Với catalog bị ẩn: cho giữ destinationId cũ khi sửa các trường không liên quan; từ chối gắn mới ID ẩn. Quy tắc này là thay đổi đề xuất so với applyLocation đang kiểm tra ACTIVE mỗi lần.

## 6. Ảnh hoạt động và vòng đời asset

**MVP đã triển khai:** thêm cột `activities.image_url` và DTO `imageUrl`; mobile upload qua endpoint Cloudinary hiện có rồi lưu URL. URL được giới hạn host/path HTTPS Cloudinary. PUT thiếu hoặc null giữ ảnh cũ; chuỗi rỗng xóa ảnh riêng. Activity dùng ảnh catalog làm fallback hiển thị. Hiện chưa có bảng asset ownership/public_id, nên kiểm tra quyền tái sử dụng và dọn orphan chưa được triển khai.

Phương án dài hạn có kiểm soát, chưa thuộc MVP:

- Thêm bảng media_assets lưu id nội bộ, uploaded_by, storage_provider, storage_public_id, secure_url, media_type, size_bytes, created_at và trạng thái tạm/gắn.
- Thêm activities.cover_asset_id nullable, FK tới media_assets; mặc định null.
- Thêm activities.image_mode: AUTO hoặc NONE, mặc định AUTO. Có cover_asset_id thì dùng ảnh riêng; NONE nghĩa người dùng muốn ẩn ảnh, khác với AUTO dùng fallback.
- Destination.imageUrl hiện có giữ nguyên; chưa di chuyển toàn bộ ảnh cũ sang media_assets.
- Provider thumbnail tự động chưa persist như upload trong MVP.

POST /api/media/images vẫn trả secureUrl, thêm assetId sau khi upload thành công và ghi metadata. Profile và cover itinerary cũ vẫn đọc secureUrl; hoạt động mới gửi coverAssetId, không chấp nhận public_id bất kỳ từ client.

ActivityResponse thêm coverAssetId, imageMode và coverImage gồm url, source, attribution tùy chọn. URL được server lấy từ asset/catalog hợp lệ, không từ URL client tùy ý. source MVP là USER_UPLOAD, DESTINATION hoặc NONE.

Khi upload:
1. Xác thực, giới hạn dung lượng, kiểm tra chữ ký định dạng JPEG/PNG/WebP như service hiện tại.
2. Upload ngoài transaction DB dài.
3. Ghi media asset có owner; nếu DB lỗi sau upload, ghi nhận để xử lý orphan.
4. Khi lưu activity, kiểm tra asset thuộc người dùng hoặc có quyền tái sử dụng rõ ràng.
5. Xóa activity không xóa asset ngay; kiểm tra mọi tham chiếu trước khi thu gom.

MVP chưa cần job tự xóa: tài liệu hóa orphan và báo cáo dung lượng là chấp nhận được nếu không nhận bừa rằng lifecycle đã hoàn chỉnh. Thời gian giữ orphan đề xuất 24 giờ chỉ áp dụng sau khi job có test và theo dõi tất cả nơi dùng URL cũ. Không xóa ảnh profile/itinerary do chưa có FK trong bảng mới.

## 7. Tương thích cập nhật ảnh

Để client cũ PUT không xóa ảnh:

- Không có trường coverAssetId: giữ ảnh hiện tại.
- Có coverAssetId là số: thay ảnh sau kiểm tra quyền.
- Có coverAssetId=null: bỏ ảnh riêng.
- Không có imageMode: giữ mode khi update; mặc định AUTO khi create.
- imageMode=NONE yêu cầu coverAssetId rỗng; request xung đột trả 400.
- imageMode=AUTO + coverAssetId=null: quay về ảnh địa điểm/placeholder.

Phải dùng DTO có theo dõi presence hoặc setter/kiểu wrapper phù hợp; Java field null thông thường không phân biệt absent và explicit null. Không áp quy tắc giữ nguyên ảnh này cho location một cách âm thầm: PUT location hiện được xử lý như nhóm thay thế.

Nếu client mới chọn NONE, đồng thời gửi coverAssetId=null. Client cũ không biết trường mới vẫn tạo được hoạt động với AUTO.

## 8. Migration, triển khai và rollback

1. Sao lưu và kiểm kê schema thực; xác định MySQL version, tên cột, FK và dữ liệu bất thường.
2. Script bổ sung media_assets, cover_asset_id, image_mode; default đảm bảo bản ghi cũ tiếp tục hợp lệ.
3. Backfill mode AUTO; không sao chép hàng loạt ảnh Destination thành asset người dùng.
4. Deploy backend tương thích trước; mobile sau feature flag; web không buộc gửi trường mới.
5. Rollback UI bằng flag, giữ dữ liệu mới; không drop cột hay bảng.
6. Có thể dùng SQL migration được review; Flyway/Liquibase là quyết định kiến trúc riêng theo quy tắc repo. ddl-auto=update không thay thế migration có version.

Nếu chọn mô hình places dài hạn, đó là migration khác, không trộn vào migration ảnh MVP.

## 9. Bảo vệ hạn mức và vận hành

Limiter request người dùng chống lạm dụng và limiter provider bảo vệ tài khoản là hai tầng. Cache hit không tính upstream quota. Dùng budget trung tâm hoặc một instance có counter bền; nhiều replica cần counter chia sẻ, không giả định Bucket4j RAM giải quyết toàn cục.

Có timeout, retry hữu hạn cho lỗi tạm thời theo chính sách, không retry 429 dồn dập. Không log API key hoặc toàn bộ địa chỉ riêng. Thống kê latency, cache hit, quota còn lại, lỗi provider và số item sai bị loại.

Tiles đi trực tiếp client nên backend limiter không bảo vệ được tile quota. Phải có giới hạn tài khoản/provider, token phù hợp và trạng thái map khi hết quota. Các flag như onlineSearchEnabled, placeDiscoveryEnabled, activityImagesEnabled là **đề xuất mới**, chưa có trong cấu hình.
