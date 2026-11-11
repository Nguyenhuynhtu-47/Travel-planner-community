import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/services/image_picker_service.dart';
import '../../../../shared/widgets/image_upload_preview.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../location/data/location_repository.dart';
import '../../../location/presentation/widgets/location_picker_sheet.dart';
import '../../data/itinerary_crud_repository.dart';
import '../../data/models/activity_detail.dart';
import '../../data/models/create_activity_request.dart';
import '../../data/models/itinerary_place.dart';
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
  LocationRepository? locationRepository,
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
      locationRepository: locationRepository,
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
  LocationRepository? locationRepository,
}) => showActivityFormDialog(
  context,
  itineraryId: itineraryId,
  dayId: dayId,
  dayNumber: dayNumber,
  dayTitle: dayTitle,
  initialActivity: initialActivity,
  authNotifier: authNotifier,
  repository: repository,
  locationRepository: locationRepository,
);

class ActivityFormBottomSheet extends StatefulWidget {
  final int itineraryId;
  final int dayId;
  final int dayNumber;
  final String? dayTitle;
  final ActivityDetail? initialActivity;
  final AuthNotifier authNotifier;
  final ItineraryCrudRepository repository;
  final LocationRepository? locationRepository;

  const ActivityFormBottomSheet({
    super.key,
    required this.itineraryId,
    required this.dayId,
    required this.dayNumber,
    this.dayTitle,
    this.initialActivity,
    required this.authNotifier,
    required this.repository,
    this.locationRepository,
  });

  @override
  State<ActivityFormBottomSheet> createState() =>
      _ActivityFormBottomSheetState();
}

