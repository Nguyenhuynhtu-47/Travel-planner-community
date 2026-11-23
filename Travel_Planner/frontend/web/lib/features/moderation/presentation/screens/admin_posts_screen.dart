import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_page_header.dart';
import '../../../../shared/widgets/admin_status_badge.dart';
import '../../../../shared/widgets/admin_toolbar.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/models/admin_post_model.dart';
import '../../data/moderation_repository.dart';

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
  String _statusFilter = 'ALL';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
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

  String _errorMessage(dynamic error, String fallback) {
    if (error is ApiException) {
      return error.message.isNotEmpty ? error.message : fallback;
    }
    return fallback;
  }

  Future<void> _loadPosts() async {
    if (_token == null) return;
    setState(() => _loading = true);
    try {
      final statusParam = _statusFilter == 'ALL' ? null : _statusFilter;
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
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _moderatePost(int postId, String status) async {
    if (_token == null) return;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status == 'HIDDEN' ? 'Ẩn bài viết vi phạm' : 'Khôi phục bài viết'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status == 'HIDDEN'
                ? 'Nhập lý do kiểm duyệt để thông báo cho người dùng hoặc lưu audit log:'
                : 'Bạn có chắc muốn khôi phục hiển thị cho bài viết này?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Lý do kiểm duyệt',
                hintText: 'VD: Vi phạm tiêu chuẩn cộng đồng, spam...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
              backgroundColor: status == 'HIDDEN' ? Colors.orange : Colors.green,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              status == 'HIDDEN' ? 'Xác nhận ẩn' : 'Xác nhận khôi phục',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
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
            content: Text(status == 'HIDDEN'
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
            content: Text(_errorMessage(e, 'Không thể cập nhật trạng thái bài viết')),
          ),
        );
      }
    }
  }

  Future<void> _purgePost(int postId) async {
    if (_token == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CẢNH BÁO: XÓA VĨNH VIỄN'),
        content: const Text(
          'Hành động này sẽ xóa vĩnh viễn bài viết khỏi hệ thống và đưa tất cả ảnh đính kèm vào hàng đợi dọn dẹp Cloudinary. Không thể hoàn tác!',
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
          const SnackBar(content: Text('Đã xóa vĩnh viễn bài viết.')),
        );
        _loadPosts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage(e, 'Không thể xóa vĩnh viễn bài viết')),
          ),
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
            AdminStatusBadge(status: post.status),
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
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: post.author.avatar != null &&
                              post.author.avatar!.isNotEmpty
                          ? NetworkImage(_resolveImageUrl(post.author.avatar!))
                          : null,
                      child: post.author.avatar == null ||
                              post.author.avatar!.isEmpty
                          ? const Icon(Icons.person, color: Colors.grey)
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
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            '@${post.author.handle} (ID: ${post.author.userId})',
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Content
                const Text('Nội dung:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SelectableText(
                    post.content.isNotEmpty ? post.content : '(Không có nội dung văn bản)',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),

                // Attached Media
                if (post.mediaUrls.isNotEmpty) ...[
                  const Text('Ảnh đính kèm:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: post.mediaUrls.map((url) {
                      final fullUrl = _resolveImageUrl(url);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(6),
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

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kiểm duyệt bài viết')),
        body: const Center(
          child: Text(
            'Quyền truy cập bị từ chối: Chỉ tài khoản Quản trị viên (ADMIN) mới có quyền truy cập.',
            style: TextStyle(color: Colors.red, fontSize: 16),
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
          // Standalone Page Header
          const AdminPageHeader(
            title: 'Kiểm duyệt bài viết',
            subtitle:
                'Quản lý, rà soát và kiểm duyệt nội dung bài đăng cộng đồng vi phạm tiêu chuẩn.',
          ),

          // Standard Admin Toolbar (Filters & Search)
          AdminToolbar(
            filters: [
              // Search input
              SizedBox(
                width: 240,
                height: 32,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm nội dung, tác giả, ID...',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.muted),
                    prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.muted),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.primary),
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
                      borderRadius: BorderRadius.circular(4),
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
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _statusFilter = val);
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
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: _loadPosts,
              ),
            ],
          ),

          // Data Table Workspace
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : filteredPosts.isEmpty
                    ? const Center(
                        child: Text(
                          'Không có bài viết nào.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 24,
                              horizontalMargin: 16,
                              headingRowHeight: 38,
                              dataRowMinHeight: 44,
                              dataRowMaxHeight: 52,
                              headingRowColor: WidgetStateProperty.all(AppColors.surfaceSoft),
                              headingTextStyle: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted,
                                letterSpacing: 0.3,
                              ),
                              columns: const [
                                DataColumn(label: Text('ID')),
                                DataColumn(label: Text('TÁC GIẢ')),
                                DataColumn(label: Text('NỘI DUNG')),
                                DataColumn(label: Text('ẢNH ĐÍNH KÈM')),
                                DataColumn(label: Text('TRẠNG THÁI')),
                                DataColumn(label: Text('NGÀY TẠO')),
                                DataColumn(label: Text('THAO TÁC')),
                              ],
                              rows: filteredPosts.map((post) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text('#${post.postId}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                                      onTap: () => _showPostDetailDialog(post),
                                    ),
                                    DataCell(
                                      Text(post.author.displayName, style: const TextStyle(fontSize: 12.5)),
                                      onTap: () => _showPostDetailDialog(post),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 260,
                                        child: Text(
                                          post.content.isNotEmpty ? post.content : '(Chỉ có ảnh)',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12.5),
                                        ),
                                      ),
                                      onTap: () => _showPostDetailDialog(post),
                                    ),
                                    DataCell(
                                      post.mediaUrls.isNotEmpty
                                          ? Text('${post.mediaUrls.length} ảnh',
                                              style: const TextStyle(fontSize: 12, color: AppColors.primary))
                                          : const Text('-', style: TextStyle(color: AppColors.muted)),
                                    ),
                                    DataCell(AdminStatusBadge(status: post.status)),
                                    DataCell(Text(
                                      '${post.createdAt.day.toString().padLeft(2, '0')}/${post.createdAt.month.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    )),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextButton(
                                            onPressed: () => _showPostDetailDialog(post),
                                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                            child: const Text('Chi tiết', style: TextStyle(fontSize: 12)),
                                          ),
                                          if (post.status == 'ACTIVE')
                                            TextButton(
                                              onPressed: () => _moderatePost(post.postId, 'HIDDEN'),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.orange.shade800,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              child: const Text('Ẩn', style: TextStyle(fontSize: 12)),
                                            )
                                          else if (post.status == 'HIDDEN')
                                            TextButton(
                                              onPressed: () => _moderatePost(post.postId, 'ACTIVE'),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.green.shade800,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              child: const Text('Khôi phục', style: TextStyle(fontSize: 12)),
                                            ),
                                          TextButton(
                                            onPressed: () => _purgePost(post.postId),
                                            style: TextButton.styleFrom(
                                              foregroundColor: AppColors.error,
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            child: const Text('Hard Purge', style: TextStyle(fontSize: 12)),
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
          ),
        ],
      ),
    );
  }
}
