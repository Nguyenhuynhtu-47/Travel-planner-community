import 'dart:async';

import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/network/api_exception.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';
import 'package:travel_planner_web/features/notifications/data/announcement_admin_repository.dart';
import 'package:travel_planner_web/shared/widgets/admin_data_table.dart';
import 'package:travel_planner_web/shared/widgets/admin_status_badge.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final AnnouncementAdminRepository repository;

  const AdminAnnouncementsScreen({
    super.key,
    required this.authNotifier,
    required this.repository,
  });

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  Map<String, int> _summary = const {};
  Timer? _debounce;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _status;
  String? _type;
  String _query = '';
  int _page = 0;
  int _totalPages = 0;
  int _totalElements = 0;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = widget.authNotifier.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Phiên đăng nhập đã hết hạn.';
        _items = const [];
      });
      return;
    }
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
      _error = null;
      _items = const [];
    });
    try {
      final result = await widget.repository.list(
        token,
        page: _page,
        status: _status,
        type: _type,
        query: _query,
      );
      if (!mounted || version != _requestVersion) return;
      final summary = await widget.repository.summary(token);
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _items = (result['content'] as List? ?? const [])
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList();
        _summary = Map<String, int>.from(summary);
        _totalPages = (result['totalPages'] as num?)?.toInt() ?? 0;
        _totalElements = (result['totalElements'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } on ApiException catch (exception) {
      _setError(exception.message, version);
    } catch (_) {
      _setError('Không tải được danh sách thông báo.', version);
    }
  }

  void _setError(String message, int version) {
    if (!mounted || version != _requestVersion) return;
    setState(() {
      _loading = false;
      _error = message;
      _items = const [];
    });
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _page = 0;
      });
      _load();
    });
  }

  void _clearFilters() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _query = '';
      _status = null;
      _type = null;
      _page = 0;
    });
    _load();
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AnnouncementFormDialog(item: item),
    );
    if (request == null || !mounted) return;
    final token = widget.authNotifier.token;
    if (token == null) return;
    setState(() => _saving = true);
    try {
      if (item == null) {
        await widget.repository.create(token, request);
      } else {
        await widget.repository.update(
          token,
          (item['id'] as num).toInt(),
          request,
        );
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _page = 0;
      });
      _message(item == null ? 'Đã tạo thông báo.' : 'Đã cập nhật thông báo.');
      await _load();
    } on ApiException catch (exception) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message(exception.message, error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Không thể lưu thông báo.', error: true);
    }
  }

  Future<void> _transition(
    Map<String, dynamic> item, {
    required bool publish,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(publish ? 'Gửi thông báo ngay?' : 'Hủy thông báo?'),
        content: Text(
          publish
              ? 'Thông báo sẽ được công khai ngay cho tất cả tài khoản đang hoạt động.'
              : 'Thông báo sẽ ngừng hiển thị với người dùng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(publish ? 'Gửi ngay' : 'Xác nhận hủy'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final token = widget.authNotifier.token;
    if (token == null) return;
    setState(() => _saving = true);
    try {
      final id = (item['id'] as num).toInt();
      if (publish) {
        await widget.repository.publish(token, id);
      } else {
        await widget.repository.cancel(token, id);
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _page = 0;
      });
      _message(publish ? 'Đã công khai thông báo.' : 'Đã hủy thông báo.');
      await _load();
    } on ApiException catch (exception) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message(exception.message, error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Không thể cập nhật trạng thái thông báo.', error: true);
    }
  }

  void _showDetail(Map<String, dynamic> item) {
    final status = _displayStatus(item);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(item['title']?.toString() ?? 'Thông báo')),
            AdminStatusBadge(status: status),
          ],
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detail('Loại', _typeLabel(item['type'])),
                _detail('Người tạo', item['createdBy']?.toString()),
                _detail('Ngày tạo', _formatDateTime(item['createdAt'])),
                _detail(
                  status == 'DRAFT' ? 'Lịch công khai' : 'Đã công khai',
                  _formatDateTime(item['publishedAt']),
                ),
                _detail('Hết hạn', _formatDateTime(item['expiresAt'])),
                const Divider(height: 28),
                const Text('Nội dung', style: AppTypography.labelControl),
                const SizedBox(height: AppSpacing.sm),
                SelectableText(
                  item['body']?.toString() ?? '',
                  style: AppTypography.bodyData,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 125, child: Text(label, style: AppTypography.bodyData)),
        Expanded(
          child: Text(
            value == null || value.isEmpty ? '—' : value,
            style: AppTypography.bodyMedium,
          ),
        ),
      ],
    ),
  );

  void _message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: error ? AppColors.error : AppColors.textPrimary,
      ),
    );
  }

  bool get _hasFilters => _query.isNotEmpty || _status != null || _type != null;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông báo hệ thống',
                    style: AppTypography.titlePage,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tạo, đặt lịch và quản lý thông báo hiển thị cho người dùng.',
                    style: AppTypography.bodyData.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _saving ? null : () => _edit(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tạo thông báo'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildSummary(),
        const SizedBox(height: AppSpacing.xl),
        _buildToolbar(),
        if (_error != null) _buildError(),
        const SizedBox(height: AppSpacing.lg),
        Expanded(child: _buildTable()),
      ],
    ),
  );

  Widget _buildSummary() => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final itemWidth = width >= 900
          ? (width - AppSpacing.md * 3) / 4
          : width >= 520
          ? (width - AppSpacing.md) / 2
          : width;
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          _SummaryCard(
            width: itemWidth,
            label: 'Tổng thông báo',
            value: _summary['total'] ?? 0,
            icon: Icons.campaign_outlined,
            color: AppColors.info,
          ),
          _SummaryCard(
            width: itemWidth,
            label: 'Chờ công khai',
            value: _summary['draft'] ?? 0,
            icon: Icons.schedule_outlined,
            color: AppColors.warning,
          ),
          _SummaryCard(
            width: itemWidth,
            label: 'Đã công khai',
            value: _summary['published'] ?? 0,
            icon: Icons.send_outlined,
            color: AppColors.success,
          ),
          _SummaryCard(
            width: itemWidth,
            label: 'Đã hủy / hết hạn',
            value: _summary['cancelled'] ?? 0,
            icon: Icons.event_busy_outlined,
            color: AppColors.error,
          ),
        ],
      );
    },
  );

  Widget _buildToolbar() => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceSubtle,
      border: Border.all(color: AppColors.border),
      borderRadius: AppRadius.borderCard,
    ),
    child: Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {});
              _search(value);
            },
            onSubmitted: (value) {
              _debounce?.cancel();
              setState(() {
                _query = value.trim();
                _page = 0;
              });
              _load();
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 19),
              hintText: 'Tìm theo tiêu đề hoặc nội dung',
              isDense: true,
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa từ khóa',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        _search('');
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
            ),
          ),
        ),
        _filterDropdown(
          width: 180,
          label: 'Trạng thái',
          value: _status ?? 'ALL',
          items: const {
            'ALL': 'Mọi trạng thái',
            'DRAFT': 'Chờ công khai',
            'PUBLISHED': 'Đã công khai',
            'CANCELLED': 'Đã hủy / hết hạn',
          },
          onChanged: (value) {
            setState(() {
              _status = value == 'ALL' ? null : value;
              _page = 0;
            });
            _load();
          },
        ),
        _filterDropdown(
          width: 180,
          label: 'Loại thông báo',
          value: _type ?? 'ALL',
          items: const {'ALL': 'Mọi loại', 'SYSTEM': 'Thông báo hệ thống'},
          onChanged: (value) {
            setState(() {
              _type = value == 'ALL' ? null : value;
              _page = 0;
            });
            _load();
          },
        ),
        if (_hasFilters)
          TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
            label: const Text('Xóa bộ lọc'),
          ),
        IconButton(
          tooltip: 'Tải lại',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh, size: 20),
        ),
      ],
    ),
  );

  Widget _filterDropdown({
    required double width,
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: items.entries
          .map(
            (entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(
                entry.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    ),
  );

  Widget _buildError() => Container(
    margin: const EdgeInsets.only(top: AppSpacing.md),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.errorLight,
      border: Border.all(color: AppColors.errorBorder),
      borderRadius: AppRadius.borderCard,
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 19),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            _error!,
            style: AppTypography.bodyData.copyWith(color: AppColors.error),
          ),
        ),
        TextButton(onPressed: _load, child: const Text('Thử lại')),
      ],
    ),
  );

  Widget _buildTable() => AdminDataTable(
    isLoading: _loading,
    emptyIcon: Icon(
      _hasFilters ? Icons.search_off_outlined : Icons.campaign_outlined,
      size: 36,
      color: AppColors.textMuted,
    ),
    emptyMessage: _hasFilters
        ? 'Không tìm thấy thông báo phù hợp. Hãy thử từ khóa hoặc bộ lọc khác.'
        : 'Chưa có thông báo. Chọn “Tạo thông báo” để bắt đầu.',
    minWidth: 1300,
    dataRowHeight: 68,
    currentPage: _page,
    totalPages: _totalPages,
    totalElements: _totalElements,
    pageSize: 20,
    onPageChanged: (value) {
      if (value == _page) return;
      setState(() => _page = value);
      _load();
    },
    columns: const [
      AdminDataColumn(label: SizedBox(width: 260, child: Text('THÔNG BÁO'))),
      AdminDataColumn(label: SizedBox(width: 105, child: Text('LOẠI'))),
      AdminDataColumn(label: SizedBox(width: 115, child: Text('TRẠNG THÁI'))),
      AdminDataColumn(label: SizedBox(width: 105, child: Text('NGƯỜI TẠO'))),
      AdminDataColumn(label: SizedBox(width: 118, child: Text('NGÀY TẠO'))),
      AdminDataColumn(label: SizedBox(width: 128, child: Text('CÔNG KHAI'))),
      AdminDataColumn(label: SizedBox(width: 118, child: Text('HẾT HẠN'))),
      AdminDataColumn(label: SizedBox(width: 200, child: Text('THAO TÁC'))),
    ],
    rows: _items.map((item) {
      final status = _displayStatus(item);
      final draft = status == 'DRAFT';
      final canCancel = status == 'DRAFT' || status == 'PUBLISHED';
      return AdminDataRow(
        onTap: () => _showDetail(item),
        cells: [
          SizedBox(
            width: 260,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  item['body']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyData.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 105, child: Text(_typeLabel(item['type']))),
          SizedBox(width: 115, child: AdminStatusBadge(status: status)),
          SizedBox(
            width: 105,
            child: Text(
              item['createdBy']?.toString() ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 118, child: Text(_formatDateTime(item['createdAt']))),
          SizedBox(
            width: 128,
            child: Text(_formatDateTime(item['publishedAt'])),
          ),
          SizedBox(width: 118, child: Text(_formatDateTime(item['expiresAt']))),
          SizedBox(
            width: 200,
            child: Row(
              children: [
                _action(Icons.visibility_outlined, 'Xem chi tiết', () {
                  _showDetail(item);
                }),
                if (draft)
                  _action(Icons.edit_outlined, 'Chỉnh sửa', () => _edit(item)),
                if (draft)
                  _action(
                    Icons.send_outlined,
                    'Gửi thông báo ngay',
                    () => _transition(item, publish: true),
                  ),
                if (canCancel)
                  _action(
                    Icons.cancel_outlined,
                    'Hủy thông báo',
                    () => _transition(item, publish: false),
                  ),
              ],
            ),
          ),
        ],
      );
    }).toList(),
  );

  Widget _action(IconData icon, String tooltip, VoidCallback action) =>
      IconButton(
        tooltip: tooltip,
        onPressed: _saving ? null : action,
        icon: Icon(icon, size: 18),
      );

  String _displayStatus(Map<String, dynamic> item) {
    final expiry = DateTime.tryParse(item['expiresAt']?.toString() ?? '');
    if (expiry != null && !expiry.isAfter(_vietnamNow())) return 'EXPIRED';
    return item['status']?.toString() ?? 'DRAFT';
  }

  static String _typeLabel(dynamic value) =>
      value?.toString() == 'SYSTEM' ? 'Hệ thống' : value?.toString() ?? '—';

  static String _formatDateTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '—';
    return '${_two(date.day)}/${_two(date.month)}/${date.year} ${_two(date.hour)}:${_two(date.minute)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static DateTime _vietnamNow() {
    final value = DateTime.now().toUtc().add(const Duration(hours: 7));
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double width;
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.borderCard,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: AppRadius.borderCard,
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: AppTypography.displayKpi),
              Text(
                label,
                style: AppTypography.bodyData.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _AnnouncementFormDialog extends StatefulWidget {
  final Map<String, dynamic>? item;

  const _AnnouncementFormDialog({this.item});

  @override
  State<_AnnouncementFormDialog> createState() =>
      _AnnouncementFormDialogState();
}

class _AnnouncementFormDialogState extends State<_AnnouncementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  DateTime? _publishDate;
  TimeOfDay? _publishTime;
  DateTime? _expiryDate;
  TimeOfDay? _expiryTime;
  String? _timeError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.item?['title']?.toString() ?? '',
    );
    _bodyController = TextEditingController(
      text: widget.item?['body']?.toString() ?? '',
    );
    _titleController.addListener(_refresh);
    _bodyController.addListener(_refresh);
    final published = DateTime.tryParse(
      widget.item?['publishedAt']?.toString() ?? '',
    );
    final expiry = DateTime.tryParse(
      widget.item?['expiresAt']?.toString() ?? '',
    );
    if (published != null) {
      _publishDate = DateTime(published.year, published.month, published.day);
      _publishTime = TimeOfDay.fromDateTime(published);
    }
    if (expiry != null) {
      _expiryDate = DateTime(expiry.year, expiry.month, expiry.day);
      _expiryTime = TimeOfDay.fromDateTime(expiry);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _pickDate(bool publish) async {
    final now = _vietnamNow();
    final current = publish ? _publishDate : _expiryDate;
    final value = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: publish ? 'Chọn ngày công khai' : 'Chọn ngày hết hạn',
    );
    if (value == null) return;
    setState(() {
      if (publish) {
        _publishDate = value;
      } else {
        _expiryDate = value;
      }
      _timeError = null;
    });
  }

  Future<void> _pickTime(bool publish) async {
    if (publish && _publishDate == null) await _pickDate(true);
    if (!publish && _expiryDate == null) await _pickDate(false);
    if (!mounted || (publish ? _publishDate : _expiryDate) == null) return;
    final value = await showTimePicker(
      context: context,
      initialTime: publish
          ? (_publishTime ?? TimeOfDay.fromDateTime(_vietnamNow()))
          : (_expiryTime ?? const TimeOfDay(hour: 0, minute: 0)),
      helpText: publish ? 'Chọn giờ công khai' : 'Chọn giờ hết hạn',
    );
    if (value == null) return;
    setState(() {
      if (publish) {
        _publishTime = value;
      } else {
        _expiryTime = value;
      }
      _timeError = null;
    });
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    if (_publishDate != null && _publishTime == null) {
      setState(() => _timeError = 'Vui lòng chọn giờ công khai.');
      return;
    }
    final publishAt = _combine(_publishDate, _publishTime);
    final expiresAt = _combine(
      _expiryDate,
      _expiryTime ?? const TimeOfDay(hour: 0, minute: 0),
    );
    final now = _vietnamNow();
    if (publishAt != null && !publishAt.isAfter(now)) {
      setState(() => _timeError = 'Thời điểm công khai phải ở tương lai.');
      return;
    }
    if (expiresAt != null && !expiresAt.isAfter(publishAt ?? now)) {
      setState(
        () => _timeError =
            'Thời điểm hết hạn phải sau thời điểm công khai dự kiến.',
      );
      return;
    }
    Navigator.pop(context, {
      'title': _titleController.text.trim(),
      'body': _bodyController.text.trim(),
      'publishedAt': _toApiDateTime(publishAt),
      'expiresAt': _toApiDateTime(expiresAt),
    });
  }

  @override
  Widget build(BuildContext context) => Dialog(
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderDialog),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item == null
                          ? 'Tạo thông báo'
                          : 'Chỉnh sửa thông báo',
                      style: AppTypography.titleSection,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        maxLength: 160,
                        decoration: const InputDecoration(
                          labelText: 'Tiêu đề',
                          hintText: 'Nhập tiêu đề thông báo',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Vui lòng nhập tiêu đề.'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _bodyController,
                        minLines: 5,
                        maxLines: 8,
                        maxLength: 10000,
                        decoration: const InputDecoration(
                          labelText: 'Nội dung',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Vui lòng nhập nội dung.'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        initialValue: 'SYSTEM',
                        decoration: const InputDecoration(
                          labelText: 'Loại thông báo',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'SYSTEM',
                            child: Text('Thông báo hệ thống'),
                          ),
                        ],
                        onChanged: null,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _DateTimeSelector(
                        label: 'Thời gian công khai (tùy chọn)',
                        helper: 'Để trống nếu muốn lưu ở trạng thái chờ và gửi thủ công.',
                        date: _publishDate,
                        time: _publishTime,
                        onDate: () => _pickDate(true),
                        onTime: () => _pickTime(true),
                        onClear: _publishDate == null
                            ? null
                            : () => setState(() {
                                _publishDate = null;
                                _publishTime = null;
                                _timeError = null;
                              }),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _DateTimeSelector(
                        label: 'Thời gian hết hạn (tùy chọn)',
                        helper:
                            'Nếu chỉ chọn ngày, giờ hết hạn mặc định là 00:00.',
                        date: _expiryDate,
                        time: _expiryTime,
                        onDate: () => _pickDate(false),
                        onTime: () => _pickTime(false),
                        onClear: _expiryDate == null
                            ? null
                            : () => setState(() {
                                _expiryDate = null;
                                _expiryTime = null;
                                _timeError = null;
                              }),
                      ),
                      if (_timeError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _timeError!,
                          style: AppTypography.bodyData.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      const Text(
                        'Xem trước',
                        style: AppTypography.labelControl,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          border: Border.all(color: AppColors.border),
                          borderRadius: AppRadius.borderCard,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _titleController.text.trim().isEmpty
                                  ? 'Tiêu đề thông báo'
                                  : _titleController.text.trim(),
                              style: AppTypography.bodyMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _bodyController.text.trim().isEmpty
                                  ? 'Nội dung thông báo sẽ hiển thị tại đây.'
                                  : _bodyController.text.trim(),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyData,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Đóng'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: _submit,
                    child: Text(
                      widget.item == null ? 'Lưu thông báo' : 'Lưu thay đổi',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  static DateTime? _combine(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  static String? _toApiDateTime(DateTime? value) {
    if (value == null) return null;
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-${two(value.month)}-${two(value.day)}T${two(value.hour)}:${two(value.minute)}:00';
  }

  static DateTime _vietnamNow() {
    final value = DateTime.now().toUtc().add(const Duration(hours: 7));
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
    );
  }
}

class _DateTimeSelector extends StatelessWidget {
  final String label;
  final String helper;
  final DateTime? date;
  final TimeOfDay? time;
  final VoidCallback onDate;
  final VoidCallback onTime;
  final VoidCallback? onClear;

  const _DateTimeSelector({
    required this.label,
    required this.helper,
    required this.date,
    required this.time,
    required this.onDate,
    required this.onTime,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.labelControl)),
          if (onClear != null)
            TextButton(onPressed: onClear, child: const Text('Xóa')),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          OutlinedButton.icon(
            onPressed: onDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 17),
            label: Text(
              date == null
                  ? 'Chọn ngày'
                  : '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}',
            ),
          ),
          OutlinedButton.icon(
            onPressed: onTime,
            icon: const Icon(Icons.schedule_outlined, size: 18),
            label: Text(
              time == null
                  ? 'Chọn giờ'
                  : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}',
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        '$helper Múi giờ Việt Nam (UTC+7).',
        style: AppTypography.bodyData.copyWith(
          color: AppColors.textMuted,
          fontSize: 12,
        ),
      ),
    ],
  );
}
