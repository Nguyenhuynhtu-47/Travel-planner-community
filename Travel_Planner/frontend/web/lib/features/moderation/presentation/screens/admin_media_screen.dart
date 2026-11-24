import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../data/models/admin_media_asset_model.dart';
import '../../data/moderation_repository.dart';

/// Professional Enterprise Media Asset Management for Travel Planner Web Admin.
/// Aligned with docs/plan/admin-design-system.md (Minimalism & Swiss Style).
/// Supports dual viewing modes (Enterprise Data Table & Media Gallery Grid),
/// server-side pagination, status/dead-letter filtering, asset inspection,
/// and safe retry deletion actions.
class AdminMediaScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final ModerationRepository? repository;
  final bool embedded;

  const AdminMediaScreen({
    super.key,
    required this.authNotifier,
    this.repository,
    this.embedded = false,
  });

  @override
  State<AdminMediaScreen> createState() => _AdminMediaScreenState();
}

class _AdminMediaScreenState extends State<AdminMediaScreen> {
  late final ModerationRepository _repository;
  bool _loading = false;
  List<AdminMediaAssetModel> _mediaAssets = [];
  int _page = 0;
  final int _pageSize = 20;
  int _totalPages = 0;
  int _totalElements = 0;
  String _statusFilter = 'ALL';
  bool _deadLetterOnly = false;
  bool _isGridView = false;
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
      _loadMediaAssets();
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

