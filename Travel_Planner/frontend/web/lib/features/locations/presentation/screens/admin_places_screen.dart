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
import 'package:travel_planner_web/shared/widgets/web_map_view.dart';

/// Screen for administering canonical Places (ADMIN role only).
class AdminPlacesScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final PlaceRepository? repository;

  const AdminPlacesScreen({
    super.key,
    required this.authNotifier,
    this.repository,
  });

  @override
  State<AdminPlacesScreen> createState() => _AdminPlacesScreenState();
}

class _AdminPlacesScreenState extends State<AdminPlacesScreen> {
  late final PlaceRepository _repository;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<PlaceModel> _places = [];
  PlaceModel? _selectedPlace;
  bool _isLoading = false;
  String? _errorMessage;
  String _categoryFilter = 'ALL';
  String _statusFilter = 'ALL'; // ALL, ACTIVE, HIDDEN

  bool get isAdmin {
    final role = widget.authNotifier.currentUser?['role']?.toString().toUpperCase();
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
      _loadPlaces(showLoading: false);
    });
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
      final keywordParam = _searchController.text.trim().isEmpty ? null : _searchController.text.trim();

      final list = await _repository.getAdminPlaces(
        keyword: keywordParam,
        category: categoryParam,
        status: statusParam,
      );

      if (mounted) {
        setState(() {
          _places = list;
          _isLoading = false;
          _errorMessage = null;

          if (_selectedPlace != null) {
            final match = _places.where((p) => p.id == _selectedPlace!.id).firstOrNull;
            _selectedPlace = match ?? (_places.isNotEmpty ? _places.first : null);
          } else if (_places.isNotEmpty) {
            _selectedPlace = _places.first;
          } else {
            _selectedPlace = null;
          }
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
          _errorMessage = 'Lỗi không xác định khi tải danh sách địa điểm: ${e.toString()}';
        });
      }
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
        await _repository.createPlace(req);
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
        await _repository.updatePlace(place.id, req);
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
            backgroundColor: place.isActive ? AppColors.warning : AppColors.success,
          ),
        );
      }
      await _loadPlaces(showLoading: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản lý Địa điểm Chuẩn hóa')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              margin: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gpp_bad_outlined, size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    const Text(
                      'Truy cập bị từ chối',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bạn cần quyền Quản trị viên (ADMIN) để xem và quản lý danh mục địa điểm.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Quay lại'),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Địa điểm Chuẩn hóa (Places)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () => _loadPlaces(showLoading: true),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('Thêm địa điểm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: _handleCreatePlace,
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;
          return Column(
            children: [
              _buildFilterBar(),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _errorMessage != null
                        ? _buildErrorView()
                        : isWide
                            ? _buildWideLayout()
                            : _buildCompactLayout(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _categoryFilter,
          icon: const Icon(Icons.category_outlined, size: 20, color: AppColors.textSecondary),
          items: _categories.map((c) {
            return DropdownMenuItem(value: c['value'], child: Text(c['label']!));
          }).toList(),
          onChanged: (val) {
            if (val != null && val != _categoryFilter) {
              setState(() => _categoryFilter = val);
              _loadPlaces();
            }
          },
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter,
          icon: const Icon(Icons.filter_list, size: 20, color: AppColors.textSecondary),
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('Tất cả trạng thái')),
            DropdownMenuItem(value: 'ACTIVE', child: Text('Đang hoạt động')),
            DropdownMenuItem(value: 'HIDDEN', child: Text('Đã ẩn')),
          ],
          onChanged: (val) {
            if (val != null && val != _statusFilter) {
              setState(() => _statusFilter = val);
              _loadPlaces();
            }
          },
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 850;

        final searchField = TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm theo tên hoặc địa chỉ địa điểm...',
            prefixIcon: const Icon(Icons.search, color: AppColors.muted),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _loadPlaces(showLoading: false);
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: AppColors.surfaceSoft,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        );

        if (isNarrow) {
          return Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildCategoryDropdown()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatusDropdown()),
                  ],
                ),
              ],
            ),
          );
        }

        return Container(
          color: AppColors.surface,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: searchField,
              ),
              const SizedBox(width: 12),
              _buildCategoryDropdown(),
              const SizedBox(width: 12),
              _buildStatusDropdown(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Đã xảy ra lỗi khi tải dữ liệu.',
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
              onPressed: () => _loadPlaces(showLoading: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 6, child: _buildPlacesList()),
        const VerticalDivider(width: 1, color: AppColors.border),
        Expanded(
          flex: 5,
          child: _selectedPlace != null
              ? _buildPlaceDetailPanel(_selectedPlace!)
              : _buildEmptyDetailPlaceholder(),
        ),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return _buildPlacesList();
  }

  Widget _buildPlacesList() {
    if (_places.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place_outlined, size: 56, color: AppColors.muted),
              const SizedBox(height: 16),
              const Text(
                'Không tìm thấy địa điểm nào',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Thử thay đổi bộ lọc tìm kiếm hoặc thêm địa điểm chuẩn hóa mới.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Thêm địa điểm ngay'),
                onPressed: _handleCreatePlace,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _places.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final place = _places[index];
        final isSelected = _selectedPlace?.id == place.id;

        return InkWell(
          onTap: () {
            setState(() => _selectedPlace = place);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 72,
                    height: 72,
                    color: AppColors.surfaceSoft,
                    child: place.imageUrl != null && place.imageUrl!.isNotEmpty
                        ? Image.network(
                            place.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: AppColors.muted),
                          )
                        : const Icon(Icons.image_not_supported_outlined, color: AppColors.muted),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              place.name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildCategoryBadge(place.categoryDisplay),
                          const SizedBox(width: 6),
                          _buildStatusBadge(place.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        place.address,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.explore_outlined, size: 14, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Text(
                            place.formattedCoordinates,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceDetailPanel(PlaceModel place) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action row
          Row(
            children: [
              Expanded(
                child: Text(
                  place.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Chỉnh sửa'),
                onPressed: () => _handleEditPlace(place),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: place.isActive ? AppColors.warning : AppColors.success,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(
                  place.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 16,
                ),
                label: Text(place.isActive ? 'Ẩn' : 'Kích hoạt'),
                onPressed: () => _handleToggleHidePlace(place),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Badges
          Row(
            children: [
              _buildCategoryBadge(place.categoryDisplay),
              const SizedBox(width: 8),
              _buildStatusBadge(place.status),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'ID: #${place.id}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Image if present
          if (place.imageUrl != null && place.imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 180,
                width: double.infinity,
                color: AppColors.surfaceSoft,
                child: Image.network(
                  place.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Center(
                    child: Text('Không thể tải ảnh', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Address
          _buildInfoRow(Icons.map_outlined, 'Địa chỉ', place.address),
          const SizedBox(height: 12),

          // Coordinates
          _buildInfoRow(Icons.explore_outlined, 'Tọa độ chuẩn hóa', place.formattedCoordinates),
          const SizedBox(height: 12),

          // Description
          if (place.description != null && place.description!.isNotEmpty) ...[
            _buildInfoRow(Icons.notes_outlined, 'Mô tả', place.description!),
            const SizedBox(height: 12),
          ],

          // Map preview
          if (place.hasCoordinates) ...[
            const SizedBox(height: 8),
            const Text(
              'Vị trí trên bản đồ',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: WebMapView(
                  initialCenter: place.coordinate!,
                  initialZoom: 15,
                  markers: [
                    Marker(
                      point: place.coordinate!,
                      width: 36,
                      height: 36,
                      child: const Icon(Icons.location_on, color: AppColors.primary, size: 32),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyDetailPlaceholder() {
    return const Center(
      child: Text(
        'Chọn một địa điểm từ danh sách để xem chi tiết.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildCategoryBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isActive = status.toUpperCase() == 'ACTIVE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'HIDDEN',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? AppColors.success : AppColors.warning,
        ),
      ),
    );
  }
}
