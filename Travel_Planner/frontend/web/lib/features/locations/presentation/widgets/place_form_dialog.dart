import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:travel_planner_web/core/constants/map_constants.dart';
import 'package:travel_planner_web/core/network/api_exception.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/locations/data/models/place_model.dart';
import 'package:travel_planner_web/shared/widgets/admin_dialog.dart';
import 'package:travel_planner_web/shared/widgets/admin_status_badge.dart';
import 'package:travel_planner_web/shared/widgets/app_primary_button.dart';
import 'package:travel_planner_web/shared/widgets/app_text_field.dart';
import 'package:travel_planner_web/shared/widgets/web_map_view.dart';

/// Modal dialog for creating or editing a canonical Place.
/// Aligned with docs/plan/admin-design-system.md (Minimalism & Swiss Style).
class PlaceFormDialog extends StatefulWidget {
  final PlaceModel? initialPlace;
  final Future<void> Function({
    required String name,
    required String address,
    required String category,
    String? description,
    String? imageUrl,
    required double latitude,
    required double longitude,
    String? status,
  }) onSubmit;

  const PlaceFormDialog({
    super.key,
    this.initialPlace,
    required this.onSubmit,
  });

  static Future<bool?> show(
    BuildContext context, {
    PlaceModel? place,
    required Future<void> Function({
      required String name,
      required String address,
      required String category,
      String? description,
      String? imageUrl,
      required double latitude,
      required double longitude,
      String? status,
    }) onSubmit,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PlaceFormDialog(
        initialPlace: place,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<PlaceFormDialog> createState() => _PlaceFormDialogState();
}

class _PlaceFormDialogState extends State<PlaceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _latController;
  late final TextEditingController _lonController;
  late final MapController _mapController;

  late String _category;
  late String _status;
  LatLng? _selectedPoint;
  bool _isSubmitting = false;
  String? _generalError;
  Map<String, String>? _fieldErrors;

  bool get isEditing => widget.initialPlace != null;

  static const List<Map<String, String>> _categories = [
    {'value': 'ATTRACTION', 'label': 'Điểm tham quan'},
    {'value': 'RESTAURANT', 'label': 'Nhà hàng'},
    {'value': 'CAFE', 'label': 'Quán cà phê'},
    {'value': 'HOTEL', 'label': 'Khách sạn / Lưu trú'},
    {'value': 'ENTERTAINMENT', 'label': 'Giải trí'},
    {'value': 'SHOPPING', 'label': 'Mua sắm'},
    {'value': 'OTHER', 'label': 'Khác'},
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.initialPlace;
    _nameController = TextEditingController(text: p?.name ?? '');
    _addressController = TextEditingController(text: p?.address ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _imageUrlController = TextEditingController(text: p?.imageUrl ?? '');
    _latController = TextEditingController(
      text: p?.latitude != null ? p!.latitude.toString() : '',
    );
    _lonController = TextEditingController(
      text: p?.longitude != null ? p!.longitude.toString() : '',
    );
    _mapController = MapController();

    _category = p?.category ?? 'ATTRACTION';
    _status = p?.status ?? 'ACTIVE';
    if (p?.hasCoordinates ?? false) {
      _selectedPoint = LatLng(p!.latitude!, p.longitude!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapTapped(LatLng point) {
    setState(() {
      _selectedPoint = point;
      _latController.text = point.latitude.toStringAsFixed(7);
      _lonController.text = point.longitude.toStringAsFixed(7);
      _fieldErrors?.remove('latitude');
      _fieldErrors?.remove('longitude');
    });
  }

  void _onCoordinateFieldsChanged() {
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());
    if (lat != null && lon != null && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
      final newPoint = LatLng(lat, lon);
      setState(() {
        _selectedPoint = newPoint;
      });
      try {
        _mapController.move(newPoint, _mapController.camera.zoom);
      } catch (_) {}
    }
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _generalError = null;
      _fieldErrors = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());

    if (lat == null || lon == null) {
      setState(() {
        _generalError = 'Vui lòng cung cấp tọa độ vĩ độ và kinh độ hợp lệ.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onSubmit(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        category: _category,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        latitude: lat,
        longitude: lon,
        status: _status,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _generalError = e.message;
          _fieldErrors = e.validationErrors;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _generalError = 'Đã xảy ra lỗi không xác định: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminDialog(
      width: 860,
      title: isEditing
          ? 'Chỉnh sửa địa điểm #${widget.initialPlace!.id}'
          : 'Thêm địa điểm chuẩn hóa mới',
      titleBadge: isEditing ? AdminStatusBadge(status: _status) : null,
      onClose: _isSubmitting ? null : () => Navigator.of(context).pop(false),
      content: SizedBox(
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // General error banner
            if (_generalError != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.errorBorder, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _generalError!,
                        style: const TextStyle(color: AppColors.error, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Body: 2 columns
            Expanded(
              child: Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Form Inputs
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(right: AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Place Name
                            AppTextField(
                              label: 'Tên địa điểm *',
                              hint: 'Ví dụ: Hồ Hoàn Kiếm, Cà phê Giảng...',
                              controller: _nameController,
                              errorText: _fieldErrors?['name'],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Tên địa điểm không được để trống';
                                }
                                if (v.trim().length > 150) {
                                  return 'Tên tối đa 150 ký tự';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // Category & Status
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Danh mục *',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      DropdownButtonFormField<String>(
                                        initialValue: _category,
                                        style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppRadius.sm),
                                            borderSide: const BorderSide(color: AppColors.border),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppRadius.sm),
                                            borderSide: const BorderSide(color: AppColors.border),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        ),
                                        items: _categories.map((c) {
                                          return DropdownMenuItem<String>(
                                            value: c['value'],
                                            child: Text(c['label']!),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => _category = val);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                if (isEditing) ...[
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Trạng thái',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        DropdownButtonFormField<String>(
                                          initialValue: _status,
                                          style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                                          decoration: InputDecoration(
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(AppRadius.sm),
                                              borderSide: const BorderSide(color: AppColors.border),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(AppRadius.sm),
                                              borderSide: const BorderSide(color: AppColors.border),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                          items: const [
                                            DropdownMenuItem(value: 'ACTIVE', child: Text('Đang hoạt động')),
                                            DropdownMenuItem(value: 'HIDDEN', child: Text('Đã ẩn')),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) setState(() => _status = val);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // Address
                            AppTextField(
                              label: 'Địa chỉ *',
                              hint: 'Số nhà, tên đường, phường/xã, quận/huyện, tỉnh/thành...',
                              controller: _addressController,
                              errorText: _fieldErrors?['address'],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Địa chỉ không được để trống';
                                }
                                if (v.trim().length > 255) {
                                  return 'Địa chỉ tối đa 255 ký tự';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // Coordinates
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    label: 'Vĩ độ (Latitude) *',
                                    hint: '21.0285',
                                    controller: _latController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                    errorText: _fieldErrors?['latitude'],
                                    onChanged: (_) => _onCoordinateFieldsChanged(),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Bắt buộc';
                                      }
                                      final val = double.tryParse(v.trim());
                                      if (val == null || val < -90.0 || val > 90.0) {
                                        return 'Trong khoảng -90 đến 90';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: AppTextField(
                                    label: 'Kinh độ (Longitude) *',
                                    hint: '105.8542',
                                    controller: _lonController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                    errorText: _fieldErrors?['longitude'],
                                    onChanged: (_) => _onCoordinateFieldsChanged(),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Bắt buộc';
                                      }
                                      final val = double.tryParse(v.trim());
                                      if (val == null || val < -180.0 || val > 180.0) {
                                        return 'Trong khoảng -180 đến 180';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // Description
                            AppTextField(
                              label: 'Mô tả',
                              hint: 'Giới thiệu về địa điểm, nét đặc sắc, lưu ý khi ghé thăm...',
                              controller: _descriptionController,
                              maxLines: 2,
                              errorText: _fieldErrors?['description'],
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // Image URL
                            AppTextField(
                              label: 'Đường dẫn ảnh (Image URL)',
                              hint: 'https://images.unsplash.com/...',
                              controller: _imageUrlController,
                              errorText: _fieldErrors?['imageUrl'],
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Right: Map & Image Preview
                    Expanded(
                      flex: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: AppColors.border)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.touch_app_outlined, size: 14, color: AppColors.primary),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Bấm lên bản đồ để chọn tọa độ',
                                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.sm - 1)),
                                child: WebMapView(
                                  mapController: _mapController,
                                  initialCenter: _selectedPoint ?? MapConstants.fallbackCoordinates,
                                  initialZoom: _selectedPoint != null ? 14 : MapConstants.fallbackZoom,
                                  onTap: (_, point) => _onMapTapped(point),
                                  markers: _selectedPoint != null
                                      ? [
                                          Marker(
                                            point: _selectedPoint!,
                                            width: 36,
                                            height: 36,
                                            child: const Icon(
                                              Icons.location_on,
                                              color: AppColors.primary,
                                              size: 32,
                                            ),
                                          ),
                                        ]
                                      : const [],
                                ),
                              ),
                            ),

                            // Image Preview if available
                            if (_imageUrlController.text.trim().isNotEmpty) ...[
                              Container(
                                height: 90,
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  border: Border(top: BorderSide(color: AppColors.border)),
                                ),
                                child: Image.network(
                                  _imageUrlController.text.trim(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Center(
                                    child: Text(
                                      'Không thể tải ảnh từ URL',
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
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
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.borderStrong),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy', style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
        ),
        AppPrimaryButton(
          text: isEditing ? 'Lưu thay đổi' : 'Thêm địa điểm',
          isLoading: _isSubmitting,
          onPressed: _handleSubmit,
        ),
      ],
    );
  }
}
