import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_page_header.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../locations/data/place_repository.dart';
import '../../data/administrative_area_repository.dart';
import '../../data/models/administrative_area_model.dart';
import '../../domain/vietnam_region_mapping.dart';

/// Tóm tắt kết quả xử lý của một đợt liên kết tuần tự (tối đa 50 địa điểm).
class _BatchChunkLog {
  final int chunkIndex;
  final int count;
  final int successCount;
  final int failureCount;
  final int skippedCount;
  final String? errorMessage;

  const _BatchChunkLog({
    required this.chunkIndex,
    required this.count,
    required this.successCount,
    required this.failureCount,
    required this.skippedCount,
    this.errorMessage,
  });
}

enum _AreaSortField { code, name }

/// Phase 4 (IDs 5.6, 5.7, 5.8) — Giao diện bảng ngang phân cấp tương tác
/// cho Quản lý khu vực hành chính, thống kê bao phủ và liên kết hàng loạt.
class AdminAdministrativeAreasScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final AdministrativeAreaRepository? repository;
  final PlaceRepository? placeRepository;

  const AdminAdministrativeAreasScreen({
    super.key,
    required this.authNotifier,
    this.repository,
    this.placeRepository,
  });

  @override
  State<AdminAdministrativeAreasScreen> createState() =>
      _AdminAdministrativeAreasScreenState();
}

