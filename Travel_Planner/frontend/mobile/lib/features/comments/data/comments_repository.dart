import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../explore/data/models/page_result.dart';
import 'models/itinerary_comment.dart';

class CommentsRepository {
  final ApiClient _apiClient;

  CommentsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<PageResult<ItineraryComment>> getComments(
    int itineraryId, {
    int page = 0,
    int size = 10,
  }) async {
    final response = await _apiClient.get(
      '${ApiConstants.itinerariesEndpoint}/$itineraryId${ApiConstants.commentsEndpoint}',
      queryParameters: {'page': page, 'size': size},
    );
    if (response is Map) {
      return PageResult<ItineraryComment>.fromJson(
        Map<String, dynamic>.from(response),
        (item) => ItineraryComment.fromJson(Map<String, dynamic>.from(item as Map)),
      );
    }
    throw Exception('Phản hồi bình luận từ máy chủ không hợp lệ.');
  }

  Future<ItineraryComment> createComment(
    int itineraryId, {
    required String content,
    required String token,
  }) async {
    final response = await _apiClient.post(
      '${ApiConstants.itinerariesEndpoint}/$itineraryId${ApiConstants.commentsEndpoint}',
      body: {'content': content},
      token: token,
    );
    if (response is Map) {
      return ItineraryComment.fromJson(Map<String, dynamic>.from(response));
    }
    throw Exception('Phản hồi bình luận từ máy chủ không hợp lệ.');
  }
}
