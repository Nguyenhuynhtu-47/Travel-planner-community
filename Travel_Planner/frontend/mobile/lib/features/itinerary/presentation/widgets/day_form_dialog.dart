import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/itinerary_crud_repository.dart';
import '../../data/models/create_day_request.dart';
import '../../data/models/itinerary_day_detail.dart';
import '../../data/models/update_day_request.dart';

Future<bool?> showDayFormDialog(
  BuildContext context, {
  required int itineraryId,
  ItineraryDayDetail? initialDay,
  int nextDayNumber = 1,
  required AuthNotifier authNotifier,
  ItineraryCrudRepository? repository,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => DayFormDialog(
      itineraryId: itineraryId,
      initialDay: initialDay,
      nextDayNumber: nextDayNumber,
      authNotifier: authNotifier,
      repository: repository,
    ),
  );
}

class DayFormDialog extends StatefulWidget {
  final int itineraryId;
  final ItineraryDayDetail? initialDay;
  final int nextDayNumber;
  final AuthNotifier authNotifier;
  final ItineraryCrudRepository? repository;

  const DayFormDialog({
    super.key,
    required this.itineraryId,
    this.initialDay,
    this.nextDayNumber = 1,
    required this.authNotifier,
    this.repository,
  });

  bool get isEditing => initialDay != null;

  @override
  State<DayFormDialog> createState() => _DayFormDialogState();
}

class _DayFormDialogState extends State<DayFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  DateTime? _selectedDate;
  bool _isSubmitting = false;

  late final ItineraryCrudRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ItineraryCrudRepository();
    _titleController = TextEditingController(
      text: widget.initialDay?.title ?? '',
    );
    _selectedDate = widget.initialDay?.date;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: widget.isEditing
          ? 'Chọn ngày diễn ra'
          : 'Chọn ngày cho lịch trình',
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final titleText = _titleController.text.trim();
    final effectiveTitle = titleText.isEmpty ? null : titleText;

    try {
      if (widget.isEditing) {
        final request = UpdateDayRequest(
          title: effectiveTitle,
          date: _selectedDate,
        );
        await _repository.updateDay(
          widget.itineraryId,
          widget.initialDay!.dayId,
          request,
          token: widget.authNotifier.token,
        );
      } else {
        final request = CreateDayRequest(
          title: effectiveTitle,
          date: _selectedDate,
        );
        await _repository.addDay(
          widget.itineraryId,
          request,
          token: widget.authNotifier.token,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Cập nhật Ngày ${widget.initialDay!.dayNumber} thành công!'
                : 'Thêm Ngày ${widget.nextDayNumber} thành công!',
          ),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lưu thông tin ngày. Vui lòng thử lại.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayNum = widget.isEditing
        ? widget.initialDay!.dayNumber
        : widget.nextDayNumber;
    final dialogTitle = widget.isEditing
        ? 'Chỉnh sửa Ngày $dayNum'
        : 'Thêm Ngày $dayNum';

    return AlertDialog(
      title: Text(
        dialogTitle,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                label: 'Tiêu đề ngày (tùy chọn)',
                hint: 'Ví dụ: Khám phá phố cổ, Nghỉ ngơi...',
                controller: _titleController,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value != null && value.trim().length > 150) {
                    return 'Tiêu đề ngày tối đa 150 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date Picker Field
              const Text(
                'Ngày diễn ra (tùy chọn)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedDate != null
                              ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
                              : 'Chọn ngày thực hiện',
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedDate != null
                                ? AppColors.textPrimary
                                : AppColors.muted,
                            fontWeight: _selectedDate != null
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (_selectedDate != null)
                        InkWell(
                          onTap: () => setState(() => _selectedDate = null),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(widget.isEditing ? 'Lưu thay đổi' : 'Thêm ngày'),
        ),
      ],
    );
  }
}
