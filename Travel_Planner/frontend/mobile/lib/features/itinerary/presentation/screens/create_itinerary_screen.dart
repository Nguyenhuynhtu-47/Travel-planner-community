import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/itinerary_crud_repository.dart';
import '../../data/models/create_itinerary_request.dart';
import 'itinerary_detail_screen.dart';

class CreateItineraryScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final ItineraryCrudRepository? repository;
  final void Function(int createdItineraryId)? onCreated;

  const CreateItineraryScreen({
    super.key,
    required this.authNotifier,
    this.repository,
    this.onCreated,
  });

  @override
  State<CreateItineraryScreen> createState() => _CreateItineraryScreenState();
}

class _CreateItineraryScreenState extends State<CreateItineraryScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _totalDaysController = TextEditingController(text: '3');
  final _budgetController = TextEditingController(text: '3000000');
  final _themeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _coverImageController = TextEditingController();

  String _visibility = 'PRIVATE'; // Default PRIVATE
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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _totalDaysController.dispose();
    _budgetController.dispose();
    _themeController.dispose();
    _descriptionController.dispose();
    _coverImageController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _titleController.clear();
    _locationController.clear();
    _totalDaysController.text = '3';
    _budgetController.text = '3000000';
    _themeController.clear();
    _descriptionController.clear();
    _coverImageController.clear();
    setState(() {
      _visibility = 'PRIVATE';
      _isSubmitting = false;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final totalDays = int.tryParse(_totalDaysController.text.trim()) ?? 1;
    final budget = double.tryParse(_budgetController.text.trim()) ?? 0.0;

    final request = CreateItineraryRequest(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      coverImage: _coverImageController.text.trim().isEmpty
          ? null
          : _coverImageController.text.trim(),
      totalDays: totalDays,
      budget: budget,
      theme: _themeController.text.trim().isEmpty
          ? null
          : _themeController.text.trim(),
      visibility: _visibility,
    );

    try {
      final created = await _repository.createItinerary(
        request,
        token: widget.authNotifier.token,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tạo lịch trình thành công!'),
          backgroundColor: AppColors.success,
        ),
      );

      // Navigate to detail screen so user can review the new itinerary,
      // and when they return, pass true to refresh MyItineraries list.
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ItineraryDetailScreen(
            itineraryId: created.itineraryId,
            initialDetail: created,
            token: widget.authNotifier.token,
            authNotifier: widget.authNotifier,
            crudRepository: _repository,
          ),
        ),
      );

      if (mounted) {
        if (widget.onCreated != null) {
          final id = created.itineraryId;
          _resetForm();
          widget.onCreated!(id);
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      }
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
          content: Text('Không thể tạo lịch trình. Vui lòng thử lại.'),
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
          'Tạo lịch trình mới',
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

              // Row: Days & Budget
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total days
                  Expanded(
                    child: AppTextField(
                      label: 'Số ngày (1-30) *',
                      hint: '3',
                      controller: _totalDaysController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập số ngày';
                        }
                        final days = int.tryParse(value.trim());
                        if (days == null) {
                          return 'Phải là số nguyên';
                        }
                        if (days < 1 || days > 30) {
                          return 'Từ 1 đến 30 ngày';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Budget
                  Expanded(
                    child: AppTextField(
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
                  ),
                ],
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

              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
              ),
              const SizedBox(height: 28),

              // Submit Button
              AppPrimaryButton(
                text: 'Tạo lịch trình',
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
        height: double.infinity,
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
