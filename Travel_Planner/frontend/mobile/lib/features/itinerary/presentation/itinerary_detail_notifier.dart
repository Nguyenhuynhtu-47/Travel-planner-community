import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../explore/data/models/itinerary_summary.dart';
import '../data/itinerary_repository.dart';
import '../data/models/itinerary_detail.dart';

class ItineraryDetailNotifier extends ChangeNotifier {
  final int itineraryId;
  final ItineraryRepository _repository;

  ItinerarySummary? initialSummary;
  ItineraryDetail? itineraryDetail;
  bool isLoading;
  String? errorMessage;
  int? errorStatusCode;

  ItineraryDetailNotifier({
    required this.itineraryId,
    this.initialSummary,
    ItineraryDetail? initialDetail,
    ItineraryRepository? repository,
  }) : itineraryDetail = initialDetail,
       isLoading = initialDetail == null,
       _repository = repository ?? ItineraryRepository();

  bool get isSuccess => itineraryDetail != null;
  bool get isError => errorMessage != null && itineraryDetail == null;
  bool get isNotFound => errorStatusCode == 404;
  bool get isUnauthorized => errorStatusCode == 401 || errorStatusCode == 403;
  bool get isNetworkError => errorStatusCode == 0;

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
      if (itineraryDetail == null) {
        errorMessage = e.message;
        errorStatusCode = e.statusCode;
      }
    } catch (_) {
      if (itineraryDetail == null) {
        errorMessage =
            'Không thể tải chi tiết lịch trình. Vui lòng thử lại sau.';
        errorStatusCode = null;
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void retry({String? token}) {
    loadDetail(token: token);
  }
}
