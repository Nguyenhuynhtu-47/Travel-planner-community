import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_data_table.dart';
import '../../../../shared/widgets/admin_page_header.dart';
import '../../../../shared/widgets/admin_status_badge.dart';
import '../../../../shared/widgets/admin_toolbar.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../users/presentation/widgets/user_avatar.dart';
import '../../data/itinerary_admin_repository.dart';
import '../../data/models/admin_itinerary_model.dart';
import '../widgets/itinerary_detail_dialog.dart';
import '../widgets/moderate_itinerary_dialog.dart';
import '../widgets/private_inspect_dialog.dart';

class AdminItinerariesScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final ItineraryAdminRepository? repository;
  final bool embedded;

  const AdminItinerariesScreen({
    super.key,
    required this.authNotifier,
    this.repository,
    this.embedded = false,
  });

  @override
  State<AdminItinerariesScreen> createState() => _AdminItinerariesScreenState();
}

class _AdminItinerariesScreenState extends State<AdminItinerariesScreen> {
  late final ItineraryAdminRepository _repository;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _loading = false;
  List<AdminItineraryModel> _itineraries = [];
  int _page = 0;
  final int _pageSize = 20;
  int _totalPages = 0;
  int _totalElements = 0;

  String _searchKeyword = '';
  String _statusFilter = 'ALL';
  String? _errorMessage;

  String? get _token => widget.authNotifier.token;

