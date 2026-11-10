# 07D — Bình luận và reply

CommentsRepository tải trang root, reply riêng, tạo/sửa/xóa; CommentsNotifier giữ pagination độc lập và gửi parentCommentId khi trả lời. Widget section/thread/composer điều khiển mở/thu gọn, trạng thái đang trả lời và cập nhật UI.

Backend CommentThreadController và CommentServiceImpl lưu parent trực tiếp, đồng thời xác định root để gom thread. Service kiểm tra parent cùng itinerary/activity, target có thể đọc và user còn hoạt động. Xóa mềm giữ placeholder khi có reply. Không tải cây comment đầy đủ rồi phân trang tại client; phân trang root và replies phải độc lập.

Khi đổi cấu trúc phải giữ đúng scope activity/itinerary, thứ tự, dedupe khi tải thêm, quyền đọc itinerary riêng tư và thread còn đọc được khi root bị xóa. Test: comment_thread_widget_test, comments_notifier_test, CommentThreadServiceTest, ActivityCommentPreservationTest.
