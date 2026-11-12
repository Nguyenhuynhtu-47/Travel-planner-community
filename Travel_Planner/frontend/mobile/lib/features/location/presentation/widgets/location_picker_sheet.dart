import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_map_view.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../itinerary/data/itinerary_crud_repository.dart';
import '../../../itinerary/presentation/widgets/activity_form_dialog.dart';
import '../../../itinerary/presentation/widgets/day_picker_bottom_sheet.dart';
import '../../../itinerary/presentation/widgets/itinerary_picker_bottom_sheet.dart';
import '../../data/location_repository.dart';
import '../../data/models/location_search_result.dart';

class SimpleTokenAuthNotifier extends AuthNotifier {
  final String _explicitToken;
  SimpleTokenAuthNotifier(this._explicitToken);
  @override
  String? get token => _explicitToken;
  @override
  bool get isAuthenticated => true;
}

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
  String? token,
  AuthNotifier? authNotifier,
  ItineraryCrudRepository? itineraryCrudRepository,
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
      token: token,
      authNotifier: authNotifier,
      itineraryCrudRepository: itineraryCrudRepository,
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
  final String? token;
  final AuthNotifier? authNotifier;
  final ItineraryCrudRepository? itineraryCrudRepository;

  const LocationPickerSheet({
    super.key,
    this.repository,
    this.initialCenter,
    this.initialName,
    this.initialAddress,
    this.initialPlaceId,
    this.initialProvider,
    this.token,
    this.authNotifier,
    this.itineraryCrudRepository,
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
    String? token,
    AuthNotifier? authNotifier,
    ItineraryCrudRepository? itineraryCrudRepository,
  }) => showLocationPickerSheet(
    context,
    repository: repository,
    initialCenter: initialCenter,
    initialName: initialName,
    initialAddress: initialAddress,
    initialPlaceId: initialPlaceId,
    initialProvider: initialProvider,
    token: token,
    authNotifier: authNotifier,
    itineraryCrudRepository: itineraryCrudRepository,
  );

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
  LocationSearchResult? _selectedSearchResult;
  bool _isReverseGeocoding = false;
  late final String _searchSessionId;

  static const String fallbackLocationName = 'Vị trí đã ghim';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocationRepository();
    _mapController = MapController();
    _searchController = TextEditingController();
    _searchSessionId = _newTomTomSessionId();

    if (widget.initialCenter != null) {
      _selectedPoint = widget.initialCenter;
      _selectedName = widget.initialName?.isNotEmpty == true
          ? widget.initialName
          : fallbackLocationName;
      _selectedAddress = widget.initialAddress;
      _selectedPlaceId = widget.initialPlaceId;
      _selectedProvider = widget.initialProvider ?? 'MANUAL_PIN';
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
          query,
          mode: 'SUGGEST',
          token: widget.token,
          sessionId: _searchSessionId,
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

  Future<void> _submitSearch(String text) async {
    final query = text.trim();
    if (query.length < 2) return;
    _debounceTimer?.cancel();
    final requestId = ++_searchRequestId;
    setState(() {
      _isSearching = true;
      _searchError = null;
      _showSearchResults = true;
    });
    try {
      final results = await _repository.searchLocations(
        query,
        mode: 'SEARCH',
        token: widget.token,
        sessionId: _searchSessionId,
      );
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isSearching = false;
        _searchResults = results;
        _searchError = results.isEmpty
            ? 'Không tìm thấy địa điểm phù hợp'
            : null;
      });
    } on ApiException catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _searchError = e.message;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _searchError = 'Không thể kết nối máy chủ tìm kiếm.';
      });
    }
  }

  String _newTomTomSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _selectSearchResult(LocationSearchResult result) async {
    FocusScope.of(context).unfocus();
    _debounceTimer?.cancel();
    final requestId = ++_searchRequestId;
    ++_reverseGeocodeRequestId;
    if (result.type == 'discoverAction' ||
        result.providerType == 'discoverAction') {
      setState(() {
        _isSearching = true;
        _searchError = null;
      });
      try {
        final results = await _repository.searchLocations(
          _searchController.text.trim(),
          mode: 'SEARCH',
          sessionId: result.sessionId ?? _searchSessionId,
          token: widget.token,
        );
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          _isSearching = false;
          _searchResults = results;
          _showSearchResults = true;
          _searchError = results.isEmpty
              ? 'Không tìm thấy địa điểm phù hợp'
              : null;
        });
      } on ApiException catch (e) {
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          _isSearching = false;
          _searchError = e.message;
        });
      }
      return;
    }
    if (result.requiresDetails &&
        result.provider == 'TOMTOM' &&
        result.providerId != null &&
        result.providerType != null) {
      setState(() {
        _isSearching = true;
        _searchError = null;
      });
      try {
        result =
            await _repository.resolveTomTomPlace(
              type: result.providerType!,
              id: result.providerId!,
              sessionId: result.sessionId ?? _searchSessionId,
              token: widget.token,
            ) ??
            result;
      } on ApiException catch (e) {
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          _isSearching = false;
          _searchError = e.message;
        });
        return;
      } catch (_) {
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          _isSearching = false;
          _searchError = 'Không thể lấy tọa độ địa điểm từ TomTom.';
        });
        return;
      }
      if (!mounted || requestId != _searchRequestId) return;
    }
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
        _selectedSearchResult = null;
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
      _selectedSearchResult = result;
      _selectedPoint = point;
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
      _selectedName = fallbackLocationName;
      _selectedAddress = null;
      _selectedPlaceId = null;
      _selectedProvider = 'MANUAL_PIN';
      _selectedSearchResult = null;
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

  Future<void> _handleScheduleActivity(LocationSearchResult location) async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng đăng nhập để lên lịch hoạt động vào chuyến đi',
          ),
        ),
      );
      return;
    }

    // Step 1: Pick Itinerary in scheduleActivity mode
    final selectedItinerary = await ItineraryPickerBottomSheet.showForSchedule(
      context,
      place: location,
      token: token,
      repository: widget.itineraryCrudRepository,
      authNotifier: widget.authNotifier,
    );

    if (selectedItinerary == null || !mounted) return;

    // Step 2: Pick Day in DayPickerBottomSheet
    final selectedDay = await DayPickerBottomSheet.show(
      context,
      itinerary: selectedItinerary,
      place: location,
      token: token,
      crudRepository: widget.itineraryCrudRepository,
    );

    if (selectedDay == null || !mounted) return;

    // Step 3: Open Activity Form with prefilled location snapshot
    final created = await showActivityFormBottomSheet(
      context,
      itineraryId: selectedItinerary.itineraryId,
      dayId: selectedDay.dayId,
      dayNumber: selectedDay.dayNumber,
      dayTitle: selectedDay.title,
      authNotifier: widget.authNotifier ?? SimpleTokenAuthNotifier(token),
      repository: widget.itineraryCrudRepository ?? ItineraryCrudRepository(),
      initialLocation: location,
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã thêm hoạt động vào Ngày ${selectedDay.dayNumber} của "${selectedItinerary.title}"!',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Widget _buildInfoNotice(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairlineSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveToItineraryAction() {
    final result = _selectedSearchResult;

    // Case 1: Administrative boundary -> cannot be saved or scheduled
    if (result != null && result.isAdministrativeArea) {
      return _buildInfoNotice(
        'Đây là ranh giới khu vực hành chính, không thể lưu vào lịch trình.',
      );
    }

    // Case 2: Internal Place -> both Save to Itinerary and Schedule as Activity are active
    if (result != null && result.isInternalPlace) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('save_to_itinerary_button'),
              icon: const Icon(Icons.bookmark_add_outlined, size: 16),
              label: const Text(
                'Lưu vào chuyến đi',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                if (widget.token == null || widget.token!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Vui lòng đăng nhập để lưu địa điểm vào chuyến đi',
                      ),
                    ),
                  );
                  return;
                }
                ItineraryPickerBottomSheet.show(
                  context,
                  place: result,
                  token: widget.token!,
                  repository: widget.itineraryCrudRepository,
                  authNotifier: widget.authNotifier,
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              key: const Key('schedule_activity_button'),
              icon: const Icon(Icons.calendar_month_outlined, size: 16),
              label: const Text(
                'Lên lịch vào ngày',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _handleScheduleActivity(result),
            ),
          ),
        ],
      );
    }

    // Case 3: External POI -> Schedule as Activity is active; Save to Itinerary has explanation
    if (result != null && result.isExternalPoi) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('schedule_activity_button'),
              icon: const Icon(Icons.calendar_month_outlined, size: 16),
              label: const Text(
                'Lên lịch vào ngày',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _handleScheduleActivity(result),
            ),
          ),
          const SizedBox(height: 6),
          _buildInfoNotice(
            'Địa điểm này chưa có trong danh mục địa điểm của Travel Planner. Bạn vẫn có thể lên lịch trực tiếp vào một ngày trong chuyến đi.',
          ),
        ],
      );
    }

    // Case 4: Manual Pin or custom pinned location
    if (_selectedPoint != null) {
      final manualLocation = _selectedSearchResult ??
          LocationSearchResult(
            placeId: _selectedPlaceId ?? '',
            name: _selectedName ?? fallbackLocationName,
            formattedAddress: _selectedAddress ?? '',
            provider: _selectedProvider ?? 'MANUAL_PIN',
            latitude: _selectedPoint!.latitude,
            longitude: _selectedPoint!.longitude,
          );

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('schedule_activity_button'),
              icon: const Icon(Icons.calendar_month_outlined, size: 16),
              label: const Text(
                'Lên lịch vào ngày',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _handleScheduleActivity(manualLocation),
            ),
          ),
          const SizedBox(height: 6),
          _buildInfoNotice(
            'Vị trí ghim thủ công chưa có trong danh mục địa điểm.',
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final sheetHeight = mediaQuery.size.height * 0.90;

    final initialCenter =
        widget.initialCenter ??
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
                              onSubmitted: _submitSearch,
                              textInputAction: TextInputAction.search,
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
                                                final isArea =
                                                    item.isLocalityFallback ||
                                                    item.isCityOrAdministrative;
                                                return ListTile(
                                                  dense: true,
                                                  leading: Icon(
                                                    isArea
                                                        ? Icons
                                                              .location_city_outlined
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
                                                            color: AppColors
                                                                .textPrimary,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      if (isArea) ...[
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: AppColors
                                                                .surfaceSoft,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                            border: Border.all(
                                                              color: AppColors
                                                                  .hairlineSoft,
                                                              width: 0.5,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            item.isLocalityFallback
                                                                ? 'Khu vực'
                                                                : 'Địa danh',
                                                            style: const TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: AppColors
                                                                  .textSecondary,
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
                                                  trailing: item.isInternalPlace
                                                      ? IconButton(
                                                          key: Key(
                                                            'save_result_${item.placeId}',
                                                          ),
                                                          icon: const Icon(
                                                            Icons
                                                                .bookmark_add_outlined,
                                                            color: AppColors
                                                                .primary,
                                                            size: 20,
                                                          ),
                                                          tooltip:
                                                              'Lưu vào chuyến đi',
                                                          onPressed: () {
                                                            if (widget.token ==
                                                                    null ||
                                                                widget.token!
                                                                    .isEmpty) {
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                const SnackBar(
                                                                  content: Text(
                                                                    'Vui lòng đăng nhập để lưu địa điểm vào chuyến đi',
                                                                  ),
                                                                ),
                                                              );
                                                              return;
                                                            }
                                                            ItineraryPickerBottomSheet.show(
                                                              context,
                                                              place: item,
                                                              token:
                                                                  widget.token!,
                                                            );
                                                          },
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
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
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _selectedName ??
                                                  fallbackLocationName,
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
                            const SizedBox(height: 8),
                            _buildSaveToItineraryAction(),
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
