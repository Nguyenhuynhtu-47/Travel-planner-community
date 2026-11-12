import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../explore/data/models/itinerary_summary.dart';
import '../../../location/data/models/location_search_result.dart';
import '../../data/itinerary_crud_repository.dart';
import '../screens/create_itinerary_screen.dart';

/// Selection mode for [ItineraryPickerBottomSheet].
enum ItineraryPickerMode {
  /// Flow A: Saves a canonical Place directly into `itinerary_places`.
  savePlace,

  /// Flow B: Selects an owned active itinerary to pick a day and schedule an Activity.
  scheduleActivity,
}

/// Modal bottom sheet allowing users to pick one of their owned active itineraries
/// to save a canonical Place into (Flow A) or schedule an Activity within (Flow B).
class ItineraryPickerBottomSheet extends StatefulWidget {
  final LocationSearchResult place;
  final String token;
  final ItineraryCrudRepository? repository;
  final ValueChanged<int>? onSaved;
  final AuthNotifier? authNotifier;
  final VoidCallback? onCreateItinerary;
  final ItineraryPickerMode mode;
  final ValueChanged<ItinerarySummary>? onItinerarySelected;

  const ItineraryPickerBottomSheet({
    super.key,
    required this.place,
    required this.token,
    this.repository,
    this.onSaved,
    this.authNotifier,
    this.onCreateItinerary,
    this.mode = ItineraryPickerMode.savePlace,
    this.onItinerarySelected,
  });

  /// Opens the [ItineraryPickerBottomSheet] in savePlace mode (Flow A).
  static Future<bool?> show(
    BuildContext context, {
    required LocationSearchResult place,
    required String token,
    ItineraryCrudRepository? repository,
    ValueChanged<int>? onSaved,
    AuthNotifier? authNotifier,
    VoidCallback? onCreateItinerary,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => ItineraryPickerBottomSheet(
        place: place,
        token: token,
        repository: repository,
        onSaved: onSaved,
        authNotifier: authNotifier,
        onCreateItinerary: onCreateItinerary,
        mode: ItineraryPickerMode.savePlace,
      ),
    );
  }

  /// Opens the [ItineraryPickerBottomSheet] in scheduleActivity mode (Flow B),
  /// returning the chosen [ItinerarySummary].
  static Future<ItinerarySummary?> showForSchedule(
    BuildContext context, {
    required LocationSearchResult place,
    required String token,
    ItineraryCrudRepository? repository,
    AuthNotifier? authNotifier,
    VoidCallback? onCreateItinerary,
    ValueChanged<ItinerarySummary>? onItinerarySelected,
  }) {
    return showModalBottomSheet<ItinerarySummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => ItineraryPickerBottomSheet(
        place: place,
        token: token,
        repository: repository,
        authNotifier: authNotifier,
        onCreateItinerary: onCreateItinerary,
        mode: ItineraryPickerMode.scheduleActivity,
        onItinerarySelected: onItinerarySelected,
      ),
    );
  }

  @override
  State<ItineraryPickerBottomSheet> createState() =>
      _ItineraryPickerBottomSheetState();
}

