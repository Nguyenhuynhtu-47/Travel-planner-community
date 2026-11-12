import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../explore/data/models/itinerary_summary.dart';
import '../../../location/data/location_repository.dart';
import '../../../location/presentation/widgets/location_picker_sheet.dart';
import '../../data/itinerary_crud_repository.dart';
import '../../data/models/itinerary_place.dart';

/// Opens modal bottom sheet to add places to an itinerary via:
/// 1. Picking places from another itinerary.
/// 2. Searching/picking a new location and canonicalizing it.
Future<bool?> showAddPlaceToItinerarySheet(
  BuildContext context, {
  required AuthNotifier authNotifier,
  required ItineraryCrudRepository repository,
  LocationRepository? locationRepository,
  ItinerarySummary? initialItinerary,
  List<ItinerarySummary>? availableItineraries,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => AddPlaceToItinerarySheet(
      authNotifier: authNotifier,
      repository: repository,
      locationRepository: locationRepository,
      initialItinerary: initialItinerary,
      availableItineraries: availableItineraries,
    ),
  );
}

class AddPlaceToItinerarySheet extends StatefulWidget {
  final AuthNotifier authNotifier;
  final ItineraryCrudRepository repository;
  final LocationRepository? locationRepository;
  final ItinerarySummary? initialItinerary;
  final List<ItinerarySummary>? availableItineraries;

  const AddPlaceToItinerarySheet({
    super.key,
    required this.authNotifier,
    required this.repository,
    this.locationRepository,
    this.initialItinerary,
    this.availableItineraries,
  });

  @override
  State<AddPlaceToItinerarySheet> createState() =>
      _AddPlaceToItinerarySheetState();
}

