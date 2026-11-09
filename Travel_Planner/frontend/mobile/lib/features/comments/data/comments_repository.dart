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

  Future<PageResult<ItineraryComment>> getActivityComments(int activityId, {int page = 0, int size = 10}) =>
      _getPage('/api/activities/$activityId/comments', page, size);

  Future<PageResult<ItineraryComment>> getReplies(int commentId, {int page = 0, int size = 10}) =>
      _getPage('/api/comments/$commentId/replies', page, size);

  Future<PageResult<ItineraryComment>> _getPage(String path, int page, int size) async {
    final response = await _apiClient.get(path, queryParameters: {'page': page, 'size': size});
    if (response is Map) {
      return PageResult<ItineraryComment>.fromJson(
        Map<String, dynamic>.from(response),
        (item) => ItineraryComment.fromJson(Map<String, dynamic>.from(item as Map)),
      );
    }
    throw Exception('Phản hồi bình luận từ máy chủ không hợp lệ.');
  }

  Future<ItineraryComment> createActivityComment(int activityId, {required String content, required String token}) =>
      _create('/api/activities/$activityId/comments', content, token);

  Future<ItineraryComment> createReply(int commentId, {required String content, required String token}) =>
      _create('/api/comments/$commentId/replies', content, token);

  Future<ItineraryComment> _create(String path, String content, String token) async {
    final response = await _apiClient.post(path, body: {'content': content}, token: token);
    if (response is Map) return ItineraryComment.fromJson(Map<String, dynamic>.from(response));
    throw Exception('Phản hồi bình luận từ máy chủ không hợp lệ.');
  }

  Future<ItineraryComment> updateComment(int commentId, {required String content, required String token}) async {
    final response = await _apiClient.put('/api/comments/$commentId', body: {'content': content}, token: token);
    if (response is Map) return ItineraryComment.fromJson(Map<String, dynamic>.from(response));
    throw Exception('Phản hồi bình luận từ máy chủ không hợp lệ.');
  }

  Future<void> deleteComment(int commentId, {required String token}) async {
    await _apiClient.delete('/api/comments/$commentId', token: token);
  }
}
