import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/itinerary_crud_repository.dart';
import '../../data/models/activity_detail.dart';
import '../../data/models/create_activity_request.dart';
import '../../data/models/update_activity_request.dart';

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
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ActivityFormDialog(
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

class _ActivityFormDialog extends StatefulWidget {
  final int itineraryId;
  final int dayId;
  final int dayNumber;
  final String? dayTitle;
  final ActivityDetail? initialActivity;
  final AuthNotifier authNotifier;
  final ItineraryCrudRepository repository;

  const _ActivityFormDialog({
    required this.itineraryId,
    required this.dayId,
    required this.dayNumber,
    this.dayTitle,
    this.initialActivity,
    required this.authNotifier,
    required this.repository,
  });

  @override
  State<_ActivityFormDialog> createState() => _ActivityFormDialogState();
}

class _ActivityFormDialogState extends State<_ActivityFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _costController;

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isLoading = false;
  String? _timeErrorMessage;

  bool get _isEditing => widget.initialActivity != null;

  @override
  void initState() {
    super.initState();
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
      initialTime: _startTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        _validateTimeRange();
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _endTime ??
          (_startTime != null
              ? TimeOfDay(
                  hour: (_startTime!.hour + 1) % 24,
                  minute: _startTime!.minute,
                )
              : const TimeOfDay(hour: 9, minute: 30)),
    );
    if (picked != null) {
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
          destinationId: widget.initialActivity?.destination?.destinationId,
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
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
                  ],
                ),
                const SizedBox(height: 18),

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
                      borderSide: const BorderSide(color: AppColors.hairline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.hairline),
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
                            border: Border.all(color: AppColors.hairline),
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
                            border: Border.all(color: AppColors.hairline),
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
                      borderSide: const BorderSide(color: AppColors.hairline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.hairline),
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
                    if (value == null || value.trim().isEmpty) return null;
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
                    hintText: 'Địa chỉ, lưu ý trang phục, món ăn ngon...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceSoft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.hairline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.hairline),
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
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEditing ? 'Lưu thay đổi' : 'Thêm hoạt động',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
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
  }
}