class _ActivityFormBottomSheetState extends State<ActivityFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final LocationRepository _locationRepository;
  late final ImagePickerService _imagePickerService;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _costController;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _savedActivityImageUrl;
  bool _imageChanged = false;

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isLoading = false;
  String? _timeErrorMessage;

  int? _destinationId;
  int? _canonicalPlaceId;
  String? _locationName;
  String? _locationAddress;
  double? _latitude;
  double? _longitude;
  String? _placeId;
  String? _locationProvider;
  String? _lastAutoFilledActivityName;
  bool _locationCleared = false;
  List<ItineraryPlace> _savedPlaces = [];

  bool get _isEditing => widget.initialActivity != null;

  String? get _selectedDestinationImageUrl =>
      widget.initialActivity?.effectiveImageUrl;

  @override
  void initState() {
    super.initState();
    _locationRepository =
        widget.locationRepository ??
        LocationRepository(apiClient: widget.repository.apiClient);
    _imagePickerService = DeviceImagePickerService();
    _savedActivityImageUrl = widget.initialActivity?.imageUrl;

    if (widget.initialActivity != null) {
      final act = widget.initialActivity!;
      _destinationId = act.destination?.destinationId;
      _canonicalPlaceId = act.canonicalPlaceId ?? act.place?.placeId;
      _locationName = act.effectiveLocationName;
      _locationAddress = act.effectiveAddress;
      _latitude = act.latitude;
      _longitude = act.longitude;
      _placeId = act.placeId;
      _locationProvider = act.locationProvider;
    }

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
    _loadSavedPlaces();
  }

  Future<void> _loadSavedPlaces() async {
    if (widget.itineraryId <= 0) return;
    try {
      final list = await widget.repository.getSavedPlaces(
        widget.itineraryId,
        token: widget.authNotifier.token,
      );
      if (mounted) {
        setState(() {
          _savedPlaces = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _openLocationPicker() async {
    LatLng? initialCenter;
    if (_latitude != null && _longitude != null) {
      initialCenter = LatLng(_latitude!, _longitude!);
    }

    final result = await showLocationPickerSheet(
      context,
      repository: _locationRepository,
      initialCenter: initialCenter,
      initialName: _locationName,
      initialAddress: _locationAddress,
      initialPlaceId: _placeId,
      initialProvider: _locationProvider,
      token: widget.authNotifier.token,
    );

    if (result != null && mounted) {
      setState(() {
        _destinationId = null;
        _canonicalPlaceId = null;
        _locationCleared = false;
        final currentName = _nameController.text.trim();
        final previousAutoName = _lastAutoFilledActivityName;
        if (result.locationProvider != 'MANUAL_PIN' &&
            (currentName.isEmpty || currentName == previousAutoName)) {
          _nameController.text = result.locationName;
          _lastAutoFilledActivityName = result.locationName;
        }
        _locationName = result.locationName;
        _locationAddress = result.address;
        _latitude = result.latitude;
        _longitude = result.longitude;
        _placeId = result.placeId;
        _locationProvider = result.locationProvider;
      });
    }
  }

  Future<void> _pickActivityImage() async {
    try {
      final file = await _imagePickerService.pickImage();
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImage = file;
        _selectedImageBytes = bytes;
        _imageChanged = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể đọc ảnh đã chọn.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _removeActivityImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
      _savedActivityImageUrl = null;
      _imageChanged = true;
    });
  }

  void _clearLocation() {
    setState(() {
      _locationName = null;
      _locationAddress = null;
      _latitude = null;
      _longitude = null;
      _placeId = null;
      _locationProvider = null;
      _destinationId = null;
      _canonicalPlaceId = null;
      _locationCleared = true;
    });
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
      String? imageUrl;
      if (_selectedImage != null && _selectedImageBytes != null) {
        imageUrl = await widget.repository.uploadImage(
          token,
          bytes: _selectedImageBytes!,
          filename: _selectedImage!.name,
        );
      } else if (_imageChanged) {
        imageUrl = '';
      }
      if (_isEditing) {
        final request = UpdateActivityRequest(
          name: name,
          description: description.isNotEmpty ? description : null,
          destinationId: _locationCleared ? null : _destinationId,
          canonicalPlaceId: _locationCleared ? null : _canonicalPlaceId,
          startTime: startTimeStr,
          endTime: endTimeStr,
          cost: rawCost,
          locationName: _locationCleared ? null : _locationName,
          locationAddress: _locationCleared ? null : _locationAddress,
          customLocationName: _locationCleared ? null : _locationName,
          customAddress: _locationCleared ? null : _locationAddress,
          latitude: _locationCleared ? null : _latitude,
          longitude: _locationCleared ? null : _longitude,
          placeId: _locationCleared ? null : _placeId,
          locationProvider: _locationCleared ? null : _locationProvider,
          imageUrl: imageUrl,
          clearLocation: _locationCleared,
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
          destinationId: _destinationId,
          canonicalPlaceId: _canonicalPlaceId,
          startTime: startTimeStr,
          endTime: endTimeStr,
          cost: rawCost,
          locationName: _locationName,
          locationAddress: _locationAddress,
          customLocationName: _locationName,
          customAddress: _locationAddress,
          latitude: _latitude,
          longitude: _longitude,
          placeId: _placeId,
          locationProvider: _locationProvider,
          imageUrl: imageUrl,
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
                        const Text(
                          'Vị trí hoạt động',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (_latitude != null && _longitude != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.pin_drop,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _locationName ?? 'Vị trí đã chọn',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (_locationAddress != null &&
                                          _locationAddress!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          _locationAddress!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tọa độ: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_location_alt_outlined,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                                  tooltip: 'Đổi vị trí trên bản đồ',
                                  onPressed: _isLoading
                                      ? null
                                      : _openLocationPicker,
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: AppColors.muted,
                                  ),
                                  tooltip: 'Xóa vị trí',
                                  onPressed: _isLoading
                                      ? null
                                      : _clearLocation,
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              icon: const Icon(
                                Icons.map_outlined,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              label: const Text(
                                'Chọn vị trí trên bản đồ',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(
                                    color: AppColors.hairline,
                                  ),
                                ),
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : _openLocationPicker,
                            ),
                          ),
                        ],
                        if (_savedPlaces.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: const [
                              Icon(
                                Icons.bookmark_outline,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Địa điểm đã lưu trong lịch trình:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _savedPlaces.map((sp) {
                              final isSelected =
                                  _canonicalPlaceId == sp.place.placeId;
                              return ActionChip(
                                avatar: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.place_outlined,
                                  size: 14,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.primary,
                                ),
                                label: Text(
                                  sp.place.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                backgroundColor: isSelected
                                    ? AppColors.primary
                                    : AppColors.surfaceSoft,
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _canonicalPlaceId = sp.place.placeId;
                                          _destinationId = null;
                                          _locationName = sp.place.name;
                                          _locationAddress = sp.place.address;
                                          _latitude = sp.place.latitude;
                                          _longitude = sp.place.longitude;
                                          _placeId =
                                              sp.place.placeId.toString();
                                          _locationProvider = 'SYSTEM';
                                          _locationCleared = false;
                                          if (_nameController.text
                                              .trim()
                                              .isEmpty) {
                                            _nameController.text =
                                                sp.place.name;
                                          }
                                        });
                                      },
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Activity-specific cover image, falling back to the
                        // selected catalog destination's cover for preview.
                        const Text(
                          'Ảnh đại diện hoạt động',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ImageUploadPreview(
                          selectedBytes: _selectedImageBytes,
                          imageUrl:
                              _savedActivityImageUrl ??
                              _selectedDestinationImageUrl,
                          onPick: _isLoading ? null : _pickActivityImage,
                          height: 112,
                          buttonLabel: _selectedImageBytes == null
                              ? 'Chọn ảnh đại diện'
                              : 'Đổi ảnh đại diện',
                        ),
                        if (_selectedImageBytes != null ||
                            (_savedActivityImageUrl?.trim().isNotEmpty ??
                                false))
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : _removeActivityImage,
                              icon: const Icon(Icons.delete_outline, size: 17),
                              label: const Text('Xóa ảnh hoạt động'),
                            ),
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