  Future<void> _loadMediaAssets() async {
    if (_token == null) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final statusParam = _statusFilter == 'ALL' ? null : _statusFilter;
      final res = await _repository.getMediaAssetsPaged(
        status: statusParam,
        deadLetterOnly: _deadLetterOnly,
        page: _page,
        size: _pageSize,
        token: _token!,
      );
      if (mounted) {
        setState(() {
          _mediaAssets = res.content;
          _totalPages = res.totalPages;
          _totalElements = res.totalElements;
          _page = res.page;
        });
      }
    } catch (e) {
      final msg = _parseErrorMessage(e, 'Không thể tải danh sách media assets');
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
      _loadMediaAssets();
    }
  }

  Future<void> _retryMedia(int mediaAssetId) async {
    if (_token == null) return;
    try {
      await _repository.retryMediaAsset(mediaAssetId, token: _token!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi yêu cầu thử lại xóa media.'),
            backgroundColor: AppColors.primary,
          ),
        );
        _loadMediaAssets();
      }
    } catch (e) {
      final msg = _parseErrorMessage(e, 'Không thể thử lại xóa media');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showMediaDetailDialog(AdminMediaAssetModel asset) {
    final fullImageUrl = _resolveImageUrl(asset.secureUrl);

    AdminDialog.show<void>(
      context: context,
      width: 580,
      title: 'Chi tiết Media #${asset.mediaAssetId}',
      titleBadge: AdminStatusBadge(status: asset.status),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image preview container
            Center(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  border: Border.all(color: AppColors.border, width: 1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.network(
                    fullImageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 160,
                        color: AppColors.surfaceSubtle,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(24),
                      color: AppColors.surfaceSubtle,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image, size: 48, color: AppColors.textMuted),
                          SizedBox(height: 8),
                          Text(
                            'Không thể tải hình ảnh từ Cloudinary',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Quick Copy Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 13),
                  label: const Text('Sao chép URL', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: asset.secureUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã sao chép liên kết ảnh vào bộ nhớ tạm.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Asset Metadata Details Table
            _buildDetailRow('Người tải lên:', '${asset.uploadedByUsername} (ID: ${asset.uploadedByUserId})'),
            _buildDetailRow('Cloudinary Public ID:', asset.cloudinaryPublicId, isSelectable: true),
            _buildDetailRow('URL an toàn:', asset.secureUrl, isSelectable: true),
            _buildDetailRow('Định dạng:', asset.mediaType ?? '-'),
            _buildDetailRow('Số lần thử lại:', '${asset.retryCount}'),
            if (asset.isDeadLettered)
              _buildDetailRow(
                'Trạng thái lỗi đình trệ:',
                'ĐÃ ĐẠT NGƯỠNG LỖI (${asset.deadLetteredAt != null ? _formatDateTime(asset.deadLetteredAt!) : 'N/A'})',
                color: AppColors.error,
              ),
            if (asset.lastError != null && asset.lastError!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.errorBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lỗi gần nhất ghi nhận:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        asset.lastError!,
                        style: const TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            _buildDetailRow('Ngày tạo:', _formatDateTime(asset.createdAt)),
            if (asset.updatedAt != null)
              _buildDetailRow('Cập nhật gần nhất:', _formatDateTime(asset.updatedAt!)),
          ],
        ),
      ),
      actions: [
        if (asset.status == 'DELETING' || asset.isDeadLettered)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _retryMedia(asset.mediaAssetId);
            },
            child: const Text('Thử lại xóa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.borderStrong),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ),
      ],
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
            width: 160,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: isSelectable
                ? SelectableText(
                    value,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: color ?? AppColors.textSecondary,
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: color ?? AppColors.textSecondary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản lý Media')),
        body: const Center(
          child: Text(
            'Quyền truy cập bị từ chối: Chỉ tài khoản Quản trị viên (ADMIN) mới có quyền truy cập.',
            style: TextStyle(color: AppColors.error, fontSize: 16),
          ),
        ),
      );
    }

    final filteredAssets = _mediaAssets.where((asset) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final matchId = asset.mediaAssetId.toString().contains(q);
      final matchUser = asset.uploadedByUsername.toLowerCase().contains(q);
      final matchPublicId = asset.cloudinaryPublicId.toLowerCase().contains(q);
      final matchType = asset.mediaType?.toLowerCase().contains(q) ?? false;
      final matchStatus = asset.status.toLowerCase().contains(q);
      return matchId || matchUser || matchPublicId || matchType || matchStatus;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Quản lý Media Assets'),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Standalone Enterprise Page Header
          AdminPageHeader(
            title: 'Quản lý tài nguyên Media',
            subtitle:
                'Giám sát tài nguyên tải lên Cloudinary, xử lý dead-letter và retry dọn dẹp file rác.',
            actions: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Text(
                  'Tổng: $_totalElements tài nguyên',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          // Standard Admin Toolbar (Filters, Search, View Mode Toggle, Actions)
          AdminToolbar(
            filters: [
              // Search input
              SizedBox(
                width: 250,
                height: 32,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm ID, uploader, public ID...',
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
                          DropdownMenuItem(value: 'UNATTACHED', child: Text('Chưa gán')),
                          DropdownMenuItem(value: 'ATTACHED', child: Text('Đã gán')),
                          DropdownMenuItem(value: 'DELETING', child: Text('Đang xóa')),
                          DropdownMenuItem(value: 'DELETED', child: Text('Đã xóa')),
                        ],
                        onChanged: (val) {
                          if (val != null && val != _statusFilter) {
                            setState(() {
                              _statusFilter = val;
                              _page = 0;
                            });
                            _loadMediaAssets();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),

              // Dead-letter Checkbox Toggle
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _deadLetterOnly,
                    activeColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) {
                      setState(() {
                        _deadLetterOnly = val ?? false;
                        _page = 0;
                      });
                      _loadMediaAssets();
                    },
                  ),
                  const Text(
                    'Chỉ hiện lỗi đình trệ (Quá số lần thử lại)',
                    style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ],
            actions: [
              // Dual View Mode Toggle (Table vs Grid)
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.table_rows_outlined,
                        size: 16,
                        color: !_isGridView ? AppColors.primary : AppColors.textMuted,
                      ),
                      tooltip: 'Xem dạng bảng',
                      splashRadius: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () {
                        if (_isGridView) setState(() => _isGridView = false);
                      },
                    ),
                    Container(width: 1, height: 18, color: AppColors.border),
                    IconButton(
                      icon: Icon(
                        Icons.grid_view_outlined,
                        size: 16,
                        color: _isGridView ? AppColors.primary : AppColors.textMuted,
                      ),
                      tooltip: 'Xem dạng lưới ảnh',
                      splashRadius: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () {
                        if (!_isGridView) setState(() => _isGridView = true);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Refresh Button
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Làm mới', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderStrong),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                ),
                onPressed: _loadMediaAssets,
              ),
            ],
          ),

          // Operational Technical Note Callout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.infoLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.infoBorder.withValues(alpha: 0.7), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.info),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'Tài nguyên Cloudinary được dọn dẹp tự động khi bài viết bị xóa vĩnh viễn (purge) hoặc qua tác vụ unattached sweep. "Retry xóa" kích hoạt lại quy trình dọn dẹp cho tài nguyên bị kẹt hoặc dead-letter.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Error Banner if server/network failure
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
                      onPressed: _loadMediaAssets,
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

          // Main Workspace: Table or Gallery Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: _isGridView
                  ? _buildGalleryGridView(filteredAssets)
                  : _buildDataTableView(filteredAssets),
            ),
          ),
        ],
      ),
    );
  }

  /// Enterprise Data Table View using AdminDataTable
  Widget _buildDataTableView(List<AdminMediaAssetModel> assets) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dynamicCloudinaryWidth =
            (constraints.maxWidth - 750).clamp(180.0, 500.0);
        final dynamicErrorWidth =
            (constraints.maxWidth - 820).clamp(160.0, 420.0);

        return AdminDataTable(
          isLoading: _loading,
          minWidth: constraints.maxWidth.isFinite ? constraints.maxWidth : 880.0,
          emptyMessage: _searchQuery.isNotEmpty
              ? 'Không tìm thấy media nào khớp với từ khóa "$_searchQuery".'
              : 'Không có tài nguyên media nào.',
          currentPage: _page,
          totalPages: _totalPages,
          totalElements: _totalElements,
          pageSize: _pageSize,
          onPageChanged: _onPageChanged,
          columns: [
            AdminDataColumn.text('MÃ TÀI NGUYÊN', numeric: true),
            AdminDataColumn.text('NGƯỜI TẢI LÊN'),
            AdminDataColumn.text('XEM TRƯỚC'),
            AdminDataColumn.text('CLOUDINARY PUBLIC ID'),
            AdminDataColumn.text('TRẠNG THÁI'),
            AdminDataColumn.text('SỐ LẦN THỬ LẠI', numeric: true),
            AdminDataColumn.text('LỖI ĐÌNH TRỆ'),
            AdminDataColumn.text('LỖI GẦN NHẤT'),
            AdminDataColumn.text('THAO TÁC'),
          ],
          rows: assets.map((asset) {
            final fullImageUrl = _resolveImageUrl(asset.secureUrl);
            return AdminDataRow(
              onTap: () => _showMediaDetailDialog(asset),
              cells: [
                Text(
                  '#${asset.mediaAssetId}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
                Text(
                  asset.uploadedByUsername,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    color: AppColors.surfaceSubtle,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.network(
                      fullImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 20, color: AppColors.textMuted),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: 180, maxWidth: dynamicCloudinaryWidth),
                  child: Tooltip(
                    message: asset.cloudinaryPublicId,
                    waitDuration: const Duration(milliseconds: 400),
                    child: Text(
                      asset.cloudinaryPublicId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ),
                AdminStatusBadge(status: asset.status),
                Text(
                  '${asset.retryCount}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
                asset.isDeadLettered
                    ? const AdminStatusBadge(status: 'DEAD_LETTER', customLabel: 'LỖI ĐÌNH TRỆ')
                    : const Text('-', style: TextStyle(color: AppColors.textMuted)),
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: 160, maxWidth: dynamicErrorWidth),
                  child: Tooltip(
                    message: asset.lastError ?? '-',
                    waitDuration: const Duration(milliseconds: 400),
                    child: Text(
                      asset.lastError ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: asset.lastError != null ? AppColors.error : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HoverMovement.button(
                      child: Tooltip(
                        message: 'Xem chi tiết tài nguyên đa phương tiện',
                        child: TextButton(
                          onPressed: () => _showMediaDetailDialog(asset),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('Chi tiết', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                    if (asset.status == 'DELETING' || asset.isDeadLettered) ...[
                      const SizedBox(width: 4),
                      HoverMovement.button(
                        child: Tooltip(
                          message: 'Thử lại tiến trình xóa ảnh trên Cloudinary',
                          child: TextButton(
                            onPressed: () => _retryMedia(asset.mediaAssetId),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryAccessible,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('Thử lại xóa',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  /// Modern Responsive Media Gallery Grid View
  Widget _buildGalleryGridView(List<AdminMediaAssetModel> assets) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (assets.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Center(
          child: Text(
            _searchQuery.isNotEmpty
                ? 'Không tìm thấy media nào khớp với từ khóa "$_searchQuery".'
                : 'Không có tài nguyên media nào.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          // Grid items container
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                childAspectRatio: 0.82,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: assets.length,
              itemBuilder: (context, index) {
                final asset = assets[index];
                final fullImageUrl = _resolveImageUrl(asset.secureUrl);

                return HoverMovement.card(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Image Preview with Header Overlay
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card - 1)),
                              child: Container(
                                color: AppColors.surfaceSubtle,
                                child: Image.network(
                                  fullImageUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) => const Center(
                                    child: Icon(Icons.broken_image, size: 36, color: AppColors.textMuted),
                                  ),
                                ),
                              ),
                            ),
                            // Top Badges
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  '#${asset.mediaAssetId}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: AdminStatusBadge(status: asset.status),
                            ),
                          ],
                        ),
                      ),

                      // Card Details
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              asset.cloudinaryPublicId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 12, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    asset.uploadedByUsername,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                            if (asset.isDeadLettered) ...[
                              const SizedBox(height: 2),
                              const Text(
                                'LỖI ĐÌNH TRỆ QUÁ HẠN',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Card Action Row
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => _showMediaDetailDialog(asset),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text('Chi tiết', style: TextStyle(fontSize: 11.5)),
                              ),
                            ),
                            if (asset.status == 'DELETING' || asset.isDeadLettered)
                              Expanded(
                                child: TextButton(
                                  onPressed: () => _retryMedia(asset.mediaAssetId),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text('Thử lại xóa', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            ),
          ),

          // Pagination Footer in Grid Mode
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border, width: 1)),
              color: AppColors.surfaceSubtle,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng số: $_totalElements tài nguyên',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 18),
                      tooltip: 'Trang trước',
                      onPressed: _page > 0 ? () => _onPageChanged(_page - 1) : null,
                    ),
                    Text(
                      'Trang ${_page + 1} / ${math.max(1, _totalPages)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 18),
                      tooltip: 'Trang kế',
                      onPressed: (_page + 1 < _totalPages) ? () => _onPageChanged(_page + 1) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
