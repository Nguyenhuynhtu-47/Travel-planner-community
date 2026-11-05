# 03. Chọn API miễn phí và nguồn ảnh địa điểm

Ngày đối chiếu nguồn: **05/11/2026**. Hạn mức là thông tin tại thời điểm đọc, không phải cam kết vĩnh viễn; cần đối chiếu dashboard tài khoản trước khi bật tích hợp.

## 1. “Giống Google Maps” có hai cách hiểu

**Giống cách sử dụng:** gõ tên, thấy gợi ý, chọn POI, xem vị trí và thêm vào ngày. Có thể xây bằng dữ liệu mở và các gói miễn phí.

**Giống kho dữ liệu Google:** cùng mức phủ cửa hàng, ảnh, đánh giá, giờ mở cửa và xếp hạng. Không thể hứa đạt mức này chỉ bằng cách thay một API miễn phí. Độ phủ tiếng Việt phải đo thực tế.

Mục tiêu của đề xuất là trải nghiệm tìm địa điểm thuận tiện, chi phí trong hạn mức và không tự nâng gói.

## 2. Các lớp dịch vụ phải chọn riêng

| Lớp | Hiện có | Đề xuất |
|---|---|---|
| Vẽ map | flutter_map | Giữ |
| Tile nền | CARTO Voyager mặc định | Xác minh quyền tài khoản; Geoapify tiles là ứng viên thay nếu chưa có quyền CARTO |
| Tìm tên/địa chỉ | LocationIQ | Giữ để cải thiện MVP |
| Gợi ý nhóm POI | Chưa có luồng riêng | Thử Nearby của LocationIQ nếu tài khoản cho phép; đánh giá Geoapify Places nếu không đủ |
| Tuyến đường | OpenRouteService | Giữ, kiểm tra quota thực của tài khoản trước phát hành |
| Ảnh | Cloudinary upload, ảnh catalog | Thêm ảnh riêng hoạt động; ảnh mở là tùy chọn sau |
| Chỉ đường ngoài app | Google/Apple Maps launcher | Giữ |

Miễn phí SDK không có nghĩa miễn phí tile, geocoding hoặc ảnh. Cloudinary hiện có tích hợp nhưng quota dung lượng, biến đổi và băng thông của tài khoản chưa được kiểm tra trong phiên này.

## 3. So sánh lựa chọn chính

| Dịch vụ | Điểm phù hợp | Giới hạn cần hiểu | Khuyến nghị |
|---|---|---|---|
| LocationIQ | Đã tích hợp; autocomplete và reverse | Free 5.000 request/ngày, 2/giây, 60/phút; cần attribution | Dùng trước để giảm công đổi |
| Geoapify | Autocomplete, POI theo category/vùng, tiles | Free 3.000 credit/ngày, tối đa 5 request/giây; không phải 3.000 lượt cho từng API | Thử nghiệm POI hoặc thay tile |
| Google Places/Photos | Dữ liệu địa điểm và ảnh trong cùng hệ sinh thái | Billing, SKU riêng, quy định hiển thị/lưu trữ | Không mặc định cho yêu cầu không phát sinh phí |
| Nominatim công cộng | Tra cứu có giới hạn | Không cho client autocomplete; giới hạn tối đa 1 request/giây | Không dùng làm search-as-you-type hoặc fallback tự động |
| OSM tự vận hành | Kiểm soát hạ tầng và dữ liệu | Tốn máy chủ, nhập/cập nhật dữ liệu, vận hành | Chưa cần cho đồ án |

