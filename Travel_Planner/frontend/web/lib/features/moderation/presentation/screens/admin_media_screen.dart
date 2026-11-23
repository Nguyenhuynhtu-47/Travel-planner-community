import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_page_header.dart';
import '../../../../shared/widgets/admin_status_badge.dart';
import '../../../../shared/widgets/admin_toolbar.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/models/admin_media_asset_model.dart';
import '../../data/moderation_repository.dart';

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
  String _statusFilter = 'ALL';
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
    _token = widget.authNotifier.token;
    if (isAdmin) {
      _loadMediaAssets();
    }
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

  Future<void> _loadMediaAssets() async {
    if (_token == null) return;
    setState(() => _loading = true);
    try {
      final statusParam = _statusFilter == 'ALL' ? null : _statusFilter;
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
            content: Text(_errorMessage(e, 'Không thể tải danh sách media assets')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retryMedia(int mediaAssetId) async {
    if (_token == null) return;
    try {
      await _repository.retryMediaAsset(mediaAssetId, token: _token!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi yêu cầu thử lại xóa media.')),
        );
        _loadMediaAssets();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage(e, 'Không thể thử lại xóa media')),
          ),
        );
      }
    }
  }

  void _showMediaDetailDialog(AdminMediaAssetModel asset) {
    final fullImageUrl = _resolveImageUrl(asset.secureUrl);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text('Chi tiết Media #${asset.mediaAssetId}'),
            const Spacer(),
            AdminStatusBadge(status: asset.status),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image preview box
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        fullImageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (c, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 150,
                            color: Colors.grey.shade100,
                            child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                          padding: const EdgeInsets.all(24),
                          color: Colors.grey.shade100,
                          child: const Column(
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
        appBar: AppBar(title: const Text('Quản lý Media')),
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
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Quản lý Media Assets'),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Standalone Page Header
          const AdminPageHeader(
            title: 'Quản lý tài nguyên Media',
            subtitle:
                'Giám sát tài nguyên tải lên Cloudinary, xử lý dead-letter và retry dọn dẹp file rác.',
          ),

          // Standard Admin Toolbar
          AdminToolbar(
            filters: [
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
                          DropdownMenuItem(value: 'UNATTACHED', child: Text('Chưa gán (UNATTACHED)')),
                          DropdownMenuItem(value: 'ATTACHED', child: Text('Đã gán (ATTACHED)')),
                          DropdownMenuItem(value: 'DELETING', child: Text('Đang xóa (DELETING)')),
                          DropdownMenuItem(value: 'DELETED', child: Text('Đã xóa (DELETED)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _statusFilter = val);
                            _loadMediaAssets();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _deadLetterOnly,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) {
                      setState(() => _deadLetterOnly = val ?? false);
                      _loadMediaAssets();
                    },
                  ),
                  const Text('Chỉ hiện Dead-lettered (Lỗi quá số lần retry)',
                      style: TextStyle(fontSize: 12)),
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
                onPressed: _loadMediaAssets,
              ),
            ],
          ),

          // Data Table Workspace
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _mediaAssets.isEmpty
                    ? const Center(
                        child: Text(
                          'Không có tài nguyên media nào.',
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
                                DataColumn(label: Text('ASSET ID')),
                                DataColumn(label: Text('NGƯỜI TẢI LÊN')),
                                DataColumn(label: Text('XEM TRƯỚC')),
                                DataColumn(label: Text('CLOUDINARY PUBLIC ID')),
                                DataColumn(label: Text('TRẠNG THÁI')),
                                DataColumn(label: Text('RETRY')),
                                DataColumn(label: Text('DEAD-LETTER')),
                                DataColumn(label: Text('LỖI GẦN NHẤT')),
                                DataColumn(label: Text('THAO TÁC')),
                              ],
                              rows: _mediaAssets.map((asset) {
                                final fullImageUrl = _resolveImageUrl(asset.secureUrl);
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text('#${asset.mediaAssetId}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                                      onTap: () => _showMediaDetailDialog(asset),
                                    ),
                                    DataCell(
                                      Text(asset.uploadedByUsername, style: const TextStyle(fontSize: 12.5)),
                                      onTap: () => _showMediaDetailDialog(asset),
                                    ),
                                    DataCell(
                                      InkWell(
                                        onTap: () => _showMediaDetailDialog(asset),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(3),
                                          child: Image.network(
                                            fullImageUrl,
                                            width: 32,
                                            height: 32,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.broken_image, size: 24, color: AppColors.muted),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(asset.cloudinaryPublicId, style: const TextStyle(fontSize: 12)),
                                      onTap: () => _showMediaDetailDialog(asset),
                                    ),
                                    DataCell(AdminStatusBadge(status: asset.status)),
                                    DataCell(Text('${asset.retryCount}', style: const TextStyle(fontSize: 12))),
                                    DataCell(
                                      asset.isDeadLettered
                                          ? const AdminStatusBadge(status: 'DEAD_LETTER', customLabel: 'DEAD-LETTER')
                                          : const Text('-', style: TextStyle(color: AppColors.muted)),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 180,
                                        child: Text(
                                          asset.lastError ?? '-',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11.5, color: AppColors.error),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextButton(
                                            onPressed: () => _showMediaDetailDialog(asset),
                                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                            child: const Text('Chi tiết', style: TextStyle(fontSize: 12)),
                                          ),
                                          if (asset.status == 'DELETING' || asset.isDeadLettered)
                                            TextButton(
                                              onPressed: () => _retryMedia(asset.mediaAssetId),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.blue.shade700,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              child: const Text('Retry xóa', style: TextStyle(fontSize: 12)),
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