class _AdminAdministrativeAreasScreenState
    extends State<AdminAdministrativeAreasScreen> {
  static const int _batchChunkSize = 50;

  late final AdministrativeAreaRepository _repo;
  late final PlaceRepository _placeRepo;

  // Trạng thái thống kê (ID 5.7)
  AdministrativeAreaStatsModel? _stats;
  bool _isLoadingStats = true;
  String? _statsError;
  DateTime? _lastUpdatedAt;

  // Trạng thái bảng phân cấp đơn vị hành chính (ID 5.6)
  List<AdministrativeAreaNodeModel> _provinces = [];
  bool _isLoadingProvinces = true;
  String? _provincesError;
  String _searchQuery = '';
  VietnamRegion _regionFilter = VietnamRegion.all;
  _AreaSortField _sortField = _AreaSortField.code;
  bool _sortAscending = true;
  int _currentPage = 0;
  int _pageSize = 10;
  final Set<String> _expandedProvinces = {};
  final Map<String, List<AdministrativeAreaNodeModel>> _childrenCache = {};
  final Set<String> _loadingChildren = {};
  final Map<String, String> _childrenErrors = {};
  String? _hoveredCode;

  // Trạng thái liên kết hàng loạt tuần tự (ID 5.8)
  bool _dryRun = true;
  bool _overwriteExisting = false;
  bool _isBatchRunning = false;
  int _totalCount = 0;
  int _processedCount = 0;
  int _successCount = 0;
  int _failureCount = 0;
  int _skippedCount = 0;
  final List<int> _failedPlaceIds = [];
  final List<_BatchChunkLog> _chunkLogs = [];
  String? _batchStatusMessage;
  VoidCallback? _dialogRefresh;

  bool get _isAdmin =>
      widget.authNotifier.currentUser?['role']?.toString().toUpperCase() ==
      'ADMIN';

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? AdministrativeAreaRepository();
    _placeRepo = widget.placeRepository ?? PlaceRepository();
    if (_isAdmin) {
      _loadInitialData();
    }
  }

  void _notifyState([VoidCallback? fn]) {
    if (!mounted) return;
    setState(fn ?? () {});
    _dialogRefresh?.call();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_fetchStats(), _fetchProvinces()]);
    if (mounted) {
      setState(() => _lastUpdatedAt = DateTime.now());
    }
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoadingStats = true;
      _statsError = null;
    });
    try {
      final token = widget.authNotifier.token;
      final stats = await _repo.getCoverageStats(token: token);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statsError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _fetchProvinces() async {
    setState(() {
      _isLoadingProvinces = true;
      _provincesError = null;
    });
    try {
      final token = widget.authNotifier.token;
      final provinces = await _repo.getProvinces(token: token);
      if (!mounted) return;
      setState(() {
        _provinces = provinces;
        _isLoadingProvinces = false;
        final total = _filteredAndSortedProvinces.length;
        final totalPages = total == 0 ? 1 : (total / _pageSize).ceil();
        if (_currentPage >= totalPages) {
          _currentPage = totalPages - 1;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _provincesError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingProvinces = false;
      });
    }
  }

  Future<void> _toggleProvinceExpansion(
    AdministrativeAreaNodeModel province, {
    bool forceReload = false,
  }) async {
    final code = province.code;
    if (!forceReload && _expandedProvinces.contains(code)) {
      setState(() => _expandedProvinces.remove(code));
      return;
    }

    setState(() {
      _expandedProvinces.add(code);
    });

    if (!forceReload && _childrenCache.containsKey(code)) {
      return;
    }

    setState(() {
      _loadingChildren.add(code);
      _childrenErrors.remove(code);
    });

    try {
      final token = widget.authNotifier.token;
      final children = await _repo.getChildren(code, token: token);
      if (!mounted) return;
      setState(() {
        _childrenCache[code] = children;
        _loadingChildren.remove(code);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _childrenErrors[code] = e.toString().replaceFirst('Exception: ', '');
        _loadingChildren.remove(code);
      });
    }
  }

  Future<List<int>> _collectAllPlaceIds() async {
    final token = widget.authNotifier.token;
    final ids = <int>[];
    int page = 0;
    int totalPages = 1;

    while (page < totalPages) {
      final res = await _placeRepo.getAdminPlacesPaged(
        page: page,
        size: _batchChunkSize,
        token: token,
      );
      for (final p in res.content) {
        ids.add(p.placeId);
      }
      totalPages = res.totalPages > 0 ? res.totalPages : 1;
      page++;
      if (res.content.isEmpty) break;
    }

    return ids;
  }

  Future<void> _runBatchResolve({List<int>? retryIds}) async {
    if (_isBatchRunning) return;

    _notifyState(() {
      _isBatchRunning = true;
      _batchStatusMessage = retryIds == null
          ? 'Đang thu thập danh sách địa điểm...'
          : 'Đang chuẩn bị chạy lại ${retryIds.length} địa điểm thất bại...';
      _totalCount = retryIds?.length ?? 0;
      _processedCount = 0;
      _successCount = 0;
      _failureCount = 0;
      _skippedCount = 0;
      _chunkLogs.clear();
    });

    try {
      final List<int> targetIds = retryIds != null
          ? List<int>.from(retryIds)
          : await _collectAllPlaceIds();

      if (!mounted) return;

      if (targetIds.isEmpty) {
        _notifyState(() {
          _isBatchRunning = false;
          _totalCount = 0;
          _batchStatusMessage = 'Không có địa điểm nào cần xử lý.';
        });
        return;
      }

      _notifyState(() {
        _totalCount = targetIds.length;
        _failedPlaceIds.clear();
        _batchStatusMessage = _dryRun
            ? 'Đang chạy thử tuần tự (tối đa $_batchChunkSize địa điểm / đợt)...'
            : 'Đang thực thi liên kết tuần tự (tối đa $_batchChunkSize địa điểm / đợt)...';
      });

      final token = widget.authNotifier.token;
      int chunkIdx = 0;

      for (int i = 0; i < targetIds.length; i += _batchChunkSize) {
        if (!mounted) return;
        chunkIdx++;
        final end = (i + _batchChunkSize < targetIds.length)
            ? i + _batchChunkSize
            : targetIds.length;
        final chunk = targetIds.sublist(i, end);

        try {
          final report = await _repo.batchResolve(
            placeIds: chunk,
            dryRun: _dryRun,
            overwriteExisting: _overwriteExisting,
            token: token,
          );

          int chunkSuccess = 0;
          int chunkFailure = 0;
          int chunkSkipped = report.skippedCount;

          for (final r in report.results) {
            if (r.currentlyLinked || r.eligibleForAutoLink) {
              chunkSuccess++;
            } else if (r.confidence == 'NO_MATCH' ||
                r.confidence == 'AMBIGUOUS' ||
                r.confidence == 'UNVERIFIED') {
              chunkFailure++;
              if (!_failedPlaceIds.contains(r.placeId)) {
                _failedPlaceIds.add(r.placeId);
              }
            } else {
              chunkSkipped++;
            }
          }

          if (!mounted) return;
          _notifyState(() {
            _processedCount += chunk.length;
            _successCount += chunkSuccess;
            _failureCount += chunkFailure;
            _skippedCount += chunkSkipped;
            _chunkLogs.add(
              _BatchChunkLog(
                chunkIndex: chunkIdx,
                count: chunk.length,
                successCount: chunkSuccess,
                failureCount: chunkFailure,
                skippedCount: chunkSkipped,
              ),
            );
          });
        } catch (e) {
          for (final id in chunk) {
            if (!_failedPlaceIds.contains(id)) {
              _failedPlaceIds.add(id);
            }
          }
          if (!mounted) return;
          _notifyState(() {
            _processedCount += chunk.length;
            _failureCount += chunk.length;
            _chunkLogs.add(
              _BatchChunkLog(
                chunkIndex: chunkIdx,
                count: chunk.length,
                successCount: 0,
                failureCount: chunk.length,
                skippedCount: 0,
                errorMessage: e.toString().replaceFirst('Exception: ', ''),
              ),
            );
          });
        }
      }

      if (!mounted) return;
      _notifyState(() {
        _isBatchRunning = false;
        _batchStatusMessage = _dryRun
            ? 'Hoàn tất chạy thử $_processedCount/$_totalCount địa điểm (chưa ghi vào cơ sở dữ liệu).'
            : 'Hoàn tất liên kết $_processedCount/$_totalCount địa điểm.';
      });

      if (!_dryRun) {
        await _fetchStats();
      }
    } catch (e) {
      if (!mounted) return;
      _notifyState(() {
        _isBatchRunning = false;
        _batchStatusMessage =
            'Lỗi chuẩn bị liên kết hàng loạt: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  List<AdministrativeAreaNodeModel> get _filteredAndSortedProvinces {
    final q = _searchQuery.trim().toLowerCase();
    // Thứ tự xử lý: tìm kiếm -> lọc miền -> sắp xếp (phân trang thực hiện sau).
    final filtered = _provinces.where((p) {
      final matchesQuery =
          q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.code.toLowerCase().contains(q) ||
          (p.normalizedName?.toLowerCase().contains(q) ?? false);
      final matchesRegion = matchesProvinceRegionFilter(p.code, _regionFilter);
      return matchesQuery && matchesRegion;
    }).toList();

    filtered.sort((a, b) {
      final cmp = _sortField == _AreaSortField.code
          ? a.code.compareTo(b.code)
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return _sortAscending ? cmp : -cmp;
    });
    return filtered;
  }

  void _toggleSort(_AreaSortField field) {
    setState(() {
      if (_sortField == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortField = field;
        _sortAscending = true;
      }
    });
  }

  String _formatUpdatedTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void _openBatchResolveDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: !_isBatchRunning,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _dialogRefresh = () {
              if (dialogContext.mounted) {
                setDialogState(() {});
              }
            };
            final pendingCount = (_totalCount - _processedCount).clamp(
              0,
              _totalCount,
            );

            return AlertDialog(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.playlist_play_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Liên kết địa điểm hàng loạt',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Xử lý tuần tự tối đa 50 địa điểm mỗi đợt từ dữ liệu hệ thống',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Đóng',
                    onPressed: _isBatchRunning
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 14),
                      if (_dryRun)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Switch(
                                  value: _dryRun,
                                  onChanged: _isBatchRunning
                                      ? null
                                      : (val) =>
                                            _notifyState(() => _dryRun = val),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Chạy thử',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16, color: AppColors.border),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Switch(
                                  value: _overwriteExisting,
                                  onChanged: _isBatchRunning
                                      ? null
                                      : (val) => _notifyState(
                                          () => _overwriteExisting = val,
                                        ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ghi đè liên kết',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_overwriteExisting) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.errorLight,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xs,
                                  ),
                                  border: Border.all(
                                    color: AppColors.errorBorder,
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                      color: AppColors.error,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Cảnh báo: Khi tắt Chế độ chạy thử, liên kết hành chính cũ sẽ bị thay thế nếu tìm thấy đơn vị mới.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.error,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            icon: _isBatchRunning
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _dryRun
                                        ? Icons.play_arrow_rounded
                                        : Icons.play_arrow,
                                    size: 18,
                                  ),
                            label: Text(
                              _dryRun
                                  ? 'Chạy thử liên kết'
                                  : 'Thực thi liên kết',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _dryRun
                                  ? const Color.fromARGB(255, 78, 192, 7)
                                  : AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onPressed: _isBatchRunning
                                ? null
                                : () => _runBatchResolve(),
                          ),
                          if (_failedPlaceIds.isNotEmpty)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.replay, size: 16),
                              label: Text(
                                'Chạy lại địa điểm thất bại (${_failedPlaceIds.length})',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(
                                  color: AppColors.errorBorder,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: _isBatchRunning
                                  ? null
                                  : () => _runBatchResolve(
                                      retryIds: _failedPlaceIds,
                                    ),
                            ),
                        ],
                      ),
                      if (_batchStatusMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _dryRun
                                ? const Color(0xFFFFFBEB)
                                : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            border: Border.all(
                              color: _dryRun
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFFBBF7D0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _dryRun
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF15803D),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _dryRun ? 'CHẠY THỬ' : 'THỰC THI',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _batchStatusMessage!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final items = [
                            (
                              label: 'Tổng số địa điểm',
                              value: _totalCount,
                              color: AppColors.textPrimary,
                            ),
                            (
                              label: 'Đã xử lý',
                              value: _processedCount,
                              color: AppColors.primary,
                            ),
                            (
                              label: 'Thành công',
                              value: _successCount,
                              color: AppColors.success,
                            ),
                            (
                              label: 'Thất bại',
                              value: _failureCount,
                              color: AppColors.error,
                            ),
                            (
                              label: 'Bỏ qua',
                              value: _skippedCount,
                              color: AppColors.textSecondary,
                            ),
                            (
                              label: 'Chờ xử lý',
                              value: pendingCount,
                              color: AppColors.warning,
                            ),
                          ];
                          final cols = constraints.maxWidth >= 460 ? 3 : 2;
                          final rows = <Widget>[];
                          for (int i = 0; i < items.length; i += cols) {
                            if (i > 0) rows.add(const SizedBox(height: 10));
                            final rowChildren = <Widget>[];
                            for (int c = 0; c < cols; c++) {
                              if (c > 0) {
                                rowChildren.add(const SizedBox(width: 10));
                              }
                              final item = items[i + c];
                              rowChildren.add(
                                Expanded(
                                  child: _buildProgressBadge(
                                    item.label,
                                    item.value,
                                    item.color,
                                  ),
                                ),
                              );
                            }
                            rows.add(
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: rowChildren,
                                ),
                              ),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: rows,
                          );
                        },
                      ),
                      if (_chunkLogs.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Chi tiết từng đợt xử lý',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _chunkLogs.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final log = _chunkLogs[index];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: log.errorMessage != null
                                      ? AppColors.error.withValues(alpha: 0.08)
                                      : AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Đợt #${log.chunkIndex} (${log.count} địa điểm)',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        log.errorMessage != null
                                            ? 'Lỗi đợt: ${log.errorMessage}'
                                            : 'Thành công: ${log.successCount} • Thất bại: ${log.failureCount} • Bỏ qua: ${log.skippedCount}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: log.errorMessage != null
                                              ? AppColors.error
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isBatchRunning
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Đóng'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      _dialogRefresh = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.gpp_bad_outlined, size: 52, color: AppColors.error),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Truy cập bị từ chối',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Bạn cần quyền Quản trị viên để quản lý khu vực hành chính và liên kết địa điểm hàng loạt.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filteredProvinces = _filteredAndSortedProvinces;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: 'Quản lý khu vực hành chính',
            actions: [
              if (_lastUpdatedAt != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'Cập nhật lúc ${_formatUpdatedTime(_lastUpdatedAt)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCompactStatsStrip(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildManagementConsoleCard(filteredProvinces),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dải thống kê gọn phía trên thanh công cụ (ID 5.7).
  Widget _buildCompactStatsStrip() {
    if (_isLoadingStats) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              'Đang tải thống kê độ bao phủ khu vực hành chính...',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_statsError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.errorBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Không thể tải thống kê độ bao phủ: $_statsError',
                style: const TextStyle(fontSize: 12.5, color: AppColors.error),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text('Thử lại'),
              onPressed: _fetchStats,
            ),
          ],
        ),
      );
    }

    final stats = _stats;
    if (stats == null || stats.totalPlaces == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.textMuted, size: 18),
            SizedBox(width: 10),
            Text(
              'Chưa có dữ liệu địa điểm để thống kê độ bao phủ.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 20,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildInlineStat(
                    label: 'Tổng số địa điểm',
                    value: '${stats.totalPlaces}',
                    textColor: AppColors.textPrimary,
                    bgColor: AppColors.surfaceSubtle,
                  ),
                  _buildInlineStat(
                    label: 'Đã liên kết',
                    value: '${stats.linkedPlaces}',
                    textColor: const Color(0xFF15803D),
                    bgColor: const Color(0xFFF0FDF4),
                  ),
                  _buildInlineStat(
                    label: 'Chưa liên kết',
                    value: '${stats.unlinkedPlaces}',
                    textColor: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                  ),
                  _buildInlineStat(
                    label: 'Tỷ lệ bao phủ',
                    value: '${stats.coveragePercentage.toStringAsFixed(2)}%',
                    textColor: AppColors.primary,
                    bgColor: AppColors.primaryLight,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (stats.coveragePercentage / 100.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.surfaceSubtle,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineStat({
    required String label,
    required String value,
    required Color textColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Bảng quản lý trung tâm theo bố cục thanh công cụ + bảng ngang phân cấp.
  Widget _buildManagementConsoleCard(
    List<AdministrativeAreaNodeModel> filteredProvinces,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(filteredProvinces.length),
          const Divider(height: 1, color: AppColors.border),
          _buildProvincesTableSection(filteredProvinces),
        ],
      ),
    );
  }

  Widget _buildToolbar(int visibleCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hàng 1: Tiêu đề + số lượng đơn vị + các nút thao tác
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Đơn vị hành chính cấp tỉnh',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'Tổng số đơn vị: ${_provinces.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Làm mới dữ liệu'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderStrong),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onPressed: _isBatchRunning ? null : _loadInitialData,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.playlist_play_outlined, size: 18),
                    label: Text(
                      _isBatchRunning
                          ? 'Đang liên kết ($_processedCount/$_totalCount)...'
                          : 'Liên kết hàng loạt',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onPressed: _openBatchResolveDialog,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Hàng 2: Ô tìm kiếm + bộ lọc khu vực địa lý + số kết quả sau lọc
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 340,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Tìm kiếm khu vực hành chính theo tên hoặc mã...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() {
                    _searchQuery = val;
                    _currentPage = 0;
                    _expandedProvinces.clear();
                  }),
                ),
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<VietnamRegion>(
                  initialValue: _regionFilter,
                  isDense: true,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Khu vực địa lý',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  items: VietnamRegion.values
                      .map(
                        (region) => DropdownMenuItem<VietnamRegion>(
                          value: region,
                          child: Text(region.label),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _regionFilter = val;
                        _currentPage = 0;
                        _expandedProvinces.clear();
                      });
                    }
                  },
                ),
              ),
              Text(
                'Kết quả: $visibleCount/${_provinces.length} đơn vị',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProvincesTableSection(
    List<AdministrativeAreaNodeModel> filteredProvinces,
  ) {
    if (_isLoadingProvinces) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_provincesError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.errorLight,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.errorBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Không thể tải danh sách tỉnh/thành: $_provincesError',
                  style: const TextStyle(fontSize: 13, color: AppColors.error),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('Thử lại'),
                onPressed: _fetchProvinces,
              ),
            ],
          ),
        ),
      );
    }

    if (filteredProvinces.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            'Không có đơn vị hành chính nào phù hợp.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
      );
    }

    final totalFiltered = filteredProvinces.length;
    final totalPages =
        totalFiltered == 0 ? 1 : (totalFiltered / _pageSize).ceil();
    final safePage = _currentPage.clamp(0, totalPages - 1);
    final startIndex = safePage * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalFiltered);
    final pagedProvinces = filteredProvinces.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final tableWidth = constraints.maxWidth < 760
                ? 760.0
                : constraints.maxWidth;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTableHeader(),
                    const Divider(height: 1, color: AppColors.border),
                    ...pagedProvinces.map(_buildProvinceAndChildrenBlock),
                  ],
                ),
              ),
            );
          },
        ),
        _buildPaginationBar(
          totalFiltered: totalFiltered,
          currentPage: safePage,
          totalPages: totalPages,
          startIndex: startIndex,
          endIndex: endIndex,
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: AppColors.surfaceSubtle,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: _buildSortableHeaderCell('Mã đơn vị', _AreaSortField.code),
          ),
          Expanded(
            flex: 4,
            child: _buildSortableHeaderCell('Tên đơn vị', _AreaSortField.name),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Loại đơn vị',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Đơn vị trực thuộc',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(
            width: 170,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Thao tác',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortableHeaderCell(String label, _AreaSortField field) {
    final isActive = _sortField == field;
    return InkWell(
      onTap: () => _toggleSort(field),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isActive
                ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 14,
            color: isActive ? AppColors.primary : AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildProvinceAndChildrenBlock(AdministrativeAreaNodeModel province) {
    final isExpanded = _expandedProvinces.contains(province.code);
    final isLoadingChildren = _loadingChildren.contains(province.code);
    final children = _childrenCache[province.code];
    final childError = _childrenErrors[province.code];
    final isHovered = _hoveredCode == province.code;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hoveredCode = province.code),
          onExit: (_) => setState(() {
            if (_hoveredCode == province.code) _hoveredCode = null;
          }),
          child: InkWell(
            onTap: () => _toggleProvinceExpansion(province),
            child: Container(
              color: isExpanded
                  ? const Color(0xFFFFF8F9)
                  : (isHovered ? AppColors.surfaceSubtle : AppColors.surface),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: Row(
                      children: [
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_right,
                          size: 18,
                          color: isExpanded
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            province.code,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      province.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Cấp tỉnh',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      children != null
                          ? '${children.length} đơn vị trực thuộc'
                          : '—',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: children != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: children != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: Icon(
                          isExpanded
                              ? Icons.unfold_less
                              : Icons.account_tree_outlined,
                          size: 15,
                        ),
                        label: Text(
                          isExpanded ? 'Thu gọn' : 'Xem trực thuộc',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: isExpanded
                              ? AppColors.textSecondary
                              : AppColors.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _toggleProvinceExpansion(province),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded) ...[
          if (isLoadingChildren)
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.fromLTRB(48, 12, 16, 12),
              child: const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Đang tải danh sách đơn vị trực thuộc...',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else if (childError != null)
            Container(
              color: const Color(0xFFFEF2F2),
              padding: const EdgeInsets.fromLTRB(48, 10, 16, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Không thể tải đơn vị trực thuộc: $childError',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        _toggleProvinceExpansion(province, forceReload: true),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          else if (children == null || children.isEmpty)
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.fromLTRB(48, 12, 16, 12),
              child: const Text(
                'Không có đơn vị trực thuộc.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
            )
          else
            ...children.map(_buildChildRow),
        ],
        const Divider(height: 1, color: AppColors.border),
      ],
    );
  }

  Widget _buildChildRow(AdministrativeAreaNodeModel child) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
          left: BorderSide(color: AppColors.primaryBorder, width: 3),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  const Text(
                    '↳',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    child.code,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              child.name,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              child.areaTypeLabel,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Cấp dưới',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 170),
        ],
      ),
    );
  }

  Widget _buildPaginationBar({
    required int totalFiltered,
    required int currentPage,
    required int totalPages,
    required int startIndex,
    required int endIndex,
  }) {
    final displayStart = totalFiltered == 0 ? 0 : startIndex + 1;
    final canGoPrev = currentPage > 0;
    final canGoNext = currentPage < totalPages - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Hiển thị $displayStart–$endIndex trên $totalFiltered đơn vị',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Số dòng / trang:',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _pageSize,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: const [10, 20, 50]
                        .map(
                          (size) => DropdownMenuItem<int>(
                            value: size,
                            child: Text(
                              '$size',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null && val != _pageSize) {
                        setState(() {
                          _pageSize = val;
                          _currentPage = 0;
                          _expandedProvinces.clear();
                        });
                      }
                    },
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.chevron_left, size: 16),
                    label: const Text(
                      'Trang trước',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: canGoPrev
                        ? () => setState(() {
                              _currentPage = currentPage - 1;
                              _expandedProvinces.clear();
                            })
                        : null,
                  ),
                  const SizedBox(width: 6),
                  ...List.generate(totalPages, (idx) {
                    final isSelected = idx == currentPage;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        onTap: isSelected
                            ? null
                            : () => setState(() {
                                  _currentPage = idx;
                                  _expandedProvinces.clear();
                                }),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: canGoNext
                        ? () => setState(() {
                              _currentPage = currentPage + 1;
                              _expandedProvinces.clear();
                            })
                        : null,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Trang sau', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBadge(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
