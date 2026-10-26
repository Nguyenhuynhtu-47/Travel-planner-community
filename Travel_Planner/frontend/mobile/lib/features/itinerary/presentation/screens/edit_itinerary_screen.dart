import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../explore/data/models/itinerary_summary.dart';
import '../../data/itinerary_crud_repository.dart';
import '../../data/models/itinerary_detail.dart';
import '../../data/models/update_itinerary_request.dart';

class EditItineraryScreen extends StatefulWidget {
  final int itineraryId;
  final String initialTitle;
  final String initialLocation;
  final double initialBudget;
  final String? initialDescription;
  final String? initialCoverImage;
  final String? initialTheme;
  final String initialVisibility;
  final int? totalDays;

  final AuthNotifier authNotifier;
  final ItineraryCrudRepository? repository;

  const EditItineraryScreen({
    super.key,
    required this.itineraryId,
    required this.initialTitle,
    required this.initialLocation,
    required this.initialBudget,
    this.initialDescription,
    this.initialCoverImage,
    this.initialTheme,
    this.initialVisibility = 'PRIVATE',
    this.totalDays,
    required this.authNotifier,
    this.repository,
  });

  factory EditItineraryScreen.fromDetail(
    ItineraryDetail detail, {
    Key? key,
    required AuthNotifier authNotifier,
    ItineraryCrudRepository? repository,
  }) {
    return EditItineraryScreen(
      key: key,
      itineraryId: detail.itineraryId,
      initialTitle: detail.title,
      initialLocation: detail.location,
      initialBudget: detail.budget,
      initialDescription: detail.description,
      initialCoverImage: detail.coverImage,
      initialTheme: detail.theme,
      initialVisibility: detail.visibility,
      totalDays: detail.totalDays,
      authNotifier: authNotifier,
      repository: repository,
    );
  }

  factory EditItineraryScreen.fromSummary(
    ItinerarySummary summary, {
    Key? key,
    required AuthNotifier authNotifier,
    ItineraryCrudRepository? repository,
  }) {
    return EditItineraryScreen(
      key: key,
      itineraryId: summary.itineraryId,
      initialTitle: summary.title,
      initialLocation: summary.location,
      initialBudget: summary.budget,
      initialDescription: summary.description,
      initialCoverImage: summary.coverImage,
      initialTheme: summary.theme,
      initialVisibility: summary.visibility ?? 'PRIVATE',
      totalDays: summary.totalDays,
      authNotifier: authNotifier,
      repository: repository,
    );
  }

  @override
  State<EditItineraryScreen> createState() => _EditItineraryScreenState();
}

class _EditItineraryScreenState extends State<EditItineraryScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _budgetController;
  late final TextEditingController _themeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _coverImageController;

  late String _visibility;
  bool _isSubmitting = false;

  late final ItineraryCrudRepository _repository;

  final List<String> _suggestedThemes = [
    'Nghỉ dưỡng',
    'Phượt',
    'Ẩm thực',
    'Khám phá',
    'Văn hóa',
    'Gia đình',
  ];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ItineraryCrudRepository();

    _titleController = TextEditingController(text: widget.initialTitle);
    _locationController = TextEditingController(text: widget.initialLocation);
    _budgetController = TextEditingController(
      text: widget.initialBudget > 0
          ? widget.initialBudget.toInt().toString()
          : '0',
    );
    _themeController = TextEditingController(text: widget.initialTheme ?? '');
    _descriptionController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
    _coverImageController = TextEditingController(
      text: widget.initialCoverImage ?? '',
    );
    _visibility = widget.initialVisibility.toUpperCase() == 'PUBLIC'
        ? 'PUBLIC'
        : 'PRIVATE';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    _themeController.dispose();
    _descriptionController.dispose();
    _coverImageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final budget = double.tryParse(_budgetController.text.trim()) ?? 0.0;

    final request = UpdateItineraryRequest(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      coverImage: _coverImageController.text.trim().isEmpty
          ? null
          : _coverImageController.text.trim(),
      budget: budget,
      theme: _themeController.text.trim().isEmpty
          ? null
          : _themeController.text.trim(),
      visibility: _visibility,
    );

    try {
      final updated = await _repository.updateItinerary(
        widget.itineraryId,
        request,
        token: widget.authNotifier.token,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật lịch trình thành công!'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.of(context).pop(updated);
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
          content: Text('Không thể cập nhật lịch trình. Vui lòng thử lại.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Chỉnh sửa lịch trình',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice about totalDays
              if (widget.totalDays != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
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
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Thời gian: ${widget.totalDays} ngày. Lịch trình theo ngày và các hoạt động được quản lý riêng.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Title
              AppTextField(
                label: 'Tiêu đề lịch trình *',
                hint: 'Ví dụ: Khám phá Đà Lạt 3 ngày 2 đêm',
                controller: _titleController,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Tiêu đề không được để trống';
                  }
                  if (value.trim().length < 3 || value.trim().length > 150) {
                    return 'Tiêu đề phải từ 3 đến 150 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Destination / Location
              AppTextField(
                label: 'Điểm đến / Địa điểm *',
                hint: 'Ví dụ: Đà Lạt, Lâm Đồng',
                controller: _locationController,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Điểm đến không được để trống';
                  }
                  if (value.trim().length > 150) {
                    return 'Điểm đến tối đa 150 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Budget
              AppTextField(
                label: 'Ngân sách (VNĐ) *',
                hint: '3000000',
                controller: _budgetController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập ngân sách';
                  }
                  final b = double.tryParse(value.trim());
                  if (b == null) {
                    return 'Số tiền không hợp lệ';
                  }
                  if (b < 0) {
                    return 'Không được âm';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Theme / Category
              AppTextField(
                label: 'Chủ đề / Thể loại',
                hint: 'Ví dụ: Nghỉ dưỡng, Phượt...',
                controller: _themeController,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value != null && value.trim().length > 100) {
                    return 'Chủ đề tối đa 100 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Quick theme chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _suggestedThemes.map((t) {
                  final isSelected = _themeController.text.trim() == t;
                  return ChoiceChip(
                    label: Text(
                      t,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceSoft,
                    showCheckmark: false,
                    onSelected: (selected) {
                      setState(() {
                        _themeController.text = selected ? t : '';
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Description
              AppTextField(
                label: 'Mô tả chuyến đi',
                hint: 'Giới thiệu ngắn về mục tiêu, trải nghiệm trong chuyến đi...',
                controller: _descriptionController,
                maxLines: 4,
                minLines: 2,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 16),

              // Cover Image URL
              AppTextField(
                label: 'Ảnh bìa (URL)',
                hint: 'https://example.com/cover.jpg',
                controller: _coverImageController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value != null && value.trim().length > 500) {
                    return 'Đường dẫn ảnh tối đa 500 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Visibility Selection
              const Text(
                'Quyền riêng tư',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  // Private option
                  Expanded(
                    child: _buildVisibilityOption(
                      title: 'Riêng tư',
                      subtitle: 'Chỉ bạn xem được',
                      icon: Icons.lock_outline,
                      value: 'PRIVATE',
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Public option
                  Expanded(
                    child: _buildVisibilityOption(
                      title: 'Công khai',
                      subtitle: 'Mọi người đều xem được',
                      icon: Icons.public,
                      value: 'PUBLIC',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Submit Button
              AppPrimaryButton(
                text: 'Lưu thay đổi',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _visibility == value;

    return InkWell(
      onTap: () => setState(() => _visibility = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withAlpha(20)
              : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.hairline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
