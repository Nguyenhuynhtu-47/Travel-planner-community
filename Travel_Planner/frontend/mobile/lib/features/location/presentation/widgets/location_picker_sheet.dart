import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_map_view.dart';
import '../../data/location_repository.dart';
import '../../data/models/location_search_result.dart';

/// The result returned when a user confirms a selected location in [LocationPickerSheet].
class CustomLocationResult {
  final String locationName;
  final String? address;
  final double latitude;
  final double longitude;
  final String? placeId;
  final String? locationProvider;

  const CustomLocationResult({
    required this.locationName,
    this.address,
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.locationProvider,
  });

  factory CustomLocationResult.fromSearchResult(LocationSearchResult result) {
    if (!result.hasCoordinates ||
        !result.latitude!.isFinite ||
        !result.longitude!.isFinite ||
        result.latitude! < -90 ||
        result.latitude! > 90 ||
        result.longitude! < -180 ||
        result.longitude! > 180) {
      throw ArgumentError.value(
        result,
        'result',
        'Location result needs valid coordinates',
      );
    }
    return CustomLocationResult(
      locationName: result.name.isNotEmpty ? result.name : 'Vị trí đã ghim',
      address: result.formattedAddress.isNotEmpty
          ? result.formattedAddress
          : null,
      latitude: result.latitude!,
      longitude: result.longitude!,
      placeId: result.placeId.isNotEmpty ? result.placeId : null,
      locationProvider: result.provider ?? 'LOCATION_IQ',
    );
  }

  @override
  String toString() =>
      'CustomLocationResult(name: $locationName, lat: $latitude, lng: $longitude, address: $address)';
}

/// Opens the mobile modal bottom sheet for picking a location on the map.
///
/// Supports place search autocomplete via [LocationRepository], interactive
/// map preview, and manual offline pin-drop fallback.
Future<CustomLocationResult?> showLocationPickerSheet(
  BuildContext context, {
  LocationRepository? repository,
  LatLng? initialCenter,
  String? initialName,
  String? initialAddress,
  String? initialPlaceId,
  String? initialProvider,
  String? locationContext,
  String? token,
}) {
  return showModalBottomSheet<CustomLocationResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: false, // Prevent sheet drag from conflicting with map gestures
    builder: (ctx) => LocationPickerSheet(
      repository: repository,
      initialCenter: initialCenter,
      initialName: initialName,
      initialAddress: initialAddress,
      initialPlaceId: initialPlaceId,
      initialProvider: initialProvider,
      locationContext: locationContext,
      token: token,
    ),
  );
}

/// Reusable modal sheet widget allowing users to search places or manually drop/move
/// a pin on an interactive map.
class LocationPickerSheet extends StatefulWidget {
  final LocationRepository? repository;
  final LatLng? initialCenter;
  final String? initialName;
  final String? initialAddress;
  final String? initialPlaceId;
  final String? initialProvider;
  final String? locationContext;
  final String? token;

  const LocationPickerSheet({
    super.key,
    this.repository,
    this.initialCenter,
    this.initialName,
    this.initialAddress,
    this.initialPlaceId,
    this.initialProvider,
    this.locationContext,
    this.token,
  });

  /// Static helper method to display the sheet.
  static Future<CustomLocationResult?> show(
    BuildContext context, {
    LocationRepository? repository,
    LatLng? initialCenter,
    String? initialName,
    String? initialAddress,
    String? initialPlaceId,
    String? initialProvider,
    String? locationContext,
    String? token,
  }) => showLocationPickerSheet(
    context,
    repository: repository,
    initialCenter: initialCenter,
    initialName: initialName,
    initialAddress: initialAddress,
    initialPlaceId: initialPlaceId,
    initialProvider: initialProvider,
    locationContext: locationContext,
    token: token,
  );

