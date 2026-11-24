import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:travel_planner_web/core/network/api_exception.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';
import 'package:travel_planner_web/features/locations/data/models/place_model.dart';
import 'package:travel_planner_web/features/locations/data/place_repository.dart';
import 'package:travel_planner_web/features/locations/presentation/widgets/hide_place_dialog.dart';
import 'package:travel_planner_web/features/locations/presentation/widgets/place_form_dialog.dart';
import 'package:travel_planner_web/shared/widgets/admin_data_table.dart';
import 'package:travel_planner_web/shared/widgets/admin_dialog.dart';
import 'package:travel_planner_web/shared/widgets/admin_page_header.dart';
import 'package:travel_planner_web/shared/widgets/admin_status_badge.dart';
import 'package:travel_planner_web/shared/widgets/admin_toolbar.dart';
import 'package:travel_planner_web/shared/widgets/hover_movement.dart';
import 'package:travel_planner_web/shared/widgets/web_map_view.dart';

/// Screen for administering canonical Places (ADMIN role only).
/// Aligned with docs/plan/admin-design-system.md (Minimalism & Swiss Style).
/// Implements enterprise data table with server-side pagination, instant search,
/// category/status filtering, map-based inspection, and CRUD flows.
class AdminPlacesScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final PlaceRepository? repository;
  final bool embedded;

  const AdminPlacesScreen({
    super.key,
    required this.authNotifier,
    this.repository,
    this.embedded = false,
  });

  @override
  State<AdminPlacesScreen> createState() => _AdminPlacesScreenState();
}

class _AdminPlacesScreenState extends State<AdminPlacesScreen> {
  late final PlaceRepository _repository;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<PlaceModel> _places = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _page = 0;
  final int _pageSize = 20;
  int _totalPages = 0;
  int _totalElements = 0;
  String _categoryFilter = 'ALL';
  String _statusFilter = 'ALL'; // ALL, ACTIVE, HIDDEN

  bool get isAdmin {
    final role =
        widget.authNotifier.currentUser?['role']?.toString().toUpperCase();
    return role == 'ADMIN';
  }