class _ItineraryPickerBottomSheetState
    extends State<ItineraryPickerBottomSheet> {
  late final ItineraryCrudRepository _repository;
  final ScrollController _scrollController = ScrollController();

  List<ItinerarySummary> _itineraries = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  int _currentPage = 0;
  bool _hasMore = false;
  static const int _pageSize = 20;

  int? _savingItineraryId;
  final Set<int> _savedItineraryIds = {};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ItineraryCrudRepository();
    _scrollController.addListener(_onScroll);
    _loadItineraries(isRefresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadItineraries(isRefresh: false);
      }
    }
  }

  Future<void> _loadItineraries({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 0;
        _hasMore = false;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    final pageToFetch = isRefresh ? 0 : _currentPage;

    try {
      final result = await _repository.getMyItineraries(
        token: widget.token,
        status: 'ACTIVE',
        page: pageToFetch,
        size: _pageSize,
        sort: 'updatedAt,desc',
      );

      if (!mounted) return;

      setState(() {
        if (isRefresh) {
          _itineraries = List.from(result.content);
        } else {
          _itineraries.addAll(result.content);
        }
        _hasMore = result.hasMore;
        _currentPage = result.pageNumber + 1;
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        if (isRefresh) {
          _errorMessage = e.message.isNotEmpty
              ? e.message
              : 'Không thể tải danh sách chuyến đi của bạn.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        if (isRefresh) {
          _errorMessage = 'Lỗi kết nối máy chủ. Vui lòng thử lại sau.';
        }
      });
    }
  }

  Future<void> _handleSaveToItinerary(ItinerarySummary itinerary) async {
    final targetPlaceId = widget.place.internalPlaceId;
    if (targetPlaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Địa điểm không hợp lệ để lưu vào lịch trình.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Prevent duplicate multi-tap submissions
    if (_savingItineraryId != null ||
        _savedItineraryIds.contains(itinerary.itineraryId)) {
      return;
    }

    setState(() {
      _savingItineraryId = itinerary.itineraryId;
    });

    try {
      await _repository.savePlaceToItinerary(
        itinerary.itineraryId,
        targetPlaceId,
        token: widget.token,
      );

      if (!mounted) return;

      setState(() {
        _savingItineraryId = null;
        _savedItineraryIds.add(itinerary.itineraryId);
      });

      widget.onSaved?.call(itinerary.itineraryId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đã lưu "${widget.place.name}" vào "${itinerary.title}"!',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 3),
        ),
      );

      // Smooth dismiss
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _savingItineraryId = null;
      });

      if (e.statusCode == 409) {
        // Handle duplicate gracefully: mark as saved and inform the user without crashing
        setState(() {
          _savedItineraryIds.add(itinerary.itineraryId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Địa điểm này đã được lưu trong lịch trình "${itinerary.title}".',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.textPrimary,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (e.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
            backgroundColor: AppColors.error,
          ),
        );
      } else if (e.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn không có quyền chỉnh sửa lịch trình này.'),
            backgroundColor: AppColors.error,
          ),
        );
      } else if (e.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lịch trình hoặc địa điểm không tồn tại.'),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message.isNotEmpty ? e.message : 'Lỗi khi lưu địa điểm.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savingItineraryId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi kết nối máy chủ. Vui lòng kiểm tra mạng.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _handleSelectForSchedule(ItinerarySummary item) {
    if (item.totalDays == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lịch trình này chưa có ngày nào. Vui lòng mở chi tiết lịch trình để thêm ngày trước.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    widget.onItinerarySelected?.call(item);
    Navigator.of(context).pop(item);
  }

  void _navigateToCreateItinerary() {
    Navigator.of(context).pop();
    if (widget.onCreateItinerary != null) {
      widget.onCreateItinerary!();
      return;
    }
    if (widget.authNotifier != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CreateItineraryScreen(
            authNotifier: widget.authNotifier!,
            repository: _repository,
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vui lòng tạo lịch trình mới từ thanh điều hướng bên dưới.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;

    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

            // Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
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
                      Icons.bookmark_add_outlined,
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
                          widget.mode == ItineraryPickerMode.scheduleActivity
                              ? 'Lên lịch vào chuyến đi'
                              : 'Lưu vào chuyến đi',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.place.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
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
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.hairlineSoft),

            // Content Body
            Flexible(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_errorMessage != null && _itineraries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 40,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _loadItineraries(isRefresh: true),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_itineraries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.luggage_outlined,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Bạn chưa có lịch trình nào',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hãy tạo một lịch trình để bắt đầu lưu các địa điểm yêu thích!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _navigateToCreateItinerary,
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Tạo lịch trình mới',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _itineraries.length + (_hasMore ? 1 : 0),
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: AppColors.hairlineSoft),
      itemBuilder: (context, index) {
        if (index >= _itineraries.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        }

        final item = _itineraries[index];
        final isSaving = _savingItineraryId == item.itineraryId;
        final isSaved = _savedItineraryIds.contains(item.itineraryId);
        final isScheduleMode =
            widget.mode == ItineraryPickerMode.scheduleActivity;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 6,
            horizontal: 4,
          ),
          onTap: isScheduleMode ? () => _handleSelectForSchedule(item) : null,
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.hairlineSoft),
            ),
            clipBehavior: Clip.antiAlias,
            child: item.coverImage != null && item.coverImage!.isNotEmpty
                ? Image.network(
                    item.coverImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(
                          Icons.landscape_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                  )
                : const Icon(
                    Icons.landscape_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
          ),
          title: Text(
            item.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Row(
                children: [
                  if (item.location.isNotEmpty) ...[
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        item.location,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('•', style: TextStyle(color: AppColors.muted)),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    '${item.totalDays} ngày',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Builder(
                    builder: (context) {
                      final isPublic =
                          item.visibility?.toUpperCase() == 'PUBLIC';
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isPublic
                              ? AppColors.primaryLight
                              : AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPublic ? 'Công khai' : 'Riêng tư',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isPublic
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          trailing: isScheduleMode
              ? FilledButton.tonal(
                  key: Key('select_itinerary_${item.itineraryId}'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _handleSelectForSchedule(item),
                  child: const Text(
                    'Chọn',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : isSaving
                  ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : isSaved
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Đã lưu',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _savingItineraryId != null
                          ? null
                          : () => _handleSaveToItinerary(item),
                      child: const Text(
                        'Lưu',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
        );
      },
    );
  }
}
