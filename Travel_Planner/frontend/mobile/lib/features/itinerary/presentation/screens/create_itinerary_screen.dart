import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/sync/app_sync_bus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_header_button.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_page_title.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/services/image_picker_service.dart';
import '../../../../shared/widgets/image_upload_preview.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/itinerary_crud_repository.dart';
import '../../data/models/create_itinerary_request.dart';
import '../widgets/itinerary_location_search_field.dart';
import 'itinerary_detail_screen.dart';

class CreateItineraryScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final ItineraryCrudRepository? repository;
  final void Function(int createdItineraryId)? onCreated;
  final ImagePickerService? imagePickerService;
  final bool initialShowIntro;

  const CreateItineraryScreen({
    super.key,
    required this.authNotifier,
    this.repository,
    this.onCreated,
    this.imagePickerService,
    this.initialShowIntro = true,
  });

  @override
  State<CreateItineraryScreen> createState() => _CreateItineraryScreenState();
}

class _CreateItineraryScreenState extends State<CreateItineraryScreen> {
  int _currentStep = 0;
  bool _showIntro = true;

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _totalDaysController = TextEditingController(text: '3');
  final _budgetController = TextEditingController(text: '3000000');
  final _themeController = TextEditingController();
  final _descriptionController = TextEditingController();
  XFile? _selectedCoverImage;
  Uint8List? _selectedCoverBytes;

  String _visibility = 'PRIVATE'; // Default PRIVATE
  bool _isSubmitting = false;