  static const List<Map<String, String>> _categories = [
    {'value': 'ALL', 'label': 'Tất cả danh mục'},
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
    _repository = widget.repository ?? PlaceRepository();

    if (isAdmin) {
      _loadPlaces();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      setState(() => _page = 0);
      _loadPlaces(showLoading: false);
    });
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$min';
  }

  Future<void> _loadPlaces({bool showLoading = true}) async {
    if (!isAdmin) return;

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final categoryParam = _categoryFilter == 'ALL' ? null : _categoryFilter;
      final statusParam = _statusFilter == 'ALL' ? null : _statusFilter;
      final keywordParam = _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim();

      final res = await _repository.getAdminPlacesPaged(
        keyword: keywordParam,
        category: categoryParam,
        status: statusParam,
        page: _page,
        size: _pageSize,
        token: widget.authNotifier.token,
      );

      if (mounted) {
        setState(() {
          _places = res.content;
          _totalPages = res.totalPages;
          _totalElements = res.totalElements;
          _page = res.page;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Lỗi không xác định khi tải danh sách địa điểm: ${e.toString()}';
        });
      }
    }
  }

  void _onPageChanged(int newPage) {
    if (newPage != _page && newPage >= 0) {
      setState(() => _page = newPage);
      _loadPlaces(showLoading: true);
    }
  }

  Future<void> _handleCreatePlace() async {
    final created = await PlaceFormDialog.show(
      context,
      onSubmit: ({
        required String name,
        required String address,
        required String category,
        String? description,
        String? imageUrl,
        required double latitude,
        required double longitude,
        String? status,
      }) async {
        final req = CreatePlaceRequest(
          name: name,
          address: address,
          category: category,
          description: description,
          imageUrl: imageUrl,
          latitude: latitude,
          longitude: longitude,
        );
        await _repository.createPlace(req, token: widget.authNotifier.token);
      },
    );

    if (created == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thêm địa điểm chuẩn hóa thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      await _loadPlaces(showLoading: false);
    }
  }

  Future<void> _handleEditPlace(PlaceModel place) async {
    final updated = await PlaceFormDialog.show(
      context,
      place: place,
      onSubmit: ({
        required String name,
        required String address,
        required String category,
        String? description,
        String? imageUrl,
        required double latitude,
        required double longitude,
        String? status,
      }) async {
        final req = UpdatePlaceRequest(
          name: name,
          address: address,
          category: category,
          description: description,
          imageUrl: imageUrl,
          latitude: latitude,
          longitude: longitude,
          status: status ?? place.status,
        );
        await _repository.updatePlace(place.id, req,
            token: widget.authNotifier.token);
      },
    );

    if (updated == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật địa điểm "${place.name}".'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      await _loadPlaces(showLoading: false);
    }
  }

  Future<void> _handleToggleHidePlace(PlaceModel place) async {
    final confirmed = await HidePlaceDialog.show(
      context,
      place: place,
      repository: _repository,
    );

    if (confirmed == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(place.isActive
                ? 'Đã ẩn địa điểm "${place.name}".'
                : 'Đã kích hoạt lại địa điểm "${place.name}".'),
            backgroundColor:
                place.isActive ? AppColors.warning : AppColors.success,
          ),
        );
      }
      await _loadPlaces(showLoading: false);
    }
  }

  void _showPlaceDetailDialog(PlaceModel place) {
    AdminDialog.show<void>(
      context: context,
      width: 640,
      title: 'Chi tiết Địa điểm #${place.id}',
      titleBadge: AdminStatusBadge(status: place.status),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image Preview if available
            if (place.imageUrl != null && place.imageUrl!.isNotEmpty) ...[
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    border: Border.all(color: AppColors.border, width: 1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.network(
                      place.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.all(24),
                        color: AppColors.surfaceSubtle,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image,
                                size: 40, color: AppColors.textMuted),
                            SizedBox(height: 6),
                            Text('Không thể tải hình ảnh địa điểm',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Badges row
            Row(
              children: [
                _buildCategoryBadge(place.categoryDisplay),
                const SizedBox(width: AppSpacing.sm),
                AdminStatusBadge(status: place.status),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'ID: #${place.id}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Place Name
            Text(
              place.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Metadata rows
            _buildDetailRow('Địa chỉ:', place.address,
                icon: Icons.map_outlined),
            if (place.administrativeAreaName != null &&
                place.administrativeAreaName!.isNotEmpty)
              _buildDetailRow('Khu vực:', place.administrativeAreaName!,
                  icon: Icons.location_city_outlined),
            _buildDetailRow('Tọa độ chuẩn hóa:', place.formattedCoordinates,
                icon: Icons.explore_outlined, isSelectable: true),
            if (place.description != null && place.description!.isNotEmpty)
              _buildDetailRow('Mô tả:', place.description!,
                  icon: Icons.notes_outlined),
            if (place.createdAt != null)
              _buildDetailRow('Ngày tạo:', _formatDateTime(place.createdAt!),
                  icon: Icons.calendar_today_outlined),
            if (place.updatedAt != null)
              _buildDetailRow(
                  'Cập nhật gần nhất:', _formatDateTime(place.updatedAt!),
                  icon: Icons.update_outlined),

            // Provider mappings if present
            if (place.providerMappings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Nhà cung cấp định danh (Provider Mappings):',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: place.providerMappings.map((m) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${m.provider}: ${m.providerPlaceId}',
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          color: AppColors.textSecondary),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Interactive Map Preview
            if (place.hasCoordinates) ...[
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Vị trí trên bản đồ chuẩn hóa:',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Container(
                height: 190,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm - 1),
                  child: WebMapView(
                    initialCenter: place.coordinate!,
                    initialZoom: 15,
                    markers: [
                      Marker(
                        point: place.coordinate!,
                        width: 34,
                        height: 34,
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.edit_outlined, size: 14),
          label: const Text('Chỉnh sửa', style: TextStyle(fontSize: 12.5)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.borderStrong),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            _handleEditPlace(place);
          },
        ),
        ElevatedButton.icon(
          icon: Icon(
            place.isActive
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 14,
          ),
          label: Text(
            place.isActive ? 'Ẩn địa điểm' : 'Kích hoạt lại',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                place.isActive ? AppColors.warning : AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            _handleToggleHidePlace(place);
          },
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng',
              style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value,
      {IconData? icon, bool isSelectable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: AppColors.textMuted),
            const SizedBox(width: 6),
          ],
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: isSelectable
                ? SelectableText(
                    value,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản lý Địa điểm Chuẩn hóa')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.xxl),
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.gpp_bad_outlined,
                      size: 56, color: AppColors.error),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Truy cập bị từ chối',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Bạn cần quyền Quản trị viên (ADMIN) để xem và quản lý danh mục địa điểm.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Quay lại'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm)),
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Standalone Enterprise Page Header
          AdminPageHeader(
            title: 'Quản lý Địa điểm Chuẩn hóa (Places)',
            subtitle:
                'Cơ sở dữ liệu địa điểm du lịch, ẩm thực, lưu trú đã được định danh và tọa độ hóa.',
            actions: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Text(
                  'Tổng: $_totalElements địa điểm',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              HoverMovement.button(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Làm mới', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderStrong),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button)),
                  ),
                  onPressed: () => _loadPlaces(showLoading: true),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              HoverMovement.button(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_location_alt_outlined, size: 15),
                  label: const Text('Thêm địa điểm',
                      style: TextStyle(fontSize: 12.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button)),
                  ),
                  onPressed: _handleCreatePlace,
                ),
              ),
            ],
          ),

          // Standard Admin Toolbar (Search, Category Filter, Status Filter)
          AdminToolbar(
            filters: [
              // Search input
              SizedBox(
                width: 260,
                height: 32,
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm theo tên hoặc địa chỉ...',
                    hintStyle: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search,
                        size: 16, color: AppColors.textMuted),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            splashRadius: 14,
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _page = 0);
                              _loadPlaces(showLoading: false);
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 0, horizontal: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: const BorderSide(color: AppColors.primaryAccessible),
                    ),
                  ),
                ),
              ),

              // Category dropdown
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Danh mục: ',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _categoryFilter,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textPrimary),
                        items: _categories.map((c) {
                          return DropdownMenuItem(
                              value: c['value'], child: Text(c['label']!));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null && val != _categoryFilter) {
                            setState(() {
                              _categoryFilter = val;
                              _page = 0;
                            });
                            _loadPlaces();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),

              // Status dropdown
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Trạng thái: ',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textPrimary),
                        items: const [
                          DropdownMenuItem(
                              value: 'ALL', child: Text('Tất cả trạng thái')),
                          DropdownMenuItem(
                              value: 'ACTIVE',
                              child: Text('Đang hoạt động')),
                          DropdownMenuItem(
                              value: 'HIDDEN', child: Text('Đã ẩn')),
                        ],
                        onChanged: (val) {
                          if (val != null && val != _statusFilter) {
                            setState(() {
                              _statusFilter = val;
                              _page = 0;
                            });
                            _loadPlaces();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Error Banner if server/network failure
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.errorBorder, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: AppColors.error),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.error,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _loadPlaces(showLoading: true),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.error,
                      ),
                      child: const Text('Thử lại',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),

          // Places Data Table Workspace
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dynamicAddressWidth =
                      (constraints.maxWidth - 780).clamp(200.0, 600.0);
                  final dynamicNameWidth =
                      (constraints.maxWidth > 1200) ? 260.0 : 180.0;

                  return AdminDataTable(
                    isLoading: _isLoading,
                    minWidth: constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : 880.0,
                    emptyMessage: _searchController.text.isNotEmpty
                        ? 'Không tìm thấy địa điểm nào khớp với từ khóa "${_searchController.text}".'
                        : 'Không tìm thấy địa điểm nào',
                    currentPage: _page,
                    totalPages: _totalPages,
                    totalElements: _totalElements,
                    pageSize: _pageSize,
                    onPageChanged: _onPageChanged,
                    columns: [
                      AdminDataColumn.text('ID', numeric: true),
                      AdminDataColumn.text('TÊN ĐỊA ĐIỂM'),
                      AdminDataColumn.text('DANH MỤC'),
                      AdminDataColumn.text('ĐỊA CHỈ'),
                      AdminDataColumn.text('KHU VỰC'),
                      AdminDataColumn.text('TỌA ĐỘ'),
                      AdminDataColumn.text('TRẠNG THÁI'),
                      AdminDataColumn.text('THAO TÁC'),
                    ],
                    rows: _places.map((place) {
                      return AdminDataRow(
                        onTap: () => _showPlaceDetailDialog(place),
                        cells: [
                          Text(
                            '#${place.id}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  color: AppColors.surfaceSubtle,
                                  child: place.imageUrl != null &&
                                          place.imageUrl!.isNotEmpty
                                      ? Image.network(
                                          place.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error,
                                                  stackTrace) =>
                                              const Icon(Icons.broken_image,
                                                  size: 16,
                                                  color: AppColors.textMuted),
                                        )
                                      : const Icon(Icons.place_outlined,
                                          size: 16, color: AppColors.textMuted),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                    minWidth: 140, maxWidth: dynamicNameWidth),
                                child: Tooltip(
                                  message: place.name,
                                  waitDuration:
                                      const Duration(milliseconds: 400),
                                  child: Text(
                                    place.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          _buildCategoryBadge(place.categoryDisplay),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                                minWidth: 200, maxWidth: dynamicAddressWidth),
                            child: Tooltip(
                              message: place.address,
                              waitDuration:
                                  const Duration(milliseconds: 400),
                              child: Text(
                                place.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          ),
                          Text(
                            place.administrativeAreaName ?? '-',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                          Tooltip(
                            message: place.hasCoordinates
                                ? 'Tọa độ: ${place.latitude}, ${place.longitude}'
                                : 'Chưa có tọa độ',
                            child: Text(
                              place.hasCoordinates
                                  ? '${place.latitude!.toStringAsFixed(4)}, ${place.longitude!.toStringAsFixed(4)}'
                                  : '-',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontFamily: 'monospace',
                                  color: AppColors.textSecondary),
                            ),
                          ),
                          AdminStatusBadge(status: place.status),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HoverMovement.button(
                                child: Tooltip(
                                  message: 'Xem chi tiết địa điểm',
                                  child: TextButton(
                                    onPressed: () =>
                                        _showPlaceDetailDialog(place),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.textSecondary,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                    ),
                                    child: const Text('Chi tiết',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ),
                              HoverMovement.button(
                                child: Tooltip(
                                  message: 'Chỉnh sửa thông tin địa điểm',
                                  child: TextButton(
                                    onPressed: () => _handleEditPlace(place),
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          AppColors.primaryAccessible,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                    ),
                                    child: const Text('Sửa',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ),
                              HoverMovement.button(
                                child: Tooltip(
                                  message: place.isActive
                                      ? 'Tạm ẩn địa điểm khỏi bản đồ'
                                      : 'Kích hoạt lại địa điểm trên bản đồ',
                                  child: TextButton(
                                    onPressed: () =>
                                        _handleToggleHidePlace(place),
                                    style: TextButton.styleFrom(
                                      foregroundColor: place.isActive
                                          ? AppColors.warning
                                          : AppColors.success,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                    ),
                                    child: Text(
                                      place.isActive ? 'Ẩn' : 'Kích hoạt',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