  static String formatQueryWithContext(String query, String? locationContext) {
    final context = locationContext?.trim();
    if (context == null || context.isEmpty) return query;
    final lowerQuery = query.toLowerCase();

    // Do not append context if query already includes full or stripped context (e.g. "Hồ Chí Minh")
    final strippedContext = context
        .replaceAll(RegExp(r'^(thành phố|tp\.?|tỉnh)\s+', caseSensitive: false), '')
        .trim();
    if (lowerQuery.contains(context.toLowerCase()) ||
        (strippedContext.isNotEmpty &&
            lowerQuery.contains(strippedContext.toLowerCase()))) {
      return query;
    }

    // Do not append city context if the user already specified a district, ward, province,
    // preposition (e.g. "gần", "ở", "tại"), comma, or an explicit known city/province.
    final hasRegionalIndicator = lowerQuery.contains(',') ||
        RegExp(
          r'(^|[^\p{L}\p{N}])(tỉnh|tinh|thành phố|thanh pho|tp\.?|quận|quan|huyện|huyen|thị xã|thi xa|thị trấn|thi tran|phường|phuong|xã|xa|đảo|dao|gần|gan|tại|tai|ở|o)([^\p{L}\p{N}]|$)',
          caseSensitive: false,
          unicode: true,
        ).hasMatch(lowerQuery) ||
        RegExp(
          r'(^|[^\p{L}\p{N}])(da lat|đà lạt|vung tau|vũng tàu|ha noi|hà nội|sai gon|sài gòn|ho chi minh|hồ chí minh|da nang|đà nẵng|nha trang|hue|huế|can tho|cần thơ|hai phong|hải phòng|long xuyen|long xuyên|phu quoc|phú quốc|hoi an|hội an|quy nhon|quy nhơn|phan thiet|phan thiết|vinh|ha long|hạ long|sa pa|sapa|lam dong|lâm đồng|an giang|dong nai|đồng nai|binh duong|bình dương|ba ria|bà rịa|bac giang|bắc giang|bac kan|bắc kạn|bac lieu|bạc liêu|bac ninh|bắc ninh|ben tre|bến tre|binh dinh|bình định|binh phuoc|bình phước|binh thuan|bình thuận|ca mau|cà mau|cao bang|cao bằng|dak lak|đắk lắk|dak nong|đắk nông|dien bien|điện biên|dong thap|đồng tháp|gia lai|ha giang|hà giang|ha nam|hà nam|ha tinh|hà tĩnh|hai duong|hải dương|hau giang|hậu giang|hoa binh|hòa bình|hung yen|hưng yên|khanh hoa|khánh hòa|kien giang|kiên giang|kon tum|lai chau|lai châu|lang son|lạng sơn|lao cai|lào cai|long an|nam dinh|nam định|nghe an|nghệ an|ninh binh|ninh bình|ninh thuan|ninh thuận|phu tho|phú thọ|phu yen|phú yên|quang binh|quảng bình|quang nam|quảng nam|quang ngai|quảng ngãi|quang ninh|quảng ninh|quang tri|quảng trị|soc trang|sóc trăng|son la|sơn la|tay ninh|tây ninh|thai binh|thái bình|thai nguyen|thái nguyên|thanh hoa|thanh hóa|thua thien hue|thừa thiên huế|tien giang|tiền giang|tra vinh|trà vinh|tuyen quang|tuyên quang|vinh long|vĩnh long|vinh phuc|vĩnh phúc|yen bai|yên bái)([^\p{L}\p{N}]|$)',
          caseSensitive: false,
          unicode: true,
        ).hasMatch(lowerQuery);
    if (hasRegionalIndicator) {
      return query;
    }

    final availableContextLength = 100 - query.length - 2;
    if (availableContextLength <= 0) return query;
    final boundedContext = context.length > availableContextLength
        ? context.substring(0, availableContextLength).trim()
        : context;
    if (boundedContext.isEmpty) return query;
    return '$query, $boundedContext';
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  late final LocationRepository _repository;
  late final MapController _mapController;
  late final TextEditingController _searchController;

  Timer? _debounceTimer;
  int _searchRequestId = 0;
  int _reverseGeocodeRequestId = 0;

  bool _isSearching = false;
  String? _searchError;
  List<LocationSearchResult> _searchResults = [];
  bool _showSearchResults = false;

  LatLng? _selectedPoint;
  String? _selectedName;
  String? _selectedAddress;
  String? _selectedPlaceId;
  String? _selectedProvider;
  bool _isReverseGeocoding = false;
  late LatLng _viewportCenter;
  String _nearbyCategory = 'ALL';

  static const String fallbackLocationName = 'Vị trí đã ghim';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocationRepository();
    _mapController = MapController();
    _searchController = TextEditingController();

    if (widget.initialCenter != null) {
      _selectedPoint = widget.initialCenter;
      _selectedName = widget.initialName?.isNotEmpty == true
          ? widget.initialName
          : fallbackLocationName;
      _selectedAddress = widget.initialAddress;
      _selectedPlaceId = widget.initialPlaceId;
      _selectedProvider = widget.initialProvider ?? 'MANUAL_PIN';
      _viewportCenter = widget.initialCenter!;
    } else {
      _viewportCenter =
          LatLng(MapConstants.fallbackLatitude, MapConstants.fallbackLongitude);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounceTimer?.cancel();
    final requestId = ++_searchRequestId;
    final query = text.trim();

    if (query.length < 2) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _searchError = null;
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
      _showSearchResults = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await _repository.searchLocations(
          _queryWithLocationContext(query),
          latitude: _viewportCenter.latitude,
          longitude: _viewportCenter.longitude,
          token: widget.token,
        );

        if (!mounted || requestId != _searchRequestId) return;

        setState(() {
          _isSearching = false;
          _searchResults = results;
          if (results.isEmpty) {
            _searchError = 'Không tìm thấy địa điểm phù hợp';
          }
        });
      } on ApiException catch (e) {
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          _isSearching = false;
          _searchResults = [];
          _searchError = e.statusCode == 429
              ? 'Đã vượt quá giới hạn tìm kiếm, vui lòng thử lại sau.'
              : (e.message.isNotEmpty ? e.message : 'Lỗi tìm kiếm địa điểm');
        });
      } catch (_) {
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          _isSearching = false;
          _searchResults = [];
          _searchError = 'Không thể kết nối máy chủ tìm kiếm.';
        });
      }
    });
  }

  String _queryWithLocationContext(String query) =>
      LocationPickerSheet.formatQueryWithContext(query, widget.locationContext);

  Future<void> _searchNearby(String category) async {
    _debounceTimer?.cancel();
    final requestId = ++_searchRequestId;
    FocusScope.of(context).unfocus();
    setState(() {
      _nearbyCategory = category;
      _isSearching = true;
      _searchError = null;
      _searchResults = [];
      _showSearchResults = true;
    });
    try {
      final results = await _repository.searchNearby(
        latitude: _viewportCenter.latitude,
        longitude: _viewportCenter.longitude,
        category: category,
        token: widget.token,
      );
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isSearching = false;
        _searchResults = results;
        if (results.isEmpty) _searchError = 'Chưa tìm thấy địa điểm quanh đây';
      });
    } on ApiException catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isSearching = false;
        _searchError = e.statusCode == 429
            ? 'Đã vượt quá giới hạn tìm kiếm, vui lòng thử lại sau.'
            : (e.message.isNotEmpty
                  ? e.message
                  : 'Không thể tìm địa điểm quanh đây');
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isSearching = false;
        _searchError = 'Không thể kết nối máy chủ tìm kiếm.';
      });
    }
  }

  void _selectSearchResult(LocationSearchResult result) {
    FocusScope.of(context).unfocus();
    _debounceTimer?.cancel();
    ++_searchRequestId;
    ++_reverseGeocodeRequestId;
    final point = result.hasCoordinates
        ? LatLng(result.latitude!, result.longitude!)
        : null;

    if (point == null ||
        !point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude < -90 ||
        point.latitude > 90 ||
        point.longitude < -180 ||
        point.longitude > 180) {
      setState(() {
        _showSearchResults = true;
        _searchResults = [];
        _searchError =
            'Địa điểm này chưa có tọa độ hợp lệ. Hãy ghim vị trí trên bản đồ.';
        _selectedPoint = null;
        _selectedName = null;
        _selectedAddress = null;
        _selectedPlaceId = null;
        _selectedProvider = null;
      });
      return;
    }

    setState(() {
      _showSearchResults = false;
      _isSearching = false;
      _searchController.text = result.name;
      _selectedName = result.name.isNotEmpty
          ? result.name
          : fallbackLocationName;
      _selectedAddress = result.formattedAddress.isNotEmpty
          ? result.formattedAddress
          : null;
      _selectedPlaceId = result.placeId.isNotEmpty ? result.placeId : null;
      _selectedProvider = result.provider ?? 'LOCATION_IQ';
      _selectedPoint = point;
      _viewportCenter = point;
    });

    final zoom = result.isCityOrAdministrative ? 12.0 : 15.5;
    _mapController.move(point, zoom);
  }

  Future<void> _handleMapTap(LatLng point) async {
    FocusScope.of(context).unfocus();
    _debounceTimer?.cancel();
    ++_searchRequestId;
    final requestId = ++_reverseGeocodeRequestId;

    setState(() {
      _showSearchResults = false;
      _selectedPoint = point;
      _viewportCenter = point;
      _selectedName = fallbackLocationName;
      _selectedAddress = null;
      _selectedPlaceId = null;
      _selectedProvider = 'MANUAL_PIN';
      _isReverseGeocoding = true;
    });

    try {
      final result = await _repository.reverseGeocode(
        point.latitude,
        point.longitude,
        token: widget.token,
      );

      if (!mounted || requestId != _reverseGeocodeRequestId) return;

      setState(() {
        _isReverseGeocoding = false;
        if (result != null) {
          _selectedAddress = result.formattedAddress.isNotEmpty
              ? result.formattedAddress
              : null;
          // Reverse geocoding is descriptive only; it must not turn a manual pin
          // into a provider place with an identity at a different coordinate.
        }
      });
    } catch (_) {
      // Zero-API resilience: If reverse geocode fails, times out, or returns 404/429,
      // fallback name remains 'Vị trí đã ghim'. Coordinates remain completely valid and saveable.
      if (!mounted || requestId != _reverseGeocodeRequestId) return;
      setState(() {
        _isReverseGeocoding = false;
      });
    }
  }

  Future<void> _editLocationName() async {
    final controller = TextEditingController(text: _selectedName ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text(
          'Đổi tên vị trí',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 150,
          decoration: const InputDecoration(
            labelText: 'Tên vị trí',
            hintText: 'VD: Cà phê Tùng, Cổng soát vé...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final trimmed = controller.text.trim();
              Navigator.of(dialogCtx)
                  .pop(trimmed.isNotEmpty ? trimmed : fallbackLocationName);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (newName != null && mounted) {
      setState(() {
        _selectedName = newName;
      });
    }
  }

  void _confirm() {
    if (_selectedPoint == null) return;
    final result = CustomLocationResult(
      locationName: (_selectedName != null && _selectedName!.trim().isNotEmpty)
          ? _selectedName!.trim()
          : fallbackLocationName,
      address: _selectedAddress?.trim(),
      latitude: _selectedPoint!.latitude,
      longitude: _selectedPoint!.longitude,
      placeId: _selectedPlaceId,
      locationProvider: _selectedProvider ?? 'MANUAL_PIN',
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final sheetHeight = mediaQuery.size.height * 0.90;

    final initialCenter = widget.initialCenter ??
        LatLng(MapConstants.fallbackLatitude, MapConstants.fallbackLongitude);
    final initialZoom = widget.initialCenter != null
        ? 15.0
        : MapConstants.fallbackZoom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutQuad,
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Indicator Handle
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

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 8, 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.map_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chọn vị trí trên bản đồ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Tìm kiếm hoặc chạm vào bản đồ để ghim vị trí',
                            style: TextStyle(
                              fontSize: 11,
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
                      onPressed: () => Navigator.of(context).pop(null),
                      tooltip: 'Đóng',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.hairlineSoft),

              // Map & Search Container (Stack)
              Expanded(
                child: Stack(
                  children: [
                    // 1. Interactive AppMapView
                    Positioned.fill(
                      child: AppMapView(
                        mapController: _mapController,
                        initialCenter: initialCenter,
                        initialZoom: initialZoom,
                        onTap: (_, point) => _handleMapTap(point),
                        onPositionChanged: (camera, hasGesture) {
                          if (hasGesture) _viewportCenter = camera.center;
                        },
                        markers: [
                          if (_selectedPoint != null)
                            MapMarkerBuilder.buildPinMarker(
                              point: _selectedPoint!,
                              color: AppColors.primary,
                              semanticLabel:
                                  _selectedName ?? fallbackLocationName,
                            ),
                        ],
                      ),
                    ),

                    // 2. Floating Search Bar & Results Dropdown
                    Positioned(
                      top: 10,
                      left: 14,
                      right: 14,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Search Input Card
                          Material(
                            elevation: 4,
                            shadowColor: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.surface,
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              decoration: InputDecoration(
                                hintText:
                                    'Tìm kiếm địa điểm (tối thiểu 2 ký tự)...',
                                hintStyle: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.muted,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                suffixIcon: _isSearching
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      )
                                    : (_searchController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.clear,
                                                size: 18,
                                                color: AppColors.textSecondary,
                                              ),
                                              onPressed: () {
                                                _searchController.clear();
                                                _onSearchChanged('');
                                              },
                                            )
                                          : null),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),

                          // Explicit Nearby search avoids requests while the map pans.
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children:
                                  [
                                        ('ALL', 'Gần đây'),
                                        ('ATTRACTION', 'Tham quan'),
                                        ('FOOD', 'Ăn uống'),
                                        ('CAFE', 'Cà phê'),
                                        ('STAY', 'Lưu trú'),
                                      ]
                                      .map(
                                        (item) => Padding(
                                          padding: const EdgeInsets.only(
                                            right: 6,
                                            top: 6,
                                          ),
                                          child: ActionChip(
                                            label: Text(
                                              item.$2,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                            backgroundColor:
                                                _nearbyCategory == item.$1
                                                ? AppColors.primaryLight
                                                : AppColors.surface,
                                            onPressed: () =>
                                                _searchNearby(item.$1),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),

                          // Search Results Dropdown List
                          if (_showSearchResults) ...[
                            const SizedBox(height: 6),
                            Material(
                              elevation: 6,
                              shadowColor: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                              color: AppColors.surface,
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 220,
                                ),
                                child: _isSearching && _searchResults.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: AppColors.primary,
                                                    ),
                                              ),
                                              SizedBox(width: 10),
                                              Text(
                                                'Đang tìm kiếm...',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : (_searchError != null &&
                                              _searchResults.isEmpty
                                          ? Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.info_outline,
                                                    size: 18,
                                                    color: AppColors.muted,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      _searchError!,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : ListView.separated(
                                              shrinkWrap: true,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 4,
                                                  ),
                                              itemCount: _searchResults.length,
                                              separatorBuilder: (_, _) =>
                                                  const Divider(
                                                    height: 1,
                                                    color:
                                                        AppColors.hairlineSoft,
                                                  ),
                                              itemBuilder: (context, index) {
                                                final item =
                                                    _searchResults[index];
                                                final isArea = item.isLocalityFallback || item.isCityOrAdministrative;
                                                return ListTile(
                                                  dense: true,
                                                  leading: Icon(
                                                    isArea
                                                        ? Icons.location_city_outlined
                                                        : Icons.place_outlined,
                                                    color: AppColors.primary,
                                                    size: 20,
                                                  ),
                                                  title: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          item.name,
                                                          style: const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                AppColors.textPrimary,
                                                          ),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      if (isArea) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.surfaceSoft,
                                                            borderRadius: BorderRadius.circular(4),
                                                            border: Border.all(
                                                              color: AppColors.hairlineSoft,
                                                              width: 0.5,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            item.isLocalityFallback ? 'Khu vực' : 'Địa danh',
                                                            style: const TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w500,
                                                              color: AppColors.textSecondary,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  subtitle:
                                                      item
                                                          .formattedAddress
                                                          .isNotEmpty
                                                      ? Text(
                                                          item.formattedAddress,
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            color: AppColors
                                                                .textSecondary,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        )
                                                      : null,
                                                  onTap: () =>
                                                      _selectSearchResult(item),
                                                );
                                              },
                                            )),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Selected Location Details Card
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.hairlineSoft),
                  ),
                ),
                child: _selectedPoint == null
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.hairlineSoft),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Chạm vào bản đồ để thả ghim hoặc tìm kiếm địa điểm',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _selectedName ?? fallbackLocationName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (_isReverseGeocoding) ...[
                                        const SizedBox(width: 6),
                                        const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ] else ...[
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: _editLocationName,
                                          child: const Icon(
                                            Icons.edit_outlined,
                                            size: 14,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedAddress ??
                                        'Tọa độ: ${_selectedPoint!.latitude.toStringAsFixed(5)}, ${_selectedPoint!.longitude.toStringAsFixed(5)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              // Bottom Action Buttons
              Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                color: AppColors.surface,
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
                        onPressed: () => Navigator.of(context).pop(null),
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
                        onPressed: _selectedPoint != null ? _confirm : null,
                        child: const Text(
                          'Xác nhận vị trí',
                          style: TextStyle(
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
