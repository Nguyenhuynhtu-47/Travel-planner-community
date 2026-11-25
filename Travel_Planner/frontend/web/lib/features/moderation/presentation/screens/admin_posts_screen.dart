import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_data_table.dart';
import '../../../../shared/widgets/admin_dialog.dart';
import '../../../../shared/widgets/admin_page_header.dart';
import '../../../../shared/widgets/admin_status_badge.dart';
import '../../../../shared/widgets/admin_toolbar.dart';
import '../../../../shared/widgets/hover_movement.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/models/admin_post_model.dart';
import '../../data/moderation_repository.dart';

/// Professional Enterprise Post Moderation screen for Travel Planner Web Admin.
/// Aligned with docs/plan/admin-design-system.md (Minimalism & Swiss Style).
class AdminPostsScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final ModerationRepository? repository;
  final bool embedded;

  const AdminPostsScreen({
    super.key,
    required this.authNotifier,
    this.repository,
    this.embedded = false,
  });

  @override
  State<AdminPostsScreen> createState() => _AdminPostsScreenState();
}

class _AdminPostsScreenState extends State<AdminPostsScreen> {
  late final ModerationRepository _repository;
  bool _loading = false;
  List<AdminPostModel> _posts = [];
  int _page = 0;
  final int _pageSize = 20;
  int _totalPages = 0;
  int _totalElements = 0;
  String _statusFilter = 'ALL';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _token;
  String? _errorMessage;

