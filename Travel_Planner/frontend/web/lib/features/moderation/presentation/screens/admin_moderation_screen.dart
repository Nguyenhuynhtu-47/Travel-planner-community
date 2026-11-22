import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/models/admin_media_asset_model.dart';
import '../../data/models/admin_post_model.dart';
import '../../data/models/admin_post_report_model.dart';
import '../../data/moderation_repository.dart';

class AdminModerationScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final ModerationRepository? repository;

  const AdminModerationScreen({
    super.key,
    required this.authNotifier,
    this.repository,
  });

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen>
    with SingleTickerProviderStateMixin {
  late final ModerationRepository _repository;
  late final TabController _tabController;

  bool _loadingPosts = false;
  List<AdminPostModel> _posts = [];
  String _postStatusFilter = 'ALL';

  bool _loadingReports = false;
  List<AdminPostReportModel> _reports = [];
  String _reportStatusFilter = 'PENDING';

  bool _loadingMedia = false;
  List<AdminMediaAssetModel> _mediaAssets = [];
  String _mediaStatusFilter = 'ALL';
  bool _deadLetterOnly = false;

  String? _token;

  bool get isAdmin {
    final role =
        widget.authNotifier.currentUser?['role']?.toString().toUpperCase();
    return role == 'ADMIN';
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ModerationRepository();
    _tabController = TabController(length: 3, vsync: this);
    _token = widget.authNotifier.token;

    if (isAdmin) {
      _loadPosts();
      _loadReports();
      _loadMediaAssets();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _resolveImageUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return '${ApiConstants.baseUrl}$trimmed';
    }
    return '${ApiConstants.baseUrl}/$trimmed';
  }

  String _errorMessage(dynamic error, String fallback) {
    if (error is ApiException) {
      return error.message.isNotEmpty ? error.message : fallback;
    }
    return fallback;
  }

  Future<void> _loadPosts() async {
    if (_token == null) return;
    setState(() => _loadingPosts = true);
    try {
      final statusParam = _postStatusFilter == 'ALL' ? null : _postStatusFilter;
      final res = await _repository.getPosts(
        status: statusParam,
        token: _token!,
      );
      if (mounted) setState(() => _posts = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage(e, 'Không thể tải danh sách bài viết')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _loadReports() async {
    if (_token == null) return;
    setState(() => _loadingReports = true);
    try {
      final statusParam =
          _reportStatusFilter == 'ALL' ? null : _reportStatusFilter;
      final res = await _repository.getReports(
        status: statusParam,
        token: _token!,
      );
      if (mounted) setState(() => _reports = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage(e, 'Không thể tải danh sách báo cáo')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingReports = false);
    }
  }

  Future<void> _loadMediaAssets() async {
    if (_token == null) return;
    setState(() => _loadingMedia = true);
    try {
      final statusParam =
          _mediaStatusFilter == 'ALL' ? null : _mediaStatusFilter;
      final res = await _repository.getMediaAssets(
        status: statusParam,
        deadLetterOnly: _deadLetterOnly,
        token: _token!,
      );
      if (mounted) setState(() => _mediaAssets = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage(
                e, 'Không thể tải danh sách tài nguyên media')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMedia = false);
    }
  }

  Future<void> _moderatePost(int postId, String targetStatus) async {
    String? reason;
    if (targetStatus == 'HIDDEN') {
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ẩn bài viết vi phạm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nhập lý do ẩn bài viết (tùy chọn):'),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLength: 255,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'VD: Vi phạm tiêu chuẩn cộng đồng...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xác nhận ẩn'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      reason = controller.text;
    }

    try {
      await _repository.moderatePost(
        postId,
        status: targetStatus,
        reason: reason,
        token: _token!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(targetStatus == 'HIDDEN'
                ? 'Đã ẩn bài viết thành công'
                : 'Đã khôi phục bài viết thành công'),
          ),
        );
        _loadPosts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(e, 'Thao tác thất bại'))),
        );
      }
    }
  }

  Future<void> _purgePost(int postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CẢNH BÁO: XÓA VĨNH VIỄN'),
        content: const Text(
          'Hành động này sẽ xóa vĩnh viễn bài viết khỏi hệ thống và chuyển toàn bộ '
          'ảnh đính kèm sang trạng thái DELETING để xóa trên Cloudinary. '
          'Thao tác KHÔNG thể hoàn tác. Bạn có chắc chắn muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa vĩnh viễn',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _repository.purgePost(postId, token: _token!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa vĩnh viễn bài viết')),
        );
        _loadPosts();
        _loadMediaAssets();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(e, 'Không thể xóa bài viết'))),
        );
      }
    }
  }

  Future<void> _resolveReport(int reportId, String status) async {
    try {
      await _repository.resolveReport(reportId, status: status, token: _token!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'RESOLVED'
                ? 'Đã đánh dấu xử lý vi phạm'
                : 'Đã bỏ qua báo cáo'),
          ),
        );
        _loadReports();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_errorMessage(e, 'Không thể cập nhật báo cáo'))),
        );
      }
    }
  }

  Future<void> _retryMedia(int mediaAssetId) async {
    try {
      await _repository.retryMediaAsset(mediaAssetId, token: _token!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã yêu cầu thử lại xóa media asset')),
        );
        _loadMediaAssets();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(e, 'Không thể retry xóa media'))),
        );
      }
    }
  }

  void _showPostDetailDialog(AdminPostModel post) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text('Chi tiết bài viết #${post.postId}'),
            const Spacer(),
            _buildStatusChip(post.status),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Author Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      backgroundImage: post.author.avatar != null &&
                              post.author.avatar!.isNotEmpty
                          ? NetworkImage(_resolveImageUrl(post.author.avatar!))
                          : null,
                      child: post.author.avatar == null ||
                              post.author.avatar!.isEmpty
                          ? const Icon(Icons.person, color: AppColors.primary)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.author.displayName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            '@${post.author.handle} (User ID: ${post.author.userId})',
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(post.visibility,
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Content
                const Text('Nội dung:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: SelectableText(
                    post.content.isNotEmpty
                        ? post.content
                        : '(Không có văn bản)',
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),

                // Attached Media
                if (post.mediaUrls.isNotEmpty) ...[
                  Text('Hình ảnh đính kèm (${post.mediaUrls.length}):',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: post.mediaUrls.map((url) {
                      final fullUrl = _resolveImageUrl(url);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () {
                            showDialog<void>(
                              context: ctx,
                              builder: (_) => Dialog(
                                child: Image.network(
                                  fullUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Padding(
                                    padding: EdgeInsets.all(32),
                                    child: Icon(Icons.broken_image, size: 60),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Image.network(
                            fullUrl,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            loadingBuilder: (c, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey.shade100,
                                child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image,
                                  color: Colors.grey),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Metadata & Stats
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text('Lượt thích: ${post.likeCount}',
                        style: const TextStyle(fontSize: 13)),
                    Text('Bình luận: ${post.commentCount}',
                        style: const TextStyle(fontSize: 13)),
                    Text(
                        'Ngày tạo: ${post.createdAt.day}/${post.createdAt.month}/${post.createdAt.year} ${post.createdAt.hour}:${post.createdAt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                  ],
                ),

                // Moderation Reason (if any)
                if (post.moderationReason != null &&
                    post.moderationReason!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      'Lý do kiểm duyệt: ${post.moderationReason}',
                      style: TextStyle(
                          color: Colors.orange.shade900, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (post.status == 'ACTIVE')
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                Navigator.pop(ctx);
                _moderatePost(post.postId, 'HIDDEN');
              },
              child: const Text('Ẩn bài viết',
                  style: TextStyle(color: Colors.white)),
            )
          else if (post.status == 'HIDDEN')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                Navigator.pop(ctx);
                _moderatePost(post.postId, 'ACTIVE');
              },
              child: const Text('Khôi phục bài viết',
                  style: TextStyle(color: Colors.white)),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _purgePost(post.postId);
            },
            child: const Text('Xóa vĩnh viễn',
                style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showReportDetailDialog(AdminPostReportModel report) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text('Chi tiết báo cáo #${report.reportId}'),
            const Spacer(),
            _buildStatusChip(report.status),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reporter Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      backgroundImage: report.reporter?.avatar != null &&
                              report.reporter!.avatar!.isNotEmpty
                          ? NetworkImage(
                              _resolveImageUrl(report.reporter!.avatar!))
                          : null,
                      child: report.reporter?.avatar == null ||
                              report.reporter!.avatar!.isEmpty
                          ? const Icon(Icons.person, color: Colors.red)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.reporter?.displayName ?? 'Người dùng ẩn danh',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (report.reporter != null)
                            Text(
                              '@${report.reporter!.handle} (ID: ${report.reporter!.userId})',
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Report Reason & Details
                const Text('Lý do báo cáo:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    report.reason,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade900),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Chi tiết bổ sung:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    report.details != null && report.details!.trim().isNotEmpty
                        ? report.details!
                        : '(Không có chi tiết bổ sung)',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),

                // Reported Post Link
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.article_outlined,
                          color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Bài viết bị báo cáo: #${report.postId}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Xem bài viết'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          if (_token == null) return;
                          try {
                            final post = await _repository.getPostById(
                              report.postId,
                              token: _token!,
                            );
                            if (mounted) _showPostDetailDialog(post);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_errorMessage(
                                      e, 'Không thể tải bài viết #${report.postId}')),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Timestamps & Resolution
                Text(
                  'Ngày báo cáo: ${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year} ${report.createdAt.hour}:${report.createdAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                if (report.resolvedAt != null)
                  Text(
                    'Đã xử lý lúc: ${report.resolvedAt!.day}/${report.resolvedAt!.month}/${report.resolvedAt!.year} ${report.resolvedAt!.hour}:${report.resolvedAt!.minute.toString().padLeft(2, '0')}${report.resolvedBy != null ? ' bởi ${report.resolvedBy!.displayName}' : ''}',
                    style:
                        const TextStyle(color: Colors.green, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          if (report.status == 'PENDING') ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                Navigator.pop(ctx);
                _resolveReport(report.reportId, 'RESOLVED');
              },
              child: const Text('Xử lý vi phạm',
                  style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              onPressed: () {
                Navigator.pop(ctx);
                _resolveReport(report.reportId, 'DISMISSED');
              },
              child: const Text('Bỏ qua',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showMediaDetailDialog(AdminMediaAssetModel asset) {
    final fullUrl = _resolveImageUrl(asset.secureUrl);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text('Tài nguyên Media #${asset.mediaAssetId}'),
            const Spacer(),
            _buildStatusChip(asset.status),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image Preview
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints:
                          const BoxConstraints(maxHeight: 280, maxWidth: 480),
                      color: Colors.grey.shade100,
                      child: Image.network(
                        fullUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const Padding(
                          padding: EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image,
                                  size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Không thể tải hình ảnh từ Cloudinary',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Asset Details
                _buildDetailRow('Người tải lên:',
                    '${asset.uploadedByUsername} (ID: ${asset.uploadedByUserId})'),
                _buildDetailRow(
                    'Cloudinary Public ID:', asset.cloudinaryPublicId),
                _buildDetailRow('URL an toàn:', asset.secureUrl,
                    isSelectable: true),
                _buildDetailRow('Định dạng:', asset.mediaType ?? '-'),
                _buildDetailRow('Số lần retry:', '${asset.retryCount}'),
                if (asset.isDeadLettered)
                  _buildDetailRow('Trạng thái Dead-letter:',
                      'ĐÃ ĐẠT NGƯỠNG LỖI (${asset.deadLetteredAt?.toLocal()})',
                      color: Colors.red),
                if (asset.lastError != null && asset.lastError!.isNotEmpty)
                  _buildDetailRow('Lỗi gần nhất:', asset.lastError!,
                      color: Colors.red),
                _buildDetailRow('Ngày tạo:',
                    '${asset.createdAt.day}/${asset.createdAt.month}/${asset.createdAt.year} ${asset.createdAt.hour}:${asset.createdAt.minute.toString().padLeft(2, '0')}'),
              ],
            ),
          ),
        ),
        actions: [
          if (asset.status == 'DELETING' || asset.isDeadLettered)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () {
                Navigator.pop(ctx);
                _retryMedia(asset.mediaAssetId);
              },
              child: const Text('Thử lại xóa (Retry)',
                  style: TextStyle(color: Colors.white)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isSelectable = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(
            child: isSelectable
                ? SelectableText(value,
                    style: TextStyle(
                        fontSize: 13, color: color ?? Colors.black87))
                : Text(value,
                    style: TextStyle(
                        fontSize: 13, color: color ?? Colors.black87)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kiểm duyệt cộng đồng')),
        body: const Center(
          child: Text(
            'Quyền truy cập bị từ chối: Chỉ tài khoản Quản trị viên (ADMIN) mới có quyền truy cập.',
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Quản trị & Kiểm duyệt Cộng đồng',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.article_outlined), text: 'Bài viết'),
            Tab(icon: Icon(Icons.report_outlined), text: 'Báo cáo vi phạm'),
            Tab(icon: Icon(Icons.perm_media_outlined), text: 'Tài nguyên Media'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPostsView(),
          _buildReportsView(),
          _buildMediaAssetsView(),
        ],
      ),
    );
  }

  Widget _buildPostsView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Bar
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Trạng thái bài viết: ',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _postStatusFilter,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Tất cả')),
                      DropdownMenuItem(
                          value: 'ACTIVE',
                          child: Text('Đang hiển thị (ACTIVE)')),
                      DropdownMenuItem(
                          value: 'HIDDEN', child: Text('Đã ẩn (HIDDEN)')),
                      DropdownMenuItem(
                          value: 'DELETED', child: Text('Đã xóa (DELETED)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _postStatusFilter = val);
                        _loadPosts();
                      }
                    },
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Làm mới'),
                onPressed: _loadPosts,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Table
          Expanded(
            child: _loadingPosts
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _posts.isEmpty
                    ? const Center(child: Text('Không có bài viết nào.'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 20,
                            horizontalMargin: 12,
                            columns: const [
                              DataColumn(label: Text('ID')),
                              DataColumn(label: Text('Tác giả')),
                              DataColumn(label: Text('Nội dung')),
                              DataColumn(label: Text('Ảnh')),
                              DataColumn(label: Text('Quyền xem')),
                              DataColumn(label: Text('Trạng thái')),
                              DataColumn(label: Text('Thích / BL')),
                              DataColumn(label: Text('Ngày tạo')),
                              DataColumn(label: Text('Thao tác')),
                            ],
                            rows: _posts.map((post) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text('#${post.postId}'),
                                    onTap: () => _showPostDetailDialog(post),
                                  ),
                                  DataCell(
                                    Text(post.author.displayName),
                                    onTap: () => _showPostDetailDialog(post),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 250,
                                      child: Text(
                                        post.content.isNotEmpty
                                            ? post.content
                                            : '(Hình ảnh / Lịch trình)',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    onTap: () => _showPostDetailDialog(post),
                                  ),
                                  DataCell(
                                    Text('${post.mediaUrls.length}'),
                                    onTap: () => _showPostDetailDialog(post),
                                  ),
                                  DataCell(Text(post.visibility)),
                                  DataCell(_buildStatusChip(post.status)),
                                  DataCell(Text(
                                      '${post.likeCount} / ${post.commentCount}')),
                                  DataCell(Text(
                                      '${post.createdAt.day}/${post.createdAt.month}/${post.createdAt.year}')),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton(
                                          onPressed: () =>
                                              _showPostDetailDialog(post),
                                          child: const Text('Chi tiết'),
                                        ),
                                        if (post.status == 'ACTIVE')
                                          TextButton(
                                            onPressed: () => _moderatePost(
                                                post.postId, 'HIDDEN'),
                                            child: const Text('Ẩn',
                                                style: TextStyle(
                                                    color: Colors.orange)),
                                          )
                                        else if (post.status == 'HIDDEN')
                                          TextButton(
                                            onPressed: () => _moderatePost(
                                                post.postId, 'ACTIVE'),
                                            child: const Text('Khôi phục',
                                                style: TextStyle(
                                                    color: Colors.green)),
                                          ),
                                        TextButton(
                                          onPressed: () =>
                                              _purgePost(post.postId),
                                          child: const Text('Hard Purge',
                                              style: TextStyle(
                                                  color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Trạng thái báo cáo: ',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _reportStatusFilter,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Tất cả')),
                      DropdownMenuItem(
                          value: 'PENDING',
                          child: Text('Chờ xử lý (PENDING)')),
                      DropdownMenuItem(
                          value: 'RESOLVED',
                          child: Text('Đã xử lý (RESOLVED)')),
                      DropdownMenuItem(
                          value: 'DISMISSED',
                          child: Text('Đã bỏ qua (DISMISSED)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _reportStatusFilter = val);
                        _loadReports();
                      }
                    },
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Làm mới'),
                onPressed: _loadReports,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loadingReports
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _reports.isEmpty
                    ? const Center(child: Text('Không có báo cáo nào.'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 20,
                            horizontalMargin: 12,
                            columns: const [
                              DataColumn(label: Text('Report ID')),
                              DataColumn(label: Text('Post ID')),
                              DataColumn(label: Text('Người báo cáo')),
                              DataColumn(label: Text('Lý do')),
                              DataColumn(label: Text('Chi tiết')),
                              DataColumn(label: Text('Trạng thái')),
                              DataColumn(label: Text('Ngày báo cáo')),
                              DataColumn(label: Text('Thao tác')),
                            ],
                            rows: _reports.map((report) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text('#${report.reportId}'),
                                    onTap: () =>
                                        _showReportDetailDialog(report),
                                  ),
                                  DataCell(
                                    Text('#${report.postId}'),
                                    onTap: () =>
                                        _showReportDetailDialog(report),
                                  ),
                                  DataCell(
                                    Text(report.reporter?.displayName ??
                                        'Ẩn danh'),
                                    onTap: () =>
                                        _showReportDetailDialog(report),
                                  ),
                                  DataCell(
                                    Text(report.reason),
                                    onTap: () =>
                                        _showReportDetailDialog(report),
                                  ),
                                  DataCell(
                                    Text(report.details ?? '-'),
                                    onTap: () =>
                                        _showReportDetailDialog(report),
                                  ),
                                  DataCell(_buildStatusChip(report.status)),
                                  DataCell(Text(
                                      '${report.createdAt.day}/${report.createdAt.month}')),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton(
                                          onPressed: () =>
                                              _showReportDetailDialog(report),
                                          child: const Text('Chi tiết'),
                                        ),
                                        if (report.status == 'PENDING') ...[
                                          TextButton(
                                            onPressed: () => _resolveReport(
                                                report.reportId, 'RESOLVED'),
                                            child: const Text('Xử lý vi phạm',
                                                style: TextStyle(
                                                    color: Colors.green)),
                                          ),
                                          TextButton(
                                            onPressed: () => _resolveReport(
                                                report.reportId, 'DISMISSED'),
                                            child: const Text('Bỏ qua',
                                                style: TextStyle(
                                                    color: Colors.grey)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaAssetsView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Trạng thái media: ',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _mediaStatusFilter,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Tất cả')),
                      DropdownMenuItem(
                          value: 'UNATTACHED',
                          child: Text('Chưa gán (UNATTACHED)')),
                      DropdownMenuItem(
                          value: 'ATTACHED', child: Text('Đã gán (ATTACHED)')),
                      DropdownMenuItem(
                          value: 'DELETING', child: Text('Đang xóa (DELETING)')),
                      DropdownMenuItem(
                          value: 'DELETED', child: Text('Đã xóa (DELETED)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _mediaStatusFilter = val);
                        _loadMediaAssets();
                      }
                    },
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _deadLetterOnly,
                    onChanged: (val) {
                      setState(() => _deadLetterOnly = val ?? false);
                      _loadMediaAssets();
                    },
                  ),
                  const Text('Chỉ hiện Dead-lettered (Lỗi quá số lần retry)'),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Làm mới'),
                onPressed: _loadMediaAssets,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loadingMedia
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _mediaAssets.isEmpty
                    ? const Center(
                        child: Text('Không có tài nguyên media nào.'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 20,
                            horizontalMargin: 12,
                            columns: const [
                              DataColumn(label: Text('Asset ID')),
                              DataColumn(label: Text('Người tải lên')),
                              DataColumn(label: Text('Xem trước')),
                              DataColumn(label: Text('Cloudinary Public ID')),
                              DataColumn(label: Text('Trạng thái')),
                              DataColumn(label: Text('Retry')),
                              DataColumn(label: Text('Dead-letter')),
                              DataColumn(label: Text('Lỗi gần nhất')),
                              DataColumn(label: Text('Thao tác')),
                            ],
                            rows: _mediaAssets.map((asset) {
                              final fullImageUrl =
                                  _resolveImageUrl(asset.secureUrl);
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text('#${asset.mediaAssetId}'),
                                    onTap: () =>
                                        _showMediaDetailDialog(asset),
                                  ),
                                  DataCell(
                                    Text(asset.uploadedByUsername),
                                    onTap: () =>
                                        _showMediaDetailDialog(asset),
                                  ),
                                  DataCell(
                                    InkWell(
                                      onTap: () =>
                                          _showMediaDetailDialog(asset),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(
                                          fullImageUrl,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(Icons.broken_image,
                                                      size: 30),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(asset.cloudinaryPublicId),
                                    onTap: () =>
                                        _showMediaDetailDialog(asset),
                                  ),
                                  DataCell(_buildStatusChip(asset.status)),
                                  DataCell(Text('${asset.retryCount}')),
                                  DataCell(
                                    asset.isDeadLettered
                                        ? const Chip(
                                            label: Text('DEAD-LETTER',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white)),
                                            backgroundColor: Colors.red,
                                          )
                                        : const Text('-'),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 180,
                                      child: Text(
                                        asset.lastError ?? '-',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton(
                                          onPressed: () =>
                                              _showMediaDetailDialog(asset),
                                          child: const Text('Chi tiết'),
                                        ),
                                        if (asset.status == 'DELETING' ||
                                            asset.isDeadLettered)
                                          TextButton(
                                            onPressed: () =>
                                                _retryMedia(asset.mediaAssetId),
                                            child: const Text('Retry xóa',
                                                style: TextStyle(
                                                    color: Colors.blue)),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg = Colors.white;

    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'RESOLVED':
      case 'ATTACHED':
        bg = Colors.green;
        break;
      case 'HIDDEN':
      case 'PENDING':
      case 'DELETING':
        bg = Colors.orange;
        break;
      case 'DELETED':
      case 'DISMISSED':
        bg = Colors.grey;
        break;
      case 'UNATTACHED':
        bg = Colors.blueGrey;
        break;
      default:
        bg = Colors.blue;
    }

    return Chip(
      label: Text(status,
          style: TextStyle(
              fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
      backgroundColor: bg,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
