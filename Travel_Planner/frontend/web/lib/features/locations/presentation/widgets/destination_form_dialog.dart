import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:travel_planner_web/core/constants/map_constants.dart';
import 'package:travel_planner_web/core/network/api_exception.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/locations/data/models/destination_model.dart';
import 'package:travel_planner_web/shared/widgets/app_primary_button.dart';
import 'package:travel_planner_web/shared/widgets/app_text_field.dart';
import 'package:travel_planner_web/shared/widgets/web_map_view.dart';

/// Modal dialog for creating or editing a catalog destination.
class DestinationFormDialog extends StatefulWidget {
  final Destination? initialDestination;
  final Future<void> Function({
    required String name,
    required String address,
    String? description,
    String? imageUrl,
    double? latitude,
    double? longitude,
    String? status,
  }) onSubmit;

  const DestinationFormDialog({
    super.key,
    this.initialDestination,
    required this.onSubmit,
  });

  static Future<bool?> show(
    BuildContext context, {
    Destination? destination,
    required Future<void> Function({
      required String name,
      required String address,
      String? description,
      String? imageUrl,
      double? latitude,
      double? longitude,
      String? status,
    }) onSubmit,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DestinationFormDialog(
        initialDestination: destination,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<DestinationFormDialog> createState() => _DestinationFormDialogState();
}

class _DestinationFormDialogState extends State<DestinationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _latController;
  late final TextEditingController _lonController;
  late final MapController _mapController;

  late String _status;
  LatLng? _selectedPoint;
  bool _isSubmitting = false;
  String? _generalError;
  Map<String, String>? _fieldErrors;

  bool get isEditing => widget.initialDestination != null;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDestination;
    _nameController = TextEditingController(text: d?.name ?? '');
    _addressController = TextEditingController(text: d?.address ?? '');
    _descriptionController = TextEditingController(text: d?.description ?? '');
    _imageUrlController = TextEditingController(text: d?.imageUrl ?? '');
    _latController = TextEditingController(
      text: d?.latitude != null ? d!.latitude.toString() : '',
    );
    _lonController = TextEditingController(
      text: d?.longitude != null ? d!.longitude.toString() : '',
    );
    _mapController = MapController();

    _status = d?.status ?? 'ACTIVE';
    if (d?.hasCoordinates ?? false) {
      _selectedPoint = LatLng(d!.latitude!, d.longitude!);
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

  void _onMapTapped(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedPoint = point;
      _latController.text = point.latitude.toStringAsFixed(6);
      _lonController.text = point.longitude.toStringAsFixed(6);
      _fieldErrors?.remove('latitude');
      _fieldErrors?.remove('longitude');
    });
  }

  void _clearCoordinates() {
    setState(() {
      _selectedPoint = null;
      _latController.clear();
      _lonController.clear();
    });
  }

  void _onCoordinateInputsChanged() {
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());
    if (lat != null && lon != null && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
      final point = LatLng(lat, lon);
      setState(() {
        _selectedPoint = point;
      });
      _mapController.move(point, 14.0);
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    setState(() {
      _generalError = null;
      _fieldErrors = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final latText = _latController.text.trim();
    final lonText = _lonController.text.trim();

    double? lat;
    double? lon;

    // Coordinate pair validation
    if (latText.isNotEmpty || lonText.isNotEmpty) {
      if (latText.isEmpty || lonText.isEmpty) {
        setState(() {
          _generalError = 'Tọa độ phải bao gồm cả vĩ độ (latitude) và kinh độ (longitude).';
        });
        return;
      }

      lat = double.tryParse(latText);
      lon = double.tryParse(lonText);

      if (lat == null || lat < -90.0 || lat > 90.0) {
        setState(() {
          _fieldErrors = {'latitude': 'Vĩ độ phải nằm trong khoảng -90.0 đến 90.0'};
        });
        return;
      }

      if (lon == null || lon < -180.0 || lon > 180.0) {
        setState(() {
          _fieldErrors = {'longitude': 'Kinh độ phải nằm trong khoảng -180.0 đến 180.0'};
        });
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.onSubmit(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        imageUrl: _imageUrlController.text.trim().isNotEmpty
            ? _imageUrlController.text.trim()
            : null,
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
          _generalError = 'Đã có lỗi xảy ra: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = isEditing ? 'Chỉnh sửa điểm đến' : 'Thêm điểm đến mới';

    final List<Marker> markers = [];
    if (_selectedPoint != null) {
      markers.add(
        Marker(
          point: _selectedPoint!,
          width: 36,
          height: 36,
          child: const Icon(
            Icons.location_on,
            color: AppColors.primary,
            size: 36,
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      isEditing ? Icons.edit_location_alt : Icons.add_location_alt,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const Divider(height: 24, color: AppColors.hairline),

                // Error alert
                if (_generalError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _generalError!,
                            style: const TextStyle(fontSize: 13, color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Form Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name Field
                        AppTextField(
                          controller: _nameController,
                          label: 'Tên điểm đến *',
                          hint: 'VD: Hồ Xuân Hương, Chợ Bến Thành',
                          errorText: _fieldErrors?['name'],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Tên điểm đến không được để trống';
                            }
                            if (value.trim().length > 150) {
                              return 'Tên điểm đến không được vượt quá 150 ký tự';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Address Field
                        AppTextField(
                          controller: _addressController,
                          label: 'Địa chỉ *',
                          hint: 'VD: Đường Trần Quốc Toản, Phường 1, TP. Đà Lạt',
                          errorText: _fieldErrors?['address'],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Địa chỉ không được để trống';
                            }
                            if (value.trim().length > 255) {
                              return 'Địa chỉ không được vượt quá 255 ký tự';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Description Field
                        AppTextField(
                          controller: _descriptionController,
                          label: 'Mô tả ngắn',
                          hint: 'Mô tả chi tiết về điểm đến...',
                          maxLines: 3,
                          errorText: _fieldErrors?['description'],
                          validator: (value) {
                            if (value != null && value.trim().length > 2000) {
                              return 'Mô tả không được vượt quá 2000 ký tự';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Image URL Field
                        AppTextField(
                          controller: _imageUrlController,
                          label: 'Đường dẫn ảnh (Image URL)',
                          hint: 'https://example.com/image.jpg',
                          errorText: _fieldErrors?['imageUrl'],
                          validator: (value) {
                            if (value != null && value.trim().length > 500) {
                              return 'Đường dẫn ảnh không được vượt quá 500 ký tự';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // Coordinates Section & Interactive Mini-Map
                        Row(
                          children: [
                            const Icon(Icons.pin_drop_outlined, size: 18, color: AppColors.primary),
                            const SizedBox(width: 6),
                            const Text(
                              'Tọa độ vị trí (Tùy chọn)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            if (_selectedPoint != null)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: AppColors.textSecondary,
                                ),
                                icon: const Icon(Icons.clear, size: 14),
                                label: const Text('Xóa tọa độ', style: TextStyle(fontSize: 12)),
                                onPressed: _clearCoordinates,
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Nhấp vào bản đồ để chọn tọa độ, hoặc nhập thủ công vào các ô bên dưới:',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),

                        // Map View
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 200,
                            child: WebMapView(
                              mapController: _mapController,
                              initialCenter: _selectedPoint ?? MapConstants.fallbackCoordinates,
                              initialZoom: _selectedPoint != null ? 14.0 : MapConstants.fallbackZoom,
                              markers: markers,
                              onTap: _onMapTapped,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Lat & Lon Input Row
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _latController,
                                label: 'Vĩ độ (Latitude)',
                                hint: 'VD: 11.9404',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                errorText: _fieldErrors?['latitude'],
                                onChanged: (_) => _onCoordinateInputsChanged(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppTextField(
                                controller: _lonController,
                                label: 'Kinh độ (Longitude)',
                                hint: 'VD: 108.4385',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                errorText: _fieldErrors?['longitude'],
                                onChanged: (_) => _onCoordinateInputsChanged(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Status Dropdown
                        const Text(
                          'Trạng thái hoạt động',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'ACTIVE',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Đang hoạt động (ACTIVE)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'HIDDEN',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility_off_outlined, size: 16, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text('Đã ẩn (HIDDEN)'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _status = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.hairline),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: 12),
                    AppPrimaryButton(
                      text: isEditing ? 'Lưu thay đổi' : 'Tạo điểm đến',
                      isLoading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _handleSubmit,
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
