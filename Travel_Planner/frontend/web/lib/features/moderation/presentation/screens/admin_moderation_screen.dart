import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải danh sách bài viết')),
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải danh sách báo cáo')),
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải danh sách tài nguyên media')),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thao tác thất bại')),
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
            child: const Text('Xóa vĩnh viễn', style: TextStyle(color: Colors.white)),
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể xóa bài viết')),
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể cập nhật báo cáo')),
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể retry xóa media')),
        );
      }
    }
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
                  const Text('Trạng thái bài viết: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _postStatusFilter,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Tất cả')),
                      DropdownMenuItem(value: 'ACTIVE', child: Text('Đang hiển thị (ACTIVE)')),
                      DropdownMenuItem(value: 'HIDDEN', child: Text('Đã ẩn (HIDDEN)')),
                      DropdownMenuItem(value: 'DELETED', child: Text('Đã xóa (DELETED)')),
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
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _posts.isEmpty
                    ? const Center(child: Text('Không có bài viết nào.'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
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
                                  DataCell(Text('#${post.postId}')),
                                  DataCell(Text(post.author.displayName)),
                                  DataCell(
                                    SizedBox(
                                      width: 250,
                                      child: Text(
                                        post.content,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text('${post.mediaUrls.length}')),
                                  DataCell(Text(post.visibility)),
                                  DataCell(_buildStatusChip(post.status)),
                                  DataCell(Text('${post.likeCount} / ${post.commentCount}')),
                                  DataCell(Text('${post.createdAt.day}/${post.createdAt.month}/${post.createdAt.year}')),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (post.status == 'ACTIVE')
                                          TextButton(
                                            onPressed: () => _moderatePost(post.postId, 'HIDDEN'),
                                            child: const Text('Ẩn', style: TextStyle(color: Colors.orange)),
                                          )
                                        else if (post.status == 'HIDDEN')
                                          TextButton(
                                            onPressed: () => _moderatePost(post.postId, 'ACTIVE'),
                                            child: const Text('Khôi phục', style: TextStyle(color: Colors.green)),
                                          ),
                                        TextButton(
                                          onPressed: () => _purgePost(post.postId),
                                          child: const Text('Hard Purge', style: TextStyle(color: Colors.red)),
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
                  const Text('Trạng thái báo cáo: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _reportStatusFilter,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Tất cả')),
                      DropdownMenuItem(value: 'PENDING', child: Text('Chờ xử lý (PENDING)')),
                      DropdownMenuItem(value: 'RESOLVED', child: Text('Đã xử lý (RESOLVED)')),
                      DropdownMenuItem(value: 'DISMISSED', child: Text('Đã bỏ qua (DISMISSED)')),
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
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _reports.isEmpty
                    ? const Center(child: Text('Không có báo cáo nào.'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
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
                                  DataCell(Text('#${report.reportId}')),
                                  DataCell(Text('#${report.postId}')),
                                  DataCell(Text(report.reporter?.displayName ?? 'Ẩn danh')),
                                  DataCell(Text(report.reason)),
                                  DataCell(Text(report.details ?? '-')),
                                  DataCell(_buildStatusChip(report.status)),
                                  DataCell(Text('${report.createdAt.day}/${report.createdAt.month}')),
                                  DataCell(
                                    report.status == 'PENDING'
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextButton(
                                                onPressed: () => _resolveReport(report.reportId, 'RESOLVED'),
                                                child: const Text('Xử lý vi phạm', style: TextStyle(color: Colors.green)),
                                              ),
                                              TextButton(
                                                onPressed: () => _resolveReport(report.reportId, 'DISMISSED'),
                                                child: const Text('Bỏ qua', style: TextStyle(color: Colors.grey)),
                                              ),
                                            ],
                                          )
                                        : const Text('Đã giải quyết', style: TextStyle(color: AppColors.muted)),
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
                  const Text('Trạng thái media: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _mediaStatusFilter,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Tất cả')),
                      DropdownMenuItem(value: 'UNATTACHED', child: Text('Chưa gán (UNATTACHED)')),
                      DropdownMenuItem(value: 'ATTACHED', child: Text('Đã gán (ATTACHED)')),
                      DropdownMenuItem(value: 'DELETING', child: Text('Đang xóa (DELETING)')),
                      DropdownMenuItem(value: 'DELETED', child: Text('Đã xóa (DELETED)')),
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
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _mediaAssets.isEmpty
                    ? const Center(child: Text('Không có tài nguyên media nào.'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
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
                              return DataRow(
                                cells: [
                                  DataCell(Text('#${asset.mediaAssetId}')),
                                  DataCell(Text(asset.uploadedByUsername)),
                                  DataCell(
                                    Image.network(
                                      asset.secureUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, _) => const Icon(Icons.broken_image, size: 30),
                                    ),
                                  ),
                                  DataCell(Text(asset.cloudinaryPublicId)),
                                  DataCell(_buildStatusChip(asset.status)),
                                  DataCell(Text('${asset.retryCount}')),
                                  DataCell(
                                    asset.isDeadLettered
                                        ? const Chip(
                                            label: Text('DEAD-LETTER', style: TextStyle(fontSize: 10, color: Colors.white)),
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
                                    (asset.status == 'DELETING' || asset.isDeadLettered)
                                        ? TextButton(
                                            onPressed: () => _retryMedia(asset.mediaAssetId),
                                            child: const Text('Retry xóa', style: TextStyle(color: Colors.blue)),
                                          )
                                        : const Text('-'),
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
      label: Text(status, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
      backgroundColor: bg,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
