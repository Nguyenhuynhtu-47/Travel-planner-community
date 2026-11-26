import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/sync/app_sync_bus.dart';
import '../../../../shared/services/image_picker_service.dart';
import '../../../../shared/widgets/app_header_button.dart';
import '../../../../shared/widgets/app_page_title.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../explore/data/models/itinerary_summary.dart';
import '../../data/itinerary_crud_repository.dart';
import '../../data/models/itinerary_detail.dart';
import '../../data/models/update_itinerary_request.dart';
import '../widgets/itinerary_location_search_field.dart';

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
  final ImagePickerService? imagePickerService;

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
    this.imagePickerService,
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
  late final ImagePickerService _imagePickerService;

  final _titleFocus = FocusNode();
  final _budgetFocus = FocusNode();
  final _descFocus = FocusNode();

  XFile? _selectedCoverImage;
  Uint8List? _selectedCoverBytes;
  String? _coverImageUrl;

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
    _coverImageUrl = widget.initialCoverImage;
    _imagePickerService =
        widget.imagePickerService ?? DeviceImagePickerService();
    _visibility = widget.initialVisibility.toUpperCase() == 'PUBLIC'
        ? 'PUBLIC'
        : 'PRIVATE';

    _titleFocus.addListener(_onFocusChange);
    _budgetFocus.addListener(_onFocusChange);
    _descFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleFocus.removeListener(_onFocusChange);
    _budgetFocus.removeListener(_onFocusChange);
    _descFocus.removeListener(_onFocusChange);
    _titleFocus.dispose();
    _budgetFocus.dispose();
    _descFocus.dispose();
    _titleController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    _themeController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final budget = double.tryParse(_budgetController.text.trim()) ?? 0.0;

    try {
      String? coverImage = _coverImageUrl;
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
      final request = UpdateItineraryRequest(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        coverImage: coverImage,
        budget: budget,
        theme: _themeController.text.trim().isEmpty
            ? null
            : _themeController.text.trim(),
        visibility: _visibility,
      );
      final updated = await _repository.updateItinerary(
        widget.itineraryId,
        request,
        token: widget.authNotifier.token,
      );
      AppSyncBus.emitItineraryUpdated(updated, widget.itineraryId);

      if (!mounted) return;

      AppToast.showSuccess(context, 'Cập nhật lịch trình thành công!');

      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppToast.showError(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppToast.showError(
        context,
        'Không thể cập nhật lịch trình. Vui lòng thử lại.',
      );
    }
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E1E1E),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required bool isFocused,
    IconData? prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14.5, color: Color(0xFF8E8E93)),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: const Color(0xFF6E6E73))
          : null,
      suffix: suffix,
      filled: true,
      fillColor: isFocused ? Colors.white : const Color(0xFFF7F8FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEBEBEF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEBEBEF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFA3E62), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCoverBytes = _selectedCoverBytes != null;
    final hasCoverUrl =
        _coverImageUrl != null && _coverImageUrl!.trim().isNotEmpty;
    final hasCover = hasCoverBytes || hasCoverUrl;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          leadingWidth: 58,
          leading: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Center(child: AppHeaderBackButton()),
          ),
          title: const AppPageTitle(
            title: 'Chỉnh sửa lịch trình',
            fontSize: 18,
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E1E1E),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 0.5, color: const Color(0xFFF0F0F5)),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFF0F0F5), width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: BounceTap(
                enabled: !_isSubmitting,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFA3E62).withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFA3E62),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.2,
                            ),
                          )
                        : const Text(
                            'Lưu thay đổi',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                if (widget.totalDays != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFAD2DA)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFA3E62),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'i',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Thời gian: ${widget.totalDays} ngày. Lịch trình theo ngày và các hoạt động được quản lý riêng.',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF4B5563),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Title
                _buildFieldLabel('Tiêu đề lịch trình *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  focusNode: _titleFocus,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E1E1E),
                  ),
                  decoration: _buildInputDecoration(
                    hint: 'Ví dụ: Khám phá Đà Lạt 3 ngày 2 đêm',
                    isFocused: _titleFocus.hasFocus,
                    prefixIcon: Icons.title_rounded,
                  ),
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
                const SizedBox(height: 16),

                // Budget
                _buildFieldLabel('Ngân sách (VNĐ) *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _budgetController,
                  focusNode: _budgetFocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E1E1E),
                  ),
                  decoration: _buildInputDecoration(
                    hint: '3000000',
                    isFocused: _budgetFocus.hasFocus,
                    prefixIcon: Icons.payments_outlined,
                    suffix: const Text(
                      'VNĐ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6E6E73),
                      ),
                    ),
                  ),
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

                // Theme / Category (Chips only, no redundant TextField)
                _buildFieldLabel('Chủ đề / Thể loại'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestedThemes.map((t) {
                    final isSelected = _themeController.text.trim() == t;
                    return BounceTap(
                      useSelectionHaptic: true,
                      child: Material(
                        color: isSelected
                            ? const Color(0xFFFA3E62)
                            : const Color(0xFFF4F5F7),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _themeController.text = isSelected ? '' : t;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Description
                _buildFieldLabel('Mô tả chuyến đi'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  focusNode: _descFocus,
                  maxLines: 4,
                  minLines: 2,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF1E1E1E),
                    height: 1.4,
                  ),
                  decoration: _buildInputDecoration(
                    hint:
                        'Giới thiệu ngắn về mục tiêu, trải nghiệm trong chuyến đi...',
                    isFocused: _descFocus.hasFocus,
                    prefixIcon: Icons.notes_rounded,
                  ),
                ),
                const SizedBox(height: 18),

                // Interactive Cover Image Card
                _buildFieldLabel('Ảnh bìa lịch trình'),
                const SizedBox(height: 8),
                BounceTap(
                  child: GestureDetector(
                    onTap: _pickCoverImage,
                    child: Container(
                      height: 170,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEBEBEF)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (hasCoverBytes)
                            Image.memory(
                              _selectedCoverBytes!,
                              fit: BoxFit.cover,
                            )
                          else if (hasCoverUrl)
                            Image.network(
                              _coverImageUrl!.trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _buildCoverPlaceholder(),
                            )
                          else
                            _buildCoverPlaceholder(),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 8,
                                  sigmaY: 8,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.camera_alt_outlined,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        hasCover
                                            ? 'Đổi ảnh bìa'
                                            : 'Chọn ảnh bìa',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Visibility Selection
                _buildFieldLabel('Quyền riêng tư'),
                const SizedBox(height: 8),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildVisibilityOption(
                          title: 'Riêng tư',
                          subtitle: 'Chỉ bạn xem được',
                          icon: Icons.lock_outline_rounded,
                          value: 'PRIVATE',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildVisibilityOption(
                          title: 'Công khai',
                          subtitle: 'Mọi người đều xem được',
                          icon: Icons.public_rounded,
                          value: 'PUBLIC',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 36,
          color: Color(0xFF9CA3AF),
        ),
        SizedBox(height: 6),
        Text(
          'Chưa có ảnh bìa',
          style: TextStyle(fontSize: 13, color: Color(0xFF6E6E73)),
        ),
      ],
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
      child: Material(
        color: isSelected ? const Color(0xFFFFF0F3) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => setState(() => _visibility = value),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFA3E62)
                    : const Color(0xFFEBEBEF),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFFE0E6)
                            : const Color(0xFFEFEFF4),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        icon,
                        size: 18,
                        color: isSelected
                            ? const Color(0xFFFA3E62)
                            : const Color(0xFF6E6E73),
                      ),
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
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? const Color(0xFFFA3E62)
                                  : const Color(0xFF1E1E1E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF6E6E73),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isSelected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFA3E62),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
