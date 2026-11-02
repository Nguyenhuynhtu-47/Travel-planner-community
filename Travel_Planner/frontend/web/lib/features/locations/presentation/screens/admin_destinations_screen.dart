import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:travel_planner_web/core/network/api_exception.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';
import 'package:travel_planner_web/features/locations/data/destination_repository.dart';
import 'package:travel_planner_web/features/locations/data/models/destination_model.dart';
import 'package:travel_planner_web/features/locations/presentation/widgets/destination_form_dialog.dart';
import 'package:travel_planner_web/features/locations/presentation/widgets/hide_destination_dialog.dart';
import 'package:travel_planner_web/shared/widgets/web_map_view.dart';

/// Screen for administering catalog destinations (ADMIN role only).
class AdminDestinationsScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final DestinationRepository? repository;

  const AdminDestinationsScreen({
    super.key,
    required this.authNotifier,
    this.repository,
  });

  @override
  State<AdminDestinationsScreen> createState() => _AdminDestinationsScreenState();
}

class _AdminDestinationsScreenState extends State<AdminDestinationsScreen> {
  late final DestinationRepository _repository;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<Destination> _destinations = [];
  Destination? _selectedDestination;
  bool _isLoading = false;
  String? _errorMessage;
  String _statusFilter = 'ALL'; // ALL, ACTIVE, HIDDEN