  late final ItineraryCrudRepository _repository;
  late final ImagePickerService _imagePickerService;

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
    _showIntro = widget.initialShowIntro;
    _repository = widget.repository ?? ItineraryCrudRepository();
    _imagePickerService =
        widget.imagePickerService ?? DeviceImagePickerService();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _totalDaysController.dispose();
    _budgetController.dispose();
    _themeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _titleController.clear();
    _locationController.clear();
    _totalDaysController.text = '3';
    _budgetController.text = '3000000';
    _themeController.clear();
    _descriptionController.clear();
    _selectedCoverImage = null;
    _selectedCoverBytes = null;
    setState(() {
      _showIntro = true;
      _currentStep = 0;
      _visibility = 'PRIVATE';
      _isSubmitting = false;
    });
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_step1Key.currentState?.validate() == true) {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      if (_step2Key.currentState?.validate() == true) {
        setState(() => _currentStep = 2);
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      setState(() => _showIntro = true);
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final image = await _imagePickerService.pickImage();
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          AppToast.showWarning(context, 'Ảnh không được vượt quá 5 MB');
        }
        return;
      }
      if (mounted) {
        setState(() {
          _selectedCoverImage = image;
          _selectedCoverBytes = bytes;
        });
      }
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          context,
          'Không thể mở thư viện ảnh. Vui lòng thử lại.',
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    // Validate current step (Step 3)
    if (_step3Key.currentState?.validate() != true) {
      return;
    }

    // Verify step 1 and step 2
    if (_titleController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty) {
      setState(() => _currentStep = 0);
      _step1Key.currentState?.validate();
      return;
    }

    final totalDays = int.tryParse(_totalDaysController.text.trim());
    final budget = double.tryParse(_budgetController.text.trim());
    if (totalDays == null || totalDays < 1 || totalDays > 30 ||
        budget == null || budget < 0) {
      setState(() => _currentStep = 1);
      _step2Key.currentState?.validate();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? coverImage;
      final selectedImage = _selectedCoverImage;
      final selectedBytes = _selectedCoverBytes;
      final token = widget.authNotifier.token;
      if (selectedImage != null && selectedBytes != null) {
        if (token == null) {
          throw ApiException(
            statusCode: 401,
            message: 'Vui lòng đăng nhập để tải ảnh lên.',
          );
        }
        coverImage = await _repository.uploadImage(
          token,
          bytes: selectedBytes,
          filename: selectedImage.name,
        );
      }
      final request = CreateItineraryRequest(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        coverImage: coverImage,
        totalDays: totalDays,
        budget: budget,
        theme: _themeController.text.trim().isEmpty
            ? null
            : _themeController.text.trim(),
        visibility: _visibility,
      );
      final created = await _repository.createItinerary(
        request,
        token: widget.authNotifier.token,
      );
      AppSyncBus.emitItineraryCreated(created, created.itineraryId);

      if (!mounted) return;

      AppToast.showSuccess(context, 'Tạo lịch trình thành công!');

      // Navigate to detail screen so user can review the new itinerary
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
      AppToast.showError(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppToast.showError(context, 'Không thể tạo lịch trình. Vui lòng thử lại.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPopScope = _showIntro && Navigator.of(context).canPop();

    return PopScope(
      canPop: canPopScope,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!_showIntro) {
          _previousStep();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const AppPageTitle(title: 'Tạo lịch trình mới'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 58,
          leading: _showIntro
              ? (Navigator.of(context).canPop()
                  ? const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Center(child: AppHeaderBackButton()),
                    )
                  : null)
              : Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Center(
                    child: AppHeaderIconButton(
                      icon: Icons.arrow_back,
                      tooltip:
                          _currentStep > 0 ? 'Quay lại bước trước' : 'Quay lại',
                      onPressed: _previousStep,
                    ),
                  ),
                ),
          actions: [
            if (!_showIntro) ...[
              AppHeaderIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Làm mới biểu mẫu',
                onPressed: _resetForm,
              ),
              const SizedBox(width: 8),
            ],
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 0.5,
              color: AppColors.hairlineSoft,
            ),
          ),
        ),
        body: _showIntro
            ? _buildIntroScreen()
            : Column(
                children: [
                  _buildProgressIndicator(),
                  Expanded(
                    child: IndexedStack(
                      index: _currentStep,
                      children: [
                        _buildStep1(),
                        _buildStep2(),
                        _buildStep3(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildIntroScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Travel Visual Container
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withAlpha(22),
                  border: Border.all(
                    color: AppColors.primary.withAlpha(50),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.explore_rounded,
                    size: 44,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Main Heading
              const Text(
                'Bắt đầu hành trình của bạn',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Supporting Text
              const Text(
                'Lên kế hoạch cho chuyến đi tiếp theo của bạn một cách dễ dàng.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 22),

              // 3-Step Overview Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.hairlineSoft),
                ),
                child: Column(
                  children: [
                    _introStepItem(
                      stepNum: '1',
                      title: 'Thông tin chuyến đi',
                      subtitle: 'Đặt tên lịch trình và chọn địa điểm khám phá',
                      icon: Icons.place_outlined,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Divider(height: 1, color: AppColors.hairlineSoft),
                    ),
                    _introStepItem(
                      stepNum: '2',
                      title: 'Thời gian & ngân sách',
                      subtitle: 'Ước tính số ngày du lịch và chi phí dự kiến',
                      icon: Icons.calendar_today_outlined,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Divider(height: 1, color: AppColors.hairlineSoft),
                    ),
                    _introStepItem(
                      stepNum: '3',
                      title: 'Phong cách & hoàn tất',
                      subtitle: 'Chọn thể loại, ảnh bìa và tạo lịch trình',
                      icon: Icons.tune_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // CTA Button: Bắt đầu
              AppPrimaryButton(
                text: 'Bắt đầu',
                onPressed: () {
                  setState(() => _showIntro = false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _introStepItem({
    required String stepNum,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    const stepTitles = [
      'Thông tin chuyến đi',
      'Thời gian & ngân sách',
      'Phong cách chuyến đi',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.hairlineSoft, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bước ${_currentStep + 1}/3',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stepTitles[_currentStep],
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 3,
              backgroundColor: AppColors.surfaceSoft,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  // Step 1: Tiêu đề & Điểm đến
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin chuyến đi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Đặt tên cho lịch trình và chọn địa điểm bạn muốn ghé thăm.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

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
            const SizedBox(height: 18),

            // Destination / Location
            ItineraryLocationSearchField(
              controller: _locationController,
              token: widget.authNotifier.token,
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
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: BounceTap(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Quay lại',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppPrimaryButton(
                    text: 'Tiếp theo',
                    onPressed: _nextStep,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Step 2: Thời gian & Ngân sách
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Form(
        key: _step2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thời gian và ngân sách',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ước tính số ngày du lịch và chi phí dự kiến cho toàn bộ chuyến đi.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

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
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: BounceTap(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Quay lại',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppPrimaryButton(
                    text: 'Tiếp theo',
                    onPressed: _nextStep,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Step 3: Phong cách, Mô tả, Ảnh bìa, Quyền riêng tư & Tạo
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Form(
        key: _step3Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phong cách chuyến đi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Chọn chủ đề, mô tả và thiết lập chế độ hiển thị cho lịch trình.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

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
                return BounceTap(
                  useSelectionHaptic: true,
                  child: ChoiceChip(
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
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Description
            AppTextField(
              label: 'Mô tả chuyến đi',
              hint: 'Giới thiệu ngắn về mục tiêu, trải nghiệm trong chuyến đi...',
              controller: _descriptionController,
              maxLines: 4,
              minLines: 2,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 18),

            ImageUploadPreview(
              selectedBytes: _selectedCoverBytes,
              imageUrl: null,
              buttonLabel: 'Chọn ảnh bìa',
              onPick: _pickCoverImage,
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
                  Expanded(
                    child: _buildVisibilityOption(
                      title: 'Riêng tư',
                      subtitle: 'Chỉ bạn xem được',
                      icon: Icons.lock_outline,
                      value: 'PRIVATE',
                    ),
                  ),
                  const SizedBox(width: 12),
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
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: BounceTap(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Quay lại',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppPrimaryButton(
                    text: 'Tạo lịch trình',
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
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

    return BounceTap(
      useSelectionHaptic: true,
      child: InkWell(
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
      ),
    );
  }
}
