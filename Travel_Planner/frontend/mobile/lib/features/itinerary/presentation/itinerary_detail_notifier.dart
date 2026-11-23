import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../explore/data/models/itinerary_summary.dart';
import '../data/itinerary_crud_repository.dart';
import '../data/itinerary_repository.dart';
import '../data/models/itinerary_detail.dart';
import '../data/models/itinerary_place.dart';

class ItineraryDetailNotifier extends ChangeNotifier {
  final int itineraryId;
  final ItineraryRepository _repository;
  final ItineraryCrudRepository? crudRepository;

  ItinerarySummary? initialSummary;
  ItineraryDetail? itineraryDetail;
  bool isLoading;
  String? errorMessage;
  int? errorStatusCode;

  List<ItineraryPlace> savedPlaces = [];
  bool isLoadingSavedPlaces = false;
  String? savedPlacesError;

  ItineraryDetailNotifier({
    required this.itineraryId,
    this.initialSummary,
    ItineraryDetail? initialDetail,
    bool? initialIsFavorited,
    bool? initialIsSaved,
    ItineraryRepository? repository,
    this.crudRepository,
    List<ItineraryPlace>? initialSavedPlaces,
  }) : itineraryDetail =
           initialDetail ??
           (initialSummary != null
               ? ItineraryDetail(
                   itineraryId: initialSummary.itineraryId != 0
                       ? initialSummary.itineraryId
                       : itineraryId,
                   title: initialSummary.title,
                   description: initialSummary.description,
                   location: initialSummary.location,
                   coverImage: initialSummary.coverImage,
                   totalDays: initialSummary.totalDays,
                   budget: initialSummary.budget,
                   theme: initialSummary.theme,
                   viewCount: initialSummary.viewCount,
                   favoriteCount: initialSummary.favoriteCount,
                   ratingCount: initialSummary.ratingCount,
                   averageRating: initialSummary.averageRating,
                   visibility: initialSummary.visibility ?? 'PUBLIC',
                   status: initialSummary.status ?? 'ACTIVE',
                   createdAt: initialSummary.createdAt,
                   creator: initialSummary.creator,
                   days: const [],
                   isFavorited: initialIsFavorited ?? false,
                   isSaved: initialIsSaved ?? false,
                 )
               : null),
       isLoading = initialDetail == null,
       savedPlaces = initialSavedPlaces != null
           ? List<ItineraryPlace>.from(initialSavedPlaces)
           : [],
       _repository = repository ?? ItineraryRepository();

  bool get isSuccess => itineraryDetail != null;
  bool get isError => errorMessage != null && itineraryDetail == null;
  bool get isNotFound => errorStatusCode == 404;
  bool get isUnauthorized => errorStatusCode == 401 || errorStatusCode == 403;
  bool get isNetworkError => errorStatusCode == 0;

  void updateSavedPlaces(List<ItineraryPlace> places) {
    savedPlaces = places;
    savedPlacesError = null;
    isLoadingSavedPlaces = false;
    notifyListeners();
  }

  void setSavedPlacesError(String error) {
    savedPlacesError = error;
    isLoadingSavedPlaces = false;
    notifyListeners();
  }

  void removeSavedPlace(int placeId) {
    savedPlaces = savedPlaces.where((p) => p.place.placeId != placeId).toList();
    notifyListeners();
  }

  void addSavedPlace(ItineraryPlace place) {
    if (!savedPlaces.any((p) => p.place.placeId == place.place.placeId)) {
      savedPlaces = [...savedPlaces, place];
      notifyListeners();
    }
  }

  Future<void> loadSavedPlaces({
    String? token,
    ItineraryCrudRepository? repository,
  }) async {
    final repo = repository ?? crudRepository;
    if (repo == null) return;
    isLoadingSavedPlaces = true;
    savedPlacesError = null;
    notifyListeners();

    try {
      final places = await repo.getSavedPlaces(itineraryId, token: token);
      savedPlaces = places;
      savedPlacesError = null;
    } catch (e) {
      savedPlacesError = e is ApiException
          ? e.message
          : 'Không thể tải danh sách địa điểm đã lưu.';
    } finally {
      isLoadingSavedPlaces = false;
      notifyListeners();
    }
  }

  Future<void> loadDetail({String? token}) async {
    isLoading = true;
    if (itineraryDetail == null) {
      errorMessage = null;
      errorStatusCode = null;
    }
    notifyListeners();

    try {
      final detail = await _repository.getItineraryDetail(
        itineraryId,
        token: token,
      );
      itineraryDetail = detail;
      errorMessage = null;
      errorStatusCode = null;
    } on ApiException catch (e) {
      errorMessage = e.message;
      errorStatusCode = e.statusCode;
    } catch (_) {
      errorMessage = 'Không thể tải chi tiết lịch trình. Vui lòng thử lại sau.';
      errorStatusCode = null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void retry({String? token}) {
    loadDetail(token: token);
  }

  Future<bool> updateActivityVisitedStatus({
    required int dayId,
    required int activityId,
    required bool visited,
    required String token,
    ItineraryCrudRepository? repository,
  }) async {
    final previousDetail = itineraryDetail;
    final updateRepository = repository ?? crudRepository;
    if (previousDetail == null || updateRepository == null) return false;

    itineraryDetail = previousDetail.copyWith(
      days: previousDetail.days
          .map((day) {
            if (day.dayId != dayId) return day;
            return day.copyWith(
              activities: day.activities
                  .map((activity) {
                    return activity.activityId == activityId
                        ? activity.copyWith(visited: visited)
                        : activity;
                  })
                  .toList(growable: false),
            );
          })
          .toList(growable: false),
    );
    notifyListeners();

    try {
      await updateRepository.updateActivityVisitStatus(
        itineraryId: itineraryId,
        dayId: dayId,
        activityId: activityId,
        visited: visited,
        token: token,
      );
      return true;
    } catch (_) {
      itineraryDetail = previousDetail;
      notifyListeners();
      return false;
    }
  }
}