Nguồn hạn mức: [LocationIQ Pricing](https://locationiq.com/pricing/), [Geoapify Pricing](https://www.geoapify.com/pricing/), [Nominatim Usage Policy](https://operations.osmfoundation.org/policies/nominatim/).

Geoapify không cần thẻ cho Free; attribution cho dịch vụ và dữ liệu nguồn vẫn bắt buộc. Trong cách tính credit đã công bố, autocomplete/reverse thường một credit, tile 0,25 credit và Places với limit tối đa 20 là một credit. Vì vậy dùng tiles và POI cùng tài khoản phải cộng chung ngân sách. [Chi tiết credit](https://www.geoapify.com/pricing-details/).

Ví dụ giả định: 60 phiên/ngày × (12 truy vấn + 2 reverse + 2 gợi ý nhóm + 80 tile × 0,25) = 2.160 credit/ngày. Đây là mô hình tải do dự án đặt ra, không phải đo đạc thật hoặc bảo đảm 60 người dùng luôn đủ quota.

## 4. LocationIQ: lưu hoạt động khác cache tìm kiếm

Tài liệu hỗ trợ của LocationIQ phân biệt lưu output lâu dài với cache các cặp request–response để tránh gọi API. Free cho cache tối đa 48 giờ. Cache tìm kiếm 24 giờ đang có phù hợp với giới hạn này; dữ liệu đã chọn lưu trong hoạt động không phải tự động hết hạn sau 48 giờ. [Quyền lưu output](https://help.locationiq.com/support/solutions/articles/36000216111-can-i-save-addresses-from-api-output-), [Giới hạn cache](https://help.locationiq.com/support/solutions/articles/36000216698-can-i-cache-the-results-).

Thiết kế vận dụng:

- Chỉ lưu điểm người dùng thật sự chọn cho lịch trình.
- Không gom mọi truy vấn thành kho POI rồi dùng để thay thế dịch vụ tìm kiếm.
- Đặt TTL theo provider; không áp một TTL toàn hệ thống cho ảnh, routes và địa chỉ.
- Giữ ghi nguồn “Search by LocationIQ.com” tại nơi dùng kết quả theo yêu cầu gói Free.
- Giữ ID có namespace; ID OSM khác Google place_id.

Autocomplete hỗ trợ tìm gợi ý; cần đối chiếu filter/bias trong tài liệu đúng endpoint. Không coi tham số có cùng tên ở reverse và autocomplete là cùng ý nghĩa. [Hướng dẫn](https://docs.locationiq.com/docs/autocomplete), [Tham chiếu endpoint](https://docs.locationiq.com/reference/autocomplete-2).

## 5. Google có miễn phí được không?

Có hạn mức miễn phí theo SKU, nhưng Places yêu cầu cấu hình billing; tìm kiếm, details và ảnh không phải một lượt gọi chung miễn phí. Không lấy ưu đãi trial làm nền tảng lâu dài. Xem [Usage and Billing](https://developers.google.com/maps/documentation/places/web-service/usage-and-billing) và [bảng giá chính thức](https://developers.google.com/maps/billing-and-pricing/pricing).

Google Places giới hạn việc lưu/cache nội dung; place ID được ngoại lệ lưu lâu dài. Kết quả Places hiển thị trên map phải dùng Google Map; dùng dữ liệu không kèm map có yêu cầu attribution riêng. Vì vậy không đề xuất lấy Google POI rồi mặc nhiên vẽ trên CARTO/OSM. [Chính sách Places](https://developers.google.com/maps/documentation/places/web-service/policies).

Ảnh Google cần lấy photo resource từ Details/Search, tải qua Place Photos và hiển thị authorAttributions khi được yêu cầu. Photo name có thể hết hạn và không nên coi URL/resource là ảnh bìa vĩnh viễn. Không tải hàng loạt hoặc chuyển ảnh Google lên Cloudinary thành tài sản của ứng dụng. [Place Photos](https://developers.google.com/maps/documentation/places/web-service/place-photos).

Nếu sau này chọn Google, phải thiết kế riêng theo điều khoản áp dụng cho tài khoản, field mask, session, quota và attribution. Cảnh báo ngân sách không tự ngắt chi tiêu. [Quản lý chi phí](https://developers.google.com/maps/billing-and-pricing/manage-costs).

Nút mở Google Maps để chỉ đường là việc khác: Maps URLs không cần API key; nó mở ứng dụng/trình duyệt, không trả bộ kết quả tìm kiếm và ảnh về app. [Maps URLs](https://developers.google.com/maps/documentation/urls/get-started).

## 6. Ảnh đại diện nên làm thế nào?

Thứ tự ưu tiên đề xuất:

1. Ảnh người dùng chọn cho chính hoạt động.
2. Ảnh Destination đã có và được phép sử dụng.
3. Ảnh từ nguồn mở được khớp đúng địa điểm và đủ metadata giấy phép.
4. Placeholder theo loại địa điểm.

Ảnh mở không bảo đảm có cho mọi POI. Có thể dùng liên kết Wikidata/Wikipedia/Commons từ dữ liệu địa điểm, rồi lấy ảnh có giấy phép phù hợp. Không tự chọn ảnh bằng tên trùng và gắn cho cửa hàng khác. Với Commons, cần kiểm tra giấy phép từng file, tác giả, nguồn, yêu cầu ghi công và điều kiện khi chỉnh sửa. [Hướng dẫn tái sử dụng Commons](https://commons.wikimedia.org/wiki/Commons:Reusing_content_outside_Wikimedia).

Giai đoạn đầu chỉ upload và ảnh catalog đã đủ giải quyết yêu cầu ảnh hoạt động. Ảnh tự động là bổ sung, không phải điều kiện để lưu hoạt động.

## 7. CARTO và OSM: cần sửa giả định trong plan cũ

Tài liệu CARTO hiện nêu sử dụng thương mại cần Enterprise license; phi thương mại miễn phí dành cho grantees. Không có cơ sở lấy các con số 5 triệu/1 triệu tile trong plan cũ làm quota miễn phí hiện hành cho mọi tài khoản. Cần kiểm tra grant/license và endpoint raster đang dùng. [CARTO Basemaps FAQ](https://docs.carto.com/faqs/carto-basemaps).

OSM có dữ liệu mở nhưng máy chủ tile công cộng có chính sách riêng, không SLA, không cho bulk download/prefetch. Không có lệnh cấm tuyệt đối mọi production app trong chính sách; việc dự án không dùng làm fallback production là lựa chọn vận hành thận trọng. Khi web dùng máy chủ công cộng, chính sách xét Referer và User-Agent trình duyệt, không yêu cầu giả mạo User-Agent. [OSM Tile Policy](https://operations.osmfoundation.org/policies/tiles/).

## 8. Cách giữ mục tiêu không phát sinh phí

- Chỉ bật Free/grant đã xác minh, không bật overage hoặc gói trả phí tự động.
- Đặt ngân sách provider có dự phòng, giới hạn giây/phút/ngày và ngắt gọi khi hết.
- Không đổi sang provider trả phí khi lỗi.
- Search lỗi: còn danh mục nội bộ, nhập tọa độ hoặc hoạt động không vị trí.
- Tile lỗi: giữ danh sách và dữ liệu; không nói bản đồ offline đầy đủ nếu chưa tải bản đồ hợp lệ.
- Route lỗi: đường nối ước lượng phải có nhãn; không trình bày thời gian giả như ETA thật.
- Khóa backend không đưa vào Flutter; tile token công khai phải hạn chế phạm vi theo khả năng provider.
- Chưa có số liệu thực về chất lượng POI Việt Nam; chạy benchmark trước quyết định thay LocationIQ.
