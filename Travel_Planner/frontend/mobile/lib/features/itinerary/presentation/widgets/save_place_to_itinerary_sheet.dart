import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../explore/data/models/itinerary_summary.dart';
import '../../data/itinerary_crud_repository.dart';

/// Opens modal bottom sheet to save a place (from another user's itinerary or activity)
/// into one of the current user's own itineraries.
Future<bool?> showSavePlaceToItinerarySheet(
  BuildContext context, {
  required AuthNotifier authNotifier,
  required ItineraryCrudRepository repository,
  required String locationName,
  String? address,
  double? latitude,
  double? longitude,
  int? canonicalPlaceId,
  String? category,
  String? imageUrl,
  List<ItinerarySummary>? availableItineraries,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SavePlaceToItinerarySheet(
      authNotifier: authNotifier,
      repository: repository,
      locationName: locationName,
      address: address,
      latitude: latitude,
      longitude: longitude,
      canonicalPlaceId: canonicalPlaceId,
      category: category,
      imageUrl: imageUrl,
      availableItineraries: availableItineraries,
    ),
  );
}

class SavePlaceToItinerarySheet extends StatefulWidget {
  final AuthNotifier authNotifier;
  final ItineraryCrudRepository repository;
  final String locationName;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int? canonicalPlaceId;
  final String? category;
  final String? imageUrl;
  final List<ItinerarySummary>? availableItineraries;

  const SavePlaceToItinerarySheet({
    super.key,
    required this.authNotifier,
    required this.repository,
    required this.locationName,
    this.address,
    this.latitude,
    this.longitude,
    this.canonicalPlaceId,
    this.category,
    this.imageUrl,
    this.availableItineraries,
  });

  @override
  State<SavePlaceToItinerarySheet> createState() =>
      _SavePlaceToItinerarySheetState();
}

class _SavePlaceToItinerarySheetState extends State<SavePlaceToItinerarySheet> {
  List<ItinerarySummary> _myItineraries = [];
  bool _isLoadingItineraries = false;
  String? _loadError;
  int? _savingItineraryId;
  final Set<int> _savedItineraryIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.availableItineraries != null &&
        widget.availableItineraries!.isNotEmpty) {
      _myItineraries = widget.availableItineraries!;
    } else {
      _loadMyItineraries();
    }
  }

  Future<void> _loadMyItineraries() async {
    setState(() {
      _isLoadingItineraries = true;
      _loadError = null;
    });

    try {
      final page = await widget.repository.getMyItineraries(
        page: 0,
        size: 50,
        token: widget.authNotifier.token,
      );
      if (mounted) {
        setState(() {
          _myItineraries = page.content;
          _isLoadingItineraries = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.message;
          _isLoadingItineraries = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError = 'Không thể tải danh sách lịch trình của bạn.';
          _isLoadingItineraries = false;
        });
      }
    }
  }

  Future<void> _saveToItinerary(ItinerarySummary itinerary) async {
    if (_savingItineraryId != null) return;

    final token = widget.authNotifier.token;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để lưu địa điểm.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _savingItineraryId = itinerary.itineraryId);

    try {
      int effectivePlaceId;

      if (widget.canonicalPlaceId != null) {
        effectivePlaceId = widget.canonicalPlaceId!;
      } else {
        // Canonicalize snapshot / custom location via backend catalog resolve endpoint
        final resolved = await widget.repository.resolvePlace(
          name: widget.locationName,
          address: widget.address,
          latitude: widget.latitude ?? 0.0,
          longitude: widget.longitude ?? 0.0,
          token: token,
        );
        effectivePlaceId = (resolved['placeId'] as num).toInt();
      }

      await widget.repository.savePlaceToItinerary(
        itinerary.itineraryId,
        effectivePlaceId,
        token: token,
      );

      if (!mounted) return;

      setState(() {
        _savedItineraryIds.add(itinerary.itineraryId);
        _savingItineraryId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã lưu "${widget.locationName}" vào lịch trình "${itinerary.title}"',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _savingItineraryId = null);

      if (e.statusCode == 409 ||
          e.message.contains('đã được lưu') ||
          e.message.contains('tồn tại')) {
        setState(() => _savedItineraryIds.add(itinerary.itineraryId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Địa điểm này đã có trong lịch trình "${itinerary.title}"',
            ),
            backgroundColor: AppColors.info,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingItineraryId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lưu địa điểm. Vui lòng thử lại.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.bookmark_add_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Lưu địa điểm vào lịch trình',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () =>
                      Navigator.of(context).pop(_savedItineraryIds.isNotEmpty),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.hairline),

          // Place Preview Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: widget.imageUrl != null &&
                            widget.imageUrl!.isNotEmpty
                        ? Image.network(
                            widget.imageUrl!,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildPlaceholderIcon(),
                          )
                        : _buildPlaceholderIcon(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.locationName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.category != null) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.category!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                        if (widget.address != null &&
                            widget.address!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.address!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Subtitle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Chọn lịch trình của bạn để lưu:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_isLoadingItineraries)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),

          // Itineraries List
          Expanded(
            child: _buildItinerariesContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      width: 52,
      height: 52,
      color: AppColors.primaryLight.withValues(alpha: 0.4),
      child: const Icon(
        Icons.place_rounded,
        color: AppColors.primary,
        size: 26,
      ),
    );
  }

  Widget _buildItinerariesContent() {
    if (_isLoadingItineraries && _myItineraries.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_loadError != null && _myItineraries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                style: const TextStyle(fontSize: 13, color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _loadMyItineraries,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_myItineraries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.luggage_outlined,
                size: 48,
                color: AppColors.muted.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bạn chưa có lịch trình nào',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Hãy tạo lịch trình mới để lưu các địa điểm yêu thích.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _myItineraries.length,
      separatorBuilder: (context, index) => const Divider(height: 8, color: Colors.transparent),
      itemBuilder: (context, index) {
        final it = _myItineraries[index];
        final isSaved = _savedItineraryIds.contains(it.itineraryId);
        final isSaving = _savingItineraryId == it.itineraryId;

        return Container(
          decoration: BoxDecoration(
            color: isSaved
                ? const Color(0xFFF0FDF4)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSaved
                  ? const Color(0xFFBBF7D0)
                  : AppColors.hairline,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: ListTile(
              onTap: isSaved || isSaving ? null : () => _saveToItinerary(it),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSaved
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.primaryLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSaved ? Icons.bookmark_added : Icons.map_outlined,
                color: isSaved ? AppColors.success : AppColors.primary,
                size: 20,
              ),
            ),
            title: Text(
              it.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${it.location} • ${it.totalDays} ngày',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            trailing: isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : isSaved
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 18,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Đã lưu',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      )
                    : FilledButton.tonal(
                        onPressed: () => _saveToItinerary(it),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Lưu'),
                      ),
            ),
          ),
        );
      },
    );
  }
}
