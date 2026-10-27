import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/itinerary_crud_repository.dart';
import '../../data/models/activity_detail.dart';
import '../../data/models/create_activity_request.dart';
import '../../data/models/destination_summary.dart';
import '../../data/models/update_activity_request.dart';

/// Opens a mobile-optimized modal bottom sheet to add or edit an activity.
Future<bool?> showActivityFormDialog(
  BuildContext context, {
  required int itineraryId,
  required int dayId,
  required int dayNumber,
  String? dayTitle,
  ActivityDetail? initialActivity,
  required AuthNotifier authNotifier,
  required ItineraryCrudRepository repository,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (ctx) => ActivityFormBottomSheet(
      itineraryId: itineraryId,
      dayId: dayId,
      dayNumber: dayNumber,
      dayTitle: dayTitle,
      initialActivity: initialActivity,
      authNotifier: authNotifier,
      repository: repository,
    ),
  );
}

/// Alias for [showActivityFormDialog] with explicit bottom sheet naming.
Future<bool?> showActivityFormBottomSheet(
  BuildContext context, {
  required int itineraryId,
  required int dayId,
  required int dayNumber,
  String? dayTitle,
  ActivityDetail? initialActivity,
  required AuthNotifier authNotifier,
  required ItineraryCrudRepository repository,
}) => showActivityFormDialog(
  context,
  itineraryId: itineraryId,
  dayId: dayId,
  dayNumber: dayNumber,
  dayTitle: dayTitle,
  initialActivity: initialActivity,
  authNotifier: authNotifier,
  repository: repository,
);

class ActivityFormBottomSheet extends StatefulWidget {
  final int itineraryId;
  final int dayId;
  final int dayNumber;
  final String? dayTitle;
  final ActivityDetail? initialActivity;
  final AuthNotifier authNotifier;
  final ItineraryCrudRepository repository;

  const ActivityFormBottomSheet({
    super.key,
    required this.itineraryId,
    required this.dayId,
    required this.dayNumber,
    this.dayTitle,
    this.initialActivity,
    required this.authNotifier,
    required this.repository,
  });

  @override
  State<ActivityFormBottomSheet> createState() =>
      _ActivityFormBottomSheetState();
}