  bool get isAdmin {
    final role = widget.authNotifier.currentUser?['role']?.toString().toUpperCase();
    return role == 'ADMIN';
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DestinationRepository();

    if (isAdmin) {
      _loadDestinations();
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
      _loadDestinations(showLoading: false);
    });
  }

  Future<void> _loadDestinations({bool showLoading = true}) async {
    if (!isAdmin) return;

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final statusParam = _statusFilter == 'ALL' ? null : _statusFilter;
      final keywordParam = _searchController.text.trim().isEmpty ? null : _searchController.text.trim();

      final list = await _repository.getAdminDestinations(
        keyword: keywordParam,
        status: statusParam,
      );

      if (mounted) {
        setState(() {
          _destinations = list;
          _isLoading = false;
          _errorMessage = null;

          // Maintain or update selection
          if (_selectedDestination != null) {
            final match = _destinations.where((d) => d.id == _selectedDestination!.id).firstOrNull;
            _selectedDestination = match ?? (_destinations.isNotEmpty ? _destinations.first : null);
          } else if (_destinations.isNotEmpty) {
            _selectedDestination = _destinations.first;
          } else {
            _selectedDestination = null;
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
          _errorMessage = 'Không thể tải danh sách điểm đến: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _handleCreateDestination() async {
    final success = await DestinationFormDialog.show(
      context,
      onSubmit: ({
        required String name,
        required String address,
        String? description,
        String? imageUrl,
        double? latitude,
        double? longitude,
        String? status,
      }) async {
        final created = await _repository.createDestination(
          CreateDestinationRequest(
            name: name,
            address: address,
            description: description,
            imageUrl: imageUrl,
            latitude: latitude,
            longitude: longitude,
            status: status ?? 'ACTIVE',
          ),
        );
        _selectedDestination = created;
      },
    );

    if (success == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thêm điểm đến mới thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      await _loadDestinations(showLoading: false);
    }
  }

  Future<void> _handleEditDestination(Destination destination) async {
    final success = await DestinationFormDialog.show(
      context,
      destination: destination,
      onSubmit: ({
        required String name,
        required String address,
        String? description,
        String? imageUrl,
        double? latitude,
        double? longitude,
        String? status,
      }) async {
        final updated = await _repository.updateDestination(
          destination.id,
          UpdateDestinationRequest(
            name: name,
            address: address,
            description: description,
            imageUrl: imageUrl,
            latitude: latitude,
            longitude: longitude,
            status: status,
          ),
        );
        _selectedDestination = updated;
      },
    );

    if (success == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật điểm đến thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      await _loadDestinations(showLoading: false);
    }
  }

  Future<void> _handleHideDestination(Destination destination) async {
    final confirmed = await HideDestinationDialog.show(
      context,
      destination: destination,
      repository: _repository,
    );

    if (confirmed == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã ẩn điểm đến "${destination.name}".'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      await _loadDestinations(showLoading: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quản lý Điểm đến'),
        ),
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
                    const Icon(
                      Icons.gpp_bad_outlined,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Truy cập bị từ chối',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bạn cần quyền Quản trị viên (ADMIN) để xem và quản lý danh mục điểm đến.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
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
        title: const Text('Quản lý Điểm đến (Destinations)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () => _loadDestinations(showLoading: true),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('Thêm điểm đến'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: _handleCreateDestination,
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
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
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

  Widget _buildFilterBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo tên hoặc địa chỉ điểm đến...',
                prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _loadDestinations(showLoading: false);
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
            ),
          ),
          const SizedBox(width: 16),
          Container(
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
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Đang hoạt động (ACTIVE)')),
                  DropdownMenuItem(value: 'HIDDEN', child: Text('Đã ẩn (HIDDEN)')),
                ],
                onChanged: (val) {
                  if (val != null && val != _statusFilter) {
                    setState(() {
                      _statusFilter = val;
                    });
                    _loadDestinations();
                  }
                },
              ),
            ),
          ),
        ],
      ),
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
              onPressed: () => _loadDestinations(showLoading: true),
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
        // Left Column: List
        Expanded(
          flex: 6,
          child: _buildDestinationsList(),
        ),
        const VerticalDivider(width: 1, color: AppColors.border),
        // Right Column: Detail & Map
        Expanded(
          flex: 5,
          child: _selectedDestination != null
              ? _buildDestinationDetailPanel(_selectedDestination!)
              : _buildEmptyDetailPlaceholder(),
        ),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return _buildDestinationsList();
  }

  Widget _buildDestinationsList() {
    if (_destinations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_outlined, size: 48, color: AppColors.muted),
              const SizedBox(height: 12),
              const Text(
                'Không tìm thấy điểm đến nào phù hợp.',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Thêm điểm đến mới'),
                onPressed: _handleCreateDestination,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _destinations.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.hairlineSoft),
      itemBuilder: (context, index) {
        final item = _destinations[index];
        final isSelected = _selectedDestination?.id == item.id;

        return ListTile(
          selected: isSelected,
          selectedTileColor: AppColors.primaryLight.withAlpha(80),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.status == 'ACTIVE'
                  ? AppColors.primaryLight
                  : AppColors.surfaceStrong,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: item.status == 'ACTIVE'
                    ? AppColors.primary.withAlpha(50)
                    : AppColors.border,
              ),
            ),
            child: Icon(
              Icons.place_outlined,
              color: item.status == 'ACTIVE' ? AppColors.primary : AppColors.muted,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _buildStatusBadge(item.status),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                item.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    item.hasCoordinates ? Icons.gps_fixed : Icons.gps_off,
                    size: 14,
                    color: item.hasCoordinates ? AppColors.success : AppColors.mutedSoft,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.hasCoordinates
                        ? '${item.latitude!.toStringAsFixed(4)}, ${item.longitude!.toStringAsFixed(4)}'
                        : 'Chưa có tọa độ',
                    style: TextStyle(
                      fontSize: 12,
                      color: item.hasCoordinates ? AppColors.textBody : AppColors.mutedSoft,
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Chỉnh sửa',
                onPressed: () => _handleEditDestination(item),
              ),
              if (item.status == 'ACTIVE')
                IconButton(
                  icon: const Icon(Icons.visibility_off_outlined, size: 20, color: AppColors.warning),
                  tooltip: 'Ẩn điểm đến (Soft-delete)',
                  onPressed: () => _handleHideDestination(item),
                ),
            ],
          ),
          onTap: () {
            setState(() {
              _selectedDestination = item;
            });
            // If in compact layout, open bottom sheet or detail dialog
            if (MediaQuery.of(context).size.width < 960) {
              _showCompactDetailSheet(item);
            }
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    final isActive = status.toUpperCase() == 'ACTIVE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? AppColors.success.withAlpha(25) : AppColors.mutedSoft.withAlpha(35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppColors.success : AppColors.borderStrong,
          width: 0.8,
        ),
      ),
      child: Text(
        isActive ? 'Đang hoạt động' : 'Đã ẩn',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? AppColors.success : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildEmptyDetailPlaceholder() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined, size: 48, color: AppColors.mutedSoft),
            SizedBox(height: 12),
            Text(
              'Chọn một điểm đến trong danh sách để xem chi tiết và vị trí bản đồ.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationDetailPanel(Destination d) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildStatusBadge(d.status),
                  ],
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Chỉnh sửa'),
                onPressed: () => _handleEditDestination(d),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Info tiles
          _buildInfoRow(Icons.place_outlined, 'Địa chỉ:', d.address),
          if (d.description != null && d.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildInfoRow(Icons.notes_outlined, 'Mô tả:', d.description!),
          ],
          const SizedBox(height: 10),
          _buildInfoRow(
            Icons.gps_fixed,
            'Tọa độ:',
            d.hasCoordinates
                ? 'Vĩ độ: ${d.latitude}, Kinh độ: ${d.longitude}'
                : 'Chưa có tọa độ địa lý',
          ),
          const SizedBox(height: 20),
          // Map preview
          const Text(
            'Vị trí trên bản đồ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 320,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: d.hasCoordinates
                  ? WebMapView(
                      initialCenter: LatLng(d.latitude!, d.longitude!),
                      initialZoom: 15.0,
                      markers: [
                        Marker(
                          point: LatLng(d.latitude!, d.longitude!),
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.location_on,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.map_outlined, size: 40, color: AppColors.mutedSoft),
                            const SizedBox(height: 12),
                            const Text(
                              'Điểm đến này chưa có tọa độ địa lý.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.add_location),
                              label: const Text('Gán tọa độ ngay'),
                              onPressed: () => _handleEditDestination(d),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: AppColors.textBody),
          ),
        ),
      ],
    );
  }

  void _showCompactDetailSheet(Destination d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: _buildDestinationDetailPanel(d),
        ),
      ),
    );
  }
}
