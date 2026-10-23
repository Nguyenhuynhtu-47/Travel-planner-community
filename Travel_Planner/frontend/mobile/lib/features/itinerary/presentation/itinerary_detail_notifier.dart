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
  bool isLoading = false;
  String? errorMessage;

  ItineraryDetailNotifier({
    required this.itineraryId,
    this.initialSummary,
    ItineraryRepository? repository,
  }) : _repository = repository ?? ItineraryRepository();

  bool get isSuccess => itineraryDetail != null;
  bool get isError => errorMessage != null && itineraryDetail == null;

  Future<void> loadDetail({String? token}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final detail = await _repository.getItineraryDetail(
        itineraryId,
        token: token,
      );
      itineraryDetail = detail;
      errorMessage = null;
    } on ApiException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Không thể tải chi tiết lịch trình. Vui lòng thử lại sau.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void retry({String? token}) {
    loadDetail(token: token);
  }
}