  bool get isAdmin {
    final role =
        widget.authNotifier.currentUser?['role']?.toString().toUpperCase();
    return role == 'ADMIN';
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ModerationRepository();
    _token = widget.authNotifier.token;
    if (isAdmin) {
      _loadPosts();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$min';
  }

  String _parseErrorMessage(dynamic error, String fallback) {
    if (error is ApiException) {
      return error.message.isNotEmpty ? error.message : fallback;
    }
    return fallback;
  }

  Future<void> _loadPosts() async {
    if (_token == null) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final statusParam = _statusFilter == 'ALL' ? null : _statusFilter;
      final res = await _repository.getPostsPaged(
        status: statusParam,
        page: _page,
        size: _pageSize,
        token: _token!,
      );
      if (mounted) {
        setState(() {
          _posts = res.content;
          _totalPages = res.totalPages;
          _totalElements = res.totalElements;
          _page = res.page;
        });
      }
    } catch (e) {
      final msg = _parseErrorMessage(e, 'Không thể tải danh sách bài viết');
      if (mounted) {
        setState(() => _errorMessage = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onPageChanged(int newPage) {
    if (newPage != _page && newPage >= 0) {
      setState(() => _page = newPage);
      _loadPosts();
    }
  }

  Future<void> _moderatePost(int postId, String status) async {
    if (_token == null) return;
    final reasonController = TextEditingController();

    final isHide = status == 'HIDDEN';
    final confirmed = await AdminDialog.show<bool>(
      context: context,
      width: 480,
      title: isHide ? 'Ẩn bài viết vi phạm' : 'Khôi phục bài viết',
      titleBadge: AdminStatusBadge(status: status),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isHide
                ? 'Nhập lý do kiểm duyệt để thông báo cho người dùng hoặc lưu audit log:'
                : 'Bạn có chắc muốn khôi phục hiển thị cho bài viết này?',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: reasonController,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Lý do kiểm duyệt',
              hintText: 'VD: Vi phạm tiêu chuẩn cộng đồng, spam...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.borderStrong),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isHide ? AppColors.accentDark : AppColors.success,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(isHide ? 'Xác nhận ẩn' : 'Xác nhận khôi phục'),
        ),
      ],
    );

    if (confirmed != true) return;

    try {
      await _repository.moderatePost(
        postId,
        status: status,
        reason: reasonController.text.trim().isNotEmpty
            ? reasonController.text.trim()
            : null,
        token: _token!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHide
                ? 'Đã ẩn bài viết thành công.'
                : 'Đã khôi phục bài viết.'),
          ),
        );
        _loadPosts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_parseErrorMessage(e, 'Không thể cập nhật trạng thái bài viết')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _purgePost(int postId) async {
    if (_token == null) return;

    final confirmed = await AdminDialog.show<bool>(
      context: context,
      width: 480,
      title: 'CẢNH BÁO: XÓA VĨNH VIỄN',
      titleBadge: const AdminStatusBadge(status: 'DELETED'),
      content: const Text(
        'Hành động này sẽ xóa vĩnh viễn bài viết khỏi hệ thống và đưa tất cả ảnh đính kèm vào hàng đợi dọn dẹp Cloudinary. Không thể hoàn tác!',
        style: TextStyle(
          fontSize: 13,
          color: AppColors.error,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.borderStrong),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Xóa vĩnh viễn'),
        ),
      ],
    );

    if (confirmed != true) return;

    try {
      await _repository.purgePost(postId, token: _token!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa vĩnh viễn bài viết.')),
        );
        _loadPosts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_parseErrorMessage(e, 'Không thể xóa vĩnh viễn bài viết')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showPostDetailDialog(AdminPostModel post) {
    AdminDialog.show<void>(
      context: context,
      width: 640,
      title: 'Chi tiết bài viết #${post.postId}',
      titleBadge: AdminStatusBadge(status: post.status),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Author Header Bar
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: post.author.avatar != null && post.author.avatar!.isNotEmpty
                    ? NetworkImage(_resolveImageUrl(post.author.avatar!))
                    : null,
                child: post.author.avatar == null || post.author.avatar!.isEmpty
                    ? Text(
                        post.author.displayName.isNotEmpty
                            ? post.author.displayName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    Text(
                      '@${post.author.handle} (ID: ${post.author.userId})',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Content body
          const Text(
            'Nội dung:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: SelectableText(
              post.content.isNotEmpty ? post.content : '(Không có nội dung văn bản)',
              style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Attached Media Gallery
          if (post.mediaUrls.isNotEmpty) ...[
            Text(
              'Ảnh đính kèm (${post.mediaUrls.length}):',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: post.mediaUrls.map((url) {
                final fullUrl = _resolveImageUrl(url);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: InkWell(
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Image.network(
                                fullUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  padding: const EdgeInsets.all(32),
                                  color: AppColors.surface,
                                  child: const Icon(Icons.broken_image, size: 48, color: AppColors.textMuted),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 24),
                                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border, width: 1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Image.network(
                        fullUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                        },
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image, color: AppColors.textMuted, size: 24),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Metadata & Stats
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Text('Lượt thích: ${post.likeCount}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text('Bình luận: ${post.commentCount}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text('Ngày tạo: ${_formatDateTime(post.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),

          // Moderation Reason (if any)
          if (post.moderationReason != null && post.moderationReason!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.warningBorder, width: 1),
              ),
              child: Text(
                'Lý do kiểm duyệt: ${post.moderationReason}',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (post.status == 'ACTIVE')
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentDark,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _moderatePost(post.postId, 'HIDDEN');
            },
            child: const Text('Ẩn bài viết'),
          )
        else if (post.status == 'HIDDEN')
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _moderatePost(post.postId, 'ACTIVE');
            },
            child: const Text('Khôi phục bài viết'),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            _purgePost(post.postId);
          },
          child: const Text('Xóa vĩnh viễn'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.borderStrong),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          child: const Text('Đóng'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kiểm duyệt bài viết')),
        body: const Center(
          child: Text(
            'Quyền truy cập bị từ chối: Chỉ tài khoản Quản trị viên (ADMIN) mới có quyền truy cập.',
            style: TextStyle(color: AppColors.error, fontSize: 16),
          ),
        ),
      );
    }

    final filteredPosts = _posts.where((post) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final matchContent = post.content.toLowerCase().contains(q);
      final matchAuthor = post.author.displayName.toLowerCase().contains(q) ||
          post.author.handle.toLowerCase().contains(q);
      final matchId = post.postId.toString().contains(q);
      return matchContent || matchAuthor || matchId;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Kiểm duyệt bài viết'),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Standalone Enterprise Page Header
          AdminPageHeader(
            title: 'Kiểm duyệt bài viết',
            actions: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Text(
                  'Tổng: $_totalElements bài viết',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          // Standard Admin Toolbar (Filters & Search)
          AdminToolbar(
            filters: [
              // Search input
              SizedBox(
                width: 260,
                height: 32,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm nội dung, tác giả, ID...',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textMuted),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            splashRadius: 14,
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: const BorderSide(color: AppColors.primaryAccessible),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                  },
                ),
              ),

              // Status Dropdown
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Trạng thái: ',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textPrimary),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('Tất cả trạng thái')),
                          DropdownMenuItem(value: 'ACTIVE', child: Text('Hoạt động (ACTIVE)')),
                          DropdownMenuItem(value: 'HIDDEN', child: Text('Đã ẩn (HIDDEN)')),
                          DropdownMenuItem(value: 'DELETED', child: Text('Đã xóa (DELETED)')),
                        ],
                        onChanged: (val) {
                          if (val != null && val != _statusFilter) {
                            setState(() {
                              _statusFilter = val;
                              _page = 0;
                            });
                            _loadPosts();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
            actions: [
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Làm mới', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderStrong),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                ),
                onPressed: _loadPosts,
              ),
            ],
          ),

          // Error Banner if network/server failed
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.errorBorder, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.error, fontWeight: FontWeight.w500),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadPosts,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.error,
                      ),
                      child: const Text('Thử lại', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),

          // Data Table Workspace using AdminDataTable
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dynamicContentWidth =
                      (constraints.maxWidth - 720).clamp(280.0, 1000.0);

                  return AdminDataTable(
                    isLoading: _loading,
                    minWidth: constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : 800.0,
                    emptyMessage: _searchQuery.isNotEmpty
                        ? 'Không tìm thấy bài viết nào khớp với từ khóa "$_searchQuery".'
                        : 'Không có bài viết nào.',
                    currentPage: _page,
                    totalPages: _totalPages,
                    totalElements: _totalElements,
                    pageSize: _pageSize,
                    onPageChanged: _onPageChanged,
                    columns: [
                      AdminDataColumn.text('ID', numeric: true),
                      AdminDataColumn.text('Tác giả'),
                      AdminDataColumn.text('Nội dung'),
                      AdminDataColumn.text('Ảnh đính kèm'),
                      AdminDataColumn.text('Trạng thái'),
                      AdminDataColumn.text('Ngày tạo'),
                      AdminDataColumn.text('Thao tác'),
                    ],
                    rows: filteredPosts.map((post) {
                      return AdminDataRow(
                        onTap: () => _showPostDetailDialog(post),
                        cells: [
                          Text(
                            '#${post.postId}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                          Text(
                            post.author.displayName,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w500),
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                                minWidth: 260, maxWidth: dynamicContentWidth),
                            child: Tooltip(
                              message: post.content.isNotEmpty
                                  ? post.content
                                  : '(Chỉ có ảnh)',
                              waitDuration: const Duration(milliseconds: 400),
                              child: Text(
                                post.content.isNotEmpty
                                    ? post.content
                                    : '(Chỉ có ảnh)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                          ),
                          post.mediaUrls.isNotEmpty
                              ? Text(
                                  '${post.mediaUrls.length} ảnh',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600),
                                )
                              : const Text('-',
                                  style:
                                      TextStyle(color: AppColors.textMuted)),
                          AdminStatusBadge(status: post.status),
                          Text(
                            '${post.createdAt.day.toString().padLeft(2, '0')}/${post.createdAt.month.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HoverMovement.button(
                                child: Tooltip(
                                  message: 'Xem chi tiết bài viết',
                                  child: TextButton(
                                    onPressed: () => _showPostDetailDialog(post),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: AppColors.textSecondary,
                                    ),
                                    child: const Text('Chi tiết',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ),
                              if (post.status == 'ACTIVE')
                                HoverMovement.button(
                                  child: Tooltip(
                                    message: 'Ẩn bài viết khỏi cộng đồng',
                                    child: TextButton(
                                      onPressed: () =>
                                          _moderatePost(post.postId, 'HIDDEN'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.warning,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: const Text('Ẩn',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                )
                              else if (post.status == 'HIDDEN')
                                HoverMovement.button(
                                  child: Tooltip(
                                    message: 'Khôi phục hiển thị bài viết',
                                    child: TextButton(
                                      onPressed: () =>
                                          _moderatePost(post.postId, 'ACTIVE'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.success,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: const Text('Khôi phục',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                ),
                              HoverMovement.button(
                                child: Tooltip(
                                  message: 'Xóa vĩnh viễn bài viết khỏi hệ thống',
                                  child: TextButton(
                                    onPressed: () => _purgePost(post.postId),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text('Xóa vĩnh viễn',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