class _AddPlaceToItinerarySheetState extends State<AddPlaceToItinerarySheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ItinerarySummary? _selectedTargetItinerary;
  List<ItinerarySummary> _itineraries = [];
  bool _isLoadingItineraries = false;

  // Way 1: Pick from another itinerary
  ItinerarySummary? _selectedSourceItinerary;
  List<ItineraryPlace> _sourcePlaces = [];
  Set<int> _alreadySavedPlaceIds = {};
  final Set<int> _selectedPlaceIds = {};
  bool _isLoadingSourcePlaces = false;
  bool _isSavingFromItinerary = false;

  // Way 2: Search new place state
  bool _isResolvingAndSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedTargetItinerary = widget.initialItinerary;

    if (widget.availableItineraries != null &&
        widget.availableItineraries!.isNotEmpty) {
      _itineraries = widget.availableItineraries!;
      if (_selectedTargetItinerary == null && _itineraries.isNotEmpty) {
        _selectedTargetItinerary = _itineraries.first;
      }
      _loadTargetSavedPlaceIds();
    } else {
      _loadUserItineraries();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserItineraries() async {
    setState(() => _isLoadingItineraries = true);
    try {
      final page = await widget.repository.getMyItineraries(
        page: 0,
        size: 50,
        token: widget.authNotifier.token,
      );
      if (mounted) {
        setState(() {
          _itineraries = page.content;
          if (_selectedTargetItinerary == null && _itineraries.isNotEmpty) {
            _selectedTargetItinerary = _itineraries.first;
          }
          _isLoadingItineraries = false;
        });
        _loadTargetSavedPlaceIds();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingItineraries = false);
    }
  }

  Future<void> _loadTargetSavedPlaceIds() async {
    if (_selectedTargetItinerary == null) return;
    try {
      final saved = await widget.repository.getSavedPlaces(
        _selectedTargetItinerary!.itineraryId,
        token: widget.authNotifier.token,
      );
      if (mounted) {
        setState(() {
          _alreadySavedPlaceIds = saved.map((p) => p.place.placeId).toSet();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSourcePlaces(ItinerarySummary source) async {
    setState(() {
      _selectedSourceItinerary = source;
      _isLoadingSourcePlaces = true;
      _selectedPlaceIds.clear();
    });

    try {
      final places = await widget.repository.getSavedPlaces(
        source.itineraryId,
        token: widget.authNotifier.token,
      );
      if (mounted) {
        setState(() {
          _sourcePlaces = places;
          _isLoadingSourcePlaces = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSourcePlaces = false);
    }
  }

  Future<void> _saveSelectedPlacesFromItinerary() async {
    if (_selectedTargetItinerary == null || _selectedPlaceIds.isEmpty) return;
    final token = widget.authNotifier.token;
    if (token == null) return;

    setState(() => _isSavingFromItinerary = true);
    int addedCount = 0;

    for (final placeId in _selectedPlaceIds) {
      if (_alreadySavedPlaceIds.contains(placeId)) continue;
      try {
        await widget.repository.savePlaceToItinerary(
          _selectedTargetItinerary!.itineraryId,
          placeId,
          token: token,
        );
        addedCount++;
      } on ApiException catch (e) {
        // If duplicate (409), treat as already added without crashing
        if (e.statusCode == 409) {
          addedCount++;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _isSavingFromItinerary = false);
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm $addedCount địa điểm vào lịch trình ${_selectedTargetItinerary!.title}'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _searchAndSaveNewPlace() async {
    if (_selectedTargetItinerary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn lịch trình trước khi thêm địa điểm')),
      );
      return;
    }

    final token = widget.authNotifier.token;
    if (token == null) return;

    final pickedLocation = await showLocationPickerSheet(
      context,
      repository: widget.locationRepository,
      token: token,
    );

    if (pickedLocation == null || !mounted) return;

    setState(() => _isResolvingAndSaving = true);

    try {
      // Resolve and canonicalize into Place catalog
      final resolved = await widget.repository.resolvePlace(
        provider: pickedLocation.locationProvider ?? 'MANUAL_PIN',
        providerPlaceId: (pickedLocation.placeId != null &&
                pickedLocation.placeId!.isNotEmpty)
            ? pickedLocation.placeId
            : null,
        name: pickedLocation.locationName.isNotEmpty
            ? pickedLocation.locationName
            : 'Địa điểm mới',
        address: pickedLocation.address,
        latitude: pickedLocation.latitude,
        longitude: pickedLocation.longitude,
        token: token,
      );
      final canonicalPlaceId = resolved['placeId'] is int
          ? resolved['placeId'] as int
          : int.parse('${resolved['placeId']}');

      // Link to destination itinerary
      await widget.repository.savePlaceToItinerary(
        _selectedTargetItinerary!.itineraryId,
        canonicalPlaceId,
        token: token,
      );

      if (mounted) {
        setState(() => _isResolvingAndSaving = false);
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã lưu "${pickedLocation.locationName}" vào lịch trình ${_selectedTargetItinerary!.title}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isResolvingAndSaving = false);
        final msg = e.statusCode == 409
            ? 'Địa điểm này đã có trong lịch trình'
            : e.message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isResolvingAndSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể lưu địa điểm. Vui lòng thử lại.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        margin: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.bookmark_add_outlined, color: AppColors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Thêm địa điểm vào lịch trình',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Destination Itinerary Selector Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                const Text(
                  'Lịch trình nhận:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _isLoadingItineraries
                      ? const SizedBox(
                          height: 20,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.hairline),
                            borderRadius: BorderRadius.circular(8),
                            color: AppColors.surfaceSoft,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedTargetItinerary?.itineraryId,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, size: 20),
                              hint: const Text('Chọn lịch trình', style: TextStyle(fontSize: 13)),
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                              items: _itineraries.map((it) {
                                return DropdownMenuItem<int>(
                                  value: it.itineraryId,
                                  child: Text(
                                    it.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  final selected = _itineraries.firstWhere((it) => it.itineraryId == val);
                                  setState(() {
                                    _selectedTargetItinerary = selected;
                                  });
                                  _loadTargetSavedPlaceIds();
                                }
                              },
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Tab Bar: 2 Options
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: const [
              Tab(
                icon: Icon(Icons.copy_rounded, size: 18),
                text: 'Từ lịch trình khác',
              ),
              Tab(
                icon: Icon(Icons.search_rounded, size: 18),
                text: 'Tìm địa điểm mới',
              ),
            ],
          ),
          const Divider(height: 1, color: AppColors.hairlineSoft),

          // Tab Content
          Flexible(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Way 1: Pick from another itinerary
                _buildPickFromOtherItineraryTab(),

                // Way 2: Search new place
                _buildSearchNewPlaceTab(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildPickFromOtherItineraryTab() {
    final otherItineraries = _itineraries
        .where((it) => it.itineraryId != _selectedTargetItinerary?.itineraryId)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Select source itinerary dropdown
          const Text(
            'Chọn lịch trình nguồn có sẵn địa điểm:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          if (otherItineraries.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.muted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bạn chưa có lịch trình nào khác để chọn địa điểm. Hãy thử tìm kiếm địa điểm mới!',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.hairline),
                borderRadius: BorderRadius.circular(10),
                color: AppColors.surfaceSoft,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  key: const Key('dropdown_source_itinerary'),
                  value: _selectedSourceItinerary?.itineraryId,
                  isExpanded: true,
                  hint: const Text('Chọn một lịch trình nguồn...', style: TextStyle(fontSize: 13)),
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  items: otherItineraries.map((it) {
                    return DropdownMenuItem<int>(
                      value: it.itineraryId,
                      child: Text(
                        '${it.title} (${it.totalDays} ngày)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final selected = otherItineraries.firstWhere((it) => it.itineraryId == val);
                      _loadSourcePlaces(selected);
                    }
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Source places list with checkboxes
          Expanded(
            child: _isLoadingSourcePlaces
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _selectedSourceItinerary == null
                    ? const Center(
                        child: Text(
                          'Vui lòng chọn lịch trình nguồn ở trên để xem danh sách địa điểm',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      )
                    : _sourcePlaces.isEmpty
                        ? const Center(
                            child: Text(
                              'Lịch trình này chưa lưu địa điểm nào',
                              style: TextStyle(fontSize: 13, color: AppColors.muted),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _sourcePlaces.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.hairlineSoft),
                            itemBuilder: (context, index) {
                              final item = _sourcePlaces[index];
                              final placeId = item.place.placeId;
                              final alreadySaved = _alreadySavedPlaceIds.contains(placeId);
                              final isSelected = _selectedPlaceIds.contains(placeId);

                              return CheckboxListTile(
                                value: alreadySaved ? true : isSelected,
                                onChanged: alreadySaved
                                    ? null
                                    : (checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _selectedPlaceIds.add(placeId);
                                          } else {
                                            _selectedPlaceIds.remove(placeId);
                                          }
                                        });
                                      },
                                activeColor: alreadySaved ? AppColors.muted : AppColors.primary,
                                title: Text(
                                  item.place.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: alreadySaved ? AppColors.muted : AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item.place.address != null && item.place.address!.isNotEmpty)
                                      Text(
                                        item.place.address!,
                                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (alreadySaved)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Text(
                                          '✓ Đã có trong lịch trình nhận',
                                          style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),

          // Confirm button
          if (_sourcePlaces.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isSavingFromItinerary
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_rounded),
                label: Text(
                  _isSavingFromItinerary
                      ? 'Đang thêm...'
                      : 'Thêm ${_selectedPlaceIds.length} địa điểm vào lịch trình',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: (_isSavingFromItinerary || _selectedPlaceIds.isEmpty)
                    ? null
                    : _saveSelectedPlacesFromItinerary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchNewPlaceTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_location_alt_outlined, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tìm kiếm địa điểm mới trên bản đồ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tìm địa danh, quán ăn, khách sạn hoặc điểm tham quan bất kỳ để lưu vào lịch trình.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isResolvingAndSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search_rounded),
              label: Text(
                _isResolvingAndSaving
                    ? 'Đang lưu vào lịch trình...'
                    : 'Mở tìm kiếm địa điểm',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isResolvingAndSaving ? null : _searchAndSaveNewPlace,
            ),
          ),
        ],
      ),
    );
  }
}