  bool get _isAdmin {
    final role =
        widget.authNotifier.currentUser?['role']?.toString().toUpperCase();
    return role == 'ADMIN';
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ItineraryAdminRepository();
    if (_isAdmin) {
      _loadItineraries();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItineraries() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final res = await _repository.getItinerariesPaged(
        keyword: _searchKeyword.trim().isEmpty ? null : _searchKeyword.trim(),
        status: _statusFilter == 'ALL' ? null : _statusFilter,
        page: _page,
        size: _pageSize,
        token: token,
      );
      if (mounted) {
        setState(() {
          _itineraries = res.content;
          _totalElements = res.totalElements;
          _totalPages = res.totalPages;
          _page = res.page;
        });
      }
    } catch (e) {
      final msg = e is ApiException && e.message.isNotEmpty
          ? e.message
          : 'Không thể tải danh sách lịch trình';
      if (mounted) {
        setState(() => _errorMessage = msg);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _searchKeyword = value;
        _page = 0;
      });
      _loadItineraries();
    });
  }

  void _onClearFilters() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchKeyword = '';
      _statusFilter = 'ALL';
      _page = 0;
    });
    _loadItineraries();
  }

  Future<void> _openDetail(AdminItineraryModel item) async {
    final token = _token;
    if (token == null) return;
    await ItineraryDetailDialog.show(
      context: context,
      itineraryId: item.itineraryId,
      token: token,
      repository: _repository,
    );
  }

  Future<void> _openPrivateInspection() async {
    final token = _token;
    if (token == null) return;

    final detail = await showPrivateInspectDialog(
      context: context,
      onInspect: ({
        required int itineraryId,
        required int reportId,
        required String inspectionReason,
      }) =>
          _repository.getItineraryDetail(
        itineraryId,
        reportId: reportId,
        inspectionReason: inspectionReason,
        token: token,
      ),
    );

    if (detail != null && mounted) {
      await ItineraryDetailDialog.show(
        context: context,
        itineraryId: detail.itinerary.itineraryId,
        token: token,
        repository: _repository,
        initialDetail: detail,
      );
    }
  }

  Future<void> _openModerate(AdminItineraryModel item) async {
    final token = _token;
    if (token == null) return;

    final isHide = item.status != 'HIDDEN';
    final confirmed = await showModerateItineraryDialog(
      context: context,
      itinerary: item,
      onSubmit: (targetStatus, reason) => _repository.moderateItinerary(
        item.itineraryId,
        status: targetStatus,
        reason: reason,
        token: token,
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHide
                ? 'Đã ẩn lịch trình #${item.itineraryId} và ghi nhận Audit Log.'
                : 'Đã khôi phục lịch trình #${item.itineraryId} và ghi nhận Audit Log.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadItineraries();
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const Center(
        child: Text(
          'Bạn không có quyền truy cập chức năng Quản lý lịch trình.',
          style: TextStyle(color: AppColors.error, fontSize: 14),
        ),
      );
    }

    final hasFilters =
        _searchKeyword.trim().isNotEmpty || _statusFilter != 'ALL';

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          title: 'Quản lý Lịch trình',
          actions: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Tổng: $_totalElements lịch trình',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _openPrivateInspection,
              icon: const Icon(Icons.policy_outlined, size: 16),
              label: const Text('Kiểm tra PRIVATE'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryAccessible,
                side: const BorderSide(color: AppColors.primaryBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _loading ? null : _loadItineraries,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Làm mới'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.borderStrong),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
          ],
        ),
        AdminToolbar(
          searchField: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onSubmitted: (val) {
              _debounce?.cancel();
              setState(() {
                _searchKeyword = val;
                _page = 0;
              });
              _loadItineraries();
            },
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              hintText: 'Tìm theo tên lịch trình, địa điểm, người tạo...',
              hintStyle:
                  const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              prefixIcon:
                  const Icon(Icons.search, size: 16, color: AppColors.textMuted),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 15),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          filters: [
            _buildDropdown(
              value: _statusFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('Tất cả trạng thái')),
                DropdownMenuItem(value: 'ACTIVE', child: Text('Hoạt động')),
                DropdownMenuItem(value: 'HIDDEN', child: Text('Đã ẩn')),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _statusFilter = val;
                  _page = 0;
                });
                _loadItineraries();
              },
            ),
            if (hasFilters)
              TextButton.icon(
                onPressed: _onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
                label: const Text('Xóa bộ lọc'),
              ),
          ],
        ),
        if (_errorMessage != null)
          Container(
            margin: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.errorBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: _loadItineraries,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth =
                    constraints.maxWidth.isFinite ? constraints.maxWidth : 1080.0;
                final tableMinWidth =
                    availableWidth > 1000.0 ? availableWidth : 1000.0;
                final contentBudget =
                    (tableMinWidth - 610).clamp(380.0, 900.0);
                final titleColWidth = (contentBudget * 0.56).clamp(210.0, 460.0);
                final creatorColWidth =
                    (contentBudget * 0.44).clamp(170.0, 320.0);

                return AdminDataTable(
                  isLoading: _loading,
                  emptyMessage: 'Không tìm thấy lịch trình nào phù hợp.',
                  minWidth: tableMinWidth,
                  columnSpacing: 14,
                  horizontalMargin: 14,
                  dataRowHeight: 56,
                  currentPage: _page,
                  totalPages: _totalPages,
                  totalElements: _totalElements,
                  pageSize: _pageSize,
                  onPageChanged: (newPage) {
                    if (newPage != _page && newPage >= 0) {
                      setState(() => _page = newPage);
                      _loadItineraries();
                    }
                  },
                  columns: [
                    const AdminDataColumn(
                      label: SizedBox(width: 48, child: Text('ID')),
                    ),
                    AdminDataColumn(
                      label: SizedBox(
                        width: titleColWidth,
                        child: const Text('LỊCH TRÌNH'),
                      ),
                    ),
                    AdminDataColumn(
                      label: SizedBox(
                        width: creatorColWidth,
                        child: const Text('NGƯỜI TẠO'),
                      ),
                    ),
                    const AdminDataColumn(
                      label: SizedBox(width: 96, child: Text('HIỂN THỊ')),
                    ),
                    const AdminDataColumn(
                      label: SizedBox(width: 96, child: Text('TRẠNG THÁI')),
                    ),
                    const AdminDataColumn(
                      label: SizedBox(width: 118, child: Text('NGÀY TẠO')),
                    ),
                    const AdminDataColumn(
                      label: SizedBox(width: 96, child: Text('THAO TÁC')),
                    ),
                  ],
                  rows: _itineraries.map((item) {
                    final isHidden = item.status == 'HIDDEN';
                    final creator = item.creator;

                    return AdminDataRow(
                      onTap: () => _openDetail(item),
                      cells: [
                        SizedBox(
                          width: 48,
                          child: Text(
                            '#${item.itineraryId}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: titleColWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Tooltip(
                                message: item.title,
                                waitDuration: const Duration(milliseconds: 400),
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.location} • ${item.totalDays} ngày',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: creatorColWidth,
                          child: creator == null
                              ? const Text('-',
                                  style: TextStyle(color: AppColors.textMuted))
                              : Row(
                                  children: [
                                    UserAvatar(
                                      avatarUrl: creator.avatar,
                                      displayName: creator.displayName,
                                      size: 30,
                                      fontSize: 11,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            creator.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            '@${creator.handle}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        SizedBox(
                          width: 96,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AdminStatusBadge(
                              status: item.visibility == 'PRIVATE'
                                  ? 'WARNING'
                                  : 'INFO',
                              customLabel: item.visibility == 'PRIVATE'
                                  ? 'PRIVATE'
                                  : 'PUBLIC',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 96,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AdminStatusBadge(status: item.status),
                          ),
                        ),
                        SizedBox(
                          width: 118,
                          child: Text(
                            _formatDateTime(item.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 96,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(36, 36),
                                  fixedSize: const Size(36, 36),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 17,
                                ),
                                tooltip: 'Xem chi tiết',
                                onPressed: () => _openDetail(item),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(36, 36),
                                  fixedSize: const Size(36, 36),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: Icon(
                                  isHidden
                                      ? Icons.restore_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 17,
                                  color: isHidden
                                      ? AppColors.success
                                      : AppColors.warning,
                                ),
                                tooltip: isHidden
                                    ? 'Khôi phục lịch trình'
                                    : 'Ẩn lịch trình',
                                onPressed: () => _openModerate(item),
                              ),
                            ],
                          ),
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
    );

    if (widget.embedded) {
      return content;
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: content,
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
          iconSize: 18,
        ),
      ),
    );
  }
}
