import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/admin_itinerary_model.dart';

class PagedAdminItineraries {
  final List<AdminItineraryModel> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  const PagedAdminItineraries({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  factory PagedAdminItineraries.fromJson(Map<String, dynamic> json) {
    final list = (json['content'] is List)
        ? (json['content'] as List)
            .map((e) => AdminItineraryModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList()
        : <AdminItineraryModel>[];

    return PagedAdminItineraries(
      content: list,
      page: (json['pageNumber'] as num?)?.toInt() ??
          (json['page'] as num?)?.toInt() ??
          0,
      size: (json['pageSize'] as num?)?.toInt() ??
          (json['size'] as num?)?.toInt() ??
          20,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? list.length,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      last: json['last'] == true,
    );
  }
}

class ItineraryAdminRepository {
  final ApiClient _apiClient;

  ItineraryAdminRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<PagedAdminItineraries> getItinerariesPaged({
    String? keyword,
    String? status,
    int page = 0,
    int size = 20,
    String? sort,
    required String token,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'size': '$size',
    };
    if (keyword != null && keyword.trim().isNotEmpty) {
      params['keyword'] = keyword.trim();
    }
    if (status != null && status.isNotEmpty && status != 'ALL') {
      params['status'] = status;
    }
    if (sort != null && sort.isNotEmpty) {
      params['sort'] = sort;
    }

    final uri = Uri.parse(ApiConstants.adminItinerariesEndpoint)
        .replace(queryParameters: params)
        .toString();
    final data = await _apiClient.get(uri, token: token);
    return PagedAdminItineraries.fromJson(
        Map<String, dynamic>.from(data as Map));
  }

  Future<AdminItineraryDetailModel> getItineraryDetail(
    int itineraryId, {
    int? reportId,
    String? inspectionReason,
    required String token,
  }) async {
    final params = <String, String>{};
    if (reportId != null) {
      params['reportId'] = '$reportId';
    }
    if (inspectionReason != null && inspectionReason.trim().isNotEmpty) {
      params['inspectionReason'] = inspectionReason.trim();
    }

    final base = ApiConstants.adminItineraryDetailEndpoint(itineraryId);
    final endpoint = params.isEmpty
        ? base
        : Uri.parse(base).replace(queryParameters: params).toString();

    final data = await _apiClient.get(endpoint, token: token);
    return AdminItineraryDetailModel.fromJson(
        Map<String, dynamic>.from(data as Map));
  }

  Future<AdminItineraryModel> moderateItinerary(
    int itineraryId, {
    required String status,
    required String reason,
    required String token,
  }) async {
    final data = await _apiClient.patch(
      ApiConstants.adminItineraryModerateEndpoint(itineraryId),
      body: {
        'status': status,
        'reason': reason,
      },
      token: token,
    );
    return AdminItineraryModel.fromJson(
        Map<String, dynamic>.from(data as Map));
  }
}