class _ActivityFormBottomSheetState extends State<ActivityFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _costController;

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isLoading = false;
  String? _timeErrorMessage;

  int? _selectedDestinationId;
  List<DestinationSummary> _availableDestinations = [];
  bool _loadingDestinations = false;

  bool get _isEditing => widget.initialActivity != null;

  @override
  void initState() {
    super.initState();
    _selectedDestinationId = widget.initialActivity?.destination?.destinationId;
    if (widget.initialActivity?.destination != null) {
      _availableDestinations = [widget.initialActivity!.destination!];
    }
    _fetchDestinations();

    _nameController = TextEditingController(
      text: widget.initialActivity?.name ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.initialActivity?.description ?? '',
    );
    _costController = TextEditingController(
      text:
          widget.initialActivity?.estimatedCost != null &&
              widget.initialActivity!.estimatedCost! > 0
          ? widget.initialActivity!.estimatedCost!.toInt().toString()
          : '',
    );

    if (widget.initialActivity?.startTime != null) {
      _startTime = _parseTimeOfDay(widget.initialActivity!.startTime!);
    }
    if (widget.initialActivity?.endTime != null) {
      _endTime = _parseTimeOfDay(widget.initialActivity!.endTime!);
    }
  }

  Future<void> _fetchDestinations() async {
    setState(() => _loadingDestinations = true);
    try {
      final list = await widget.repository.getDestinations(
        token: widget.authNotifier.token,
      );
      if (mounted) {
        setState(() {
          final merged = <int, DestinationSummary>{};
          if (widget.initialActivity?.destination != null) {
            merged[widget.initialActivity!.destination!.destinationId] =
                widget.initialActivity!.destination!;
          }
          for (final d in list) {
            merged[d.destinationId] = d;
          }
          _availableDestinations = merged.values.toList();
          _loadingDestinations = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDestinations = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _costController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (_) {}
    return null;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  int _timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _startTime = picked;
        _validateTimeRange();
      });
    }
  }

  Future<void> _pickEndTime() async {
    final initial =
        _endTime ??
        (_startTime != null
            ? TimeOfDay(
                hour: (_startTime!.hour + 1) % 24,
                minute: _startTime!.minute,
              )
            : const TimeOfDay(hour: 10, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _endTime = picked;
        _validateTimeRange();
      });
    }
  }

  bool _validateTimeRange() {
    if (_startTime != null && _endTime != null) {
      if (_timeToMinutes(_endTime!) < _timeToMinutes(_startTime!)) {
        setState(() {
          _timeErrorMessage = 'Giờ kết thúc không thể trước giờ bắt đầu';
        });
        return false;
      }
    }
    setState(() {
      _timeErrorMessage = null;
    });
    return true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_validateTimeRange()) return;

    final token = widget.authNotifier.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để thực hiện thao tác.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final rawCost = double.tryParse(_costController.text.trim());
    final startTimeStr = _startTime != null
        ? _formatTimeOfDay(_startTime!)
        : null;
    final endTimeStr = _endTime != null ? _formatTimeOfDay(_endTime!) : null;

    try {
      if (_isEditing) {
        final request = UpdateActivityRequest(
          name: name,
          description: description.isNotEmpty ? description : null,
          destinationId: _selectedDestinationId,
          startTime: startTimeStr,
          endTime: endTimeStr,
          cost: rawCost,
        );
        await widget.repository.updateActivity(
          widget.itineraryId,
          widget.dayId,
          widget.initialActivity!.activityId,
          request,
          token: token,
        );
      } else {
        final request = CreateActivityRequest(
          name: name,
          description: description.isNotEmpty ? description : null,
          destinationId: _selectedDestinationId,
          startTime: startTimeStr,
          endTime: endTimeStr,
          cost: rawCost,
        );
        await widget.repository.addActivity(
          widget.itineraryId,
          widget.dayId,
          request,
          token: token,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã có lỗi xảy ra. Vui lòng thử lại.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final maxHeight = mediaQuery.size.height * 0.88;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutQuad,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag indicator handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _isEditing
                            ? Icons.edit_outlined
                            : Icons.add_task_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing
                                ? 'Chỉnh sửa hoạt động'
                                : 'Thêm hoạt động mới',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            widget.dayTitle != null &&
                                    widget.dayTitle!.isNotEmpty
                                ? 'Ngày ${widget.dayNumber} • ${widget.dayTitle}'
                                : 'Ngày ${widget.dayNumber}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(false),
                      tooltip: 'Đóng',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.hairlineSoft),

              // Scrollable Form content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Activity Name
                        TextFormField(
                          controller: _nameController,
                          enabled: !_isLoading,
                          maxLength: 150,
                          decoration: InputDecoration(
                            labelText: 'Tên hoạt động *',
                            hintText: 'VD: Ăn sáng bánh mì chảo, Check-in Fansipan...',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceSoft,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.hairline,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.hairline,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập tên hoạt động';
                            }
                            if (value.trim().length > 150) {
                              return 'Tên hoạt động tối đa 150 ký tự';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Destination Dropdown (Optional)
                        DropdownButtonFormField<int?>(
                          initialValue: _selectedDestinationId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Điểm đến / Địa điểm (tùy chọn)',
                            hintText: _loadingDestinations
                                ? 'Đang tải danh sách điểm đến...'
                                : 'Chọn địa điểm liên kết...',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceSoft,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.hairline,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.hairline,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text(
                                'Không liên kết địa điểm',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            ..._availableDestinations.map(
                              (dest) => DropdownMenuItem<int?>(
                                value: dest.destinationId,
                                child: Text(
                                  dest.name +
                                      (dest.address != null &&
                                              dest.address!.isNotEmpty
                                          ? ' (${dest.address})'
                                          : ''),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          onChanged: _isLoading
                              ? null
                              : (val) {
                                  setState(() {
                                    _selectedDestinationId = val;
                                  });
                                },
                        ),
                        const SizedBox(height: 14),

                        // Time Pickers Row
                        const Text(
                          'Thời gian thực hiện',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _isLoading ? null : _pickStartTime,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSoft,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.hairline,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _startTime != null
                                              ? _formatTimeOfDay(_startTime!)
                                              : 'Bắt đầu',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: _startTime != null
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: _startTime != null
                                                ? AppColors.textPrimary
                                                : AppColors.muted,
                                          ),
                                        ),
                                      ),
                                      if (_startTime != null && !_isLoading)
                                        GestureDetector(
                                          onTap: () => setState(() {
                                            _startTime = null;
                                            _validateTimeRange();
                                          }),
                                          child: const Icon(
                                            Icons.close,
                                            size: 16,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: _isLoading ? null : _pickEndTime,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSoft,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.hairline,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time_filled,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _endTime != null
                                              ? _formatTimeOfDay(_endTime!)
                                              : 'Kết thúc',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: _endTime != null
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: _endTime != null
                                                ? AppColors.textPrimary
                                                : AppColors.muted,
                                          ),
                                        ),
                                      ),
                                      if (_endTime != null && !_isLoading)
                                        GestureDetector(
                                          onTap: () => setState(() {
                                            _endTime = null;
                                            _validateTimeRange();
                                          }),
                                          child: const Icon(
                                            Icons.close,
                                            size: 16,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_timeErrorMessage != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _timeErrorMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Estimated Cost
                        TextFormField(
                          controller: _costController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Chi phí ước tính (VNĐ)',
                            hintText: '0 (để trống nếu miễn phí)',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceSoft,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.hairline,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.hairline,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return null;
                            }
                            final parsed = double.tryParse(value.trim());
                            if (parsed == null || parsed < 0) {
                              return 'Chi phí phải là số không âm';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Description
                        TextFormField(
                          controller: _descriptionController,
                          enabled: !_isLoading,
                          maxLines: 3,
                          minLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Mô tả / Ghi chú (tùy chọn)',
                            hintText:
                                'Địa chỉ, lưu ý trang phục, món ăn ngon...',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceSoft,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.hairline,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.hairline,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Action buttons
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.hairlineSoft),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppColors.hairline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEditing ? 'Lưu thay đổi' : 'Thêm hoạt động',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
