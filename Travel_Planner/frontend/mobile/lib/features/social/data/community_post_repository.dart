import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/post_comment_model.dart';
import 'models/post_model.dart';

class CommunityPostRepository {
  final ApiClient _apiClient;

  CommunityPostRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<PostModel>> getPublicFeed({
    int page = 0,
    int size = 10,
    String? token,
  }) async {
    final response = await _apiClient.get(
      '${ApiConstants.communityFeedEndpoint}?page=$page&size=$size',
      token: token,
    );
    if (response is Map<String, dynamic> && response['content'] is List) {
      final list = response['content'] as List;
      return list
          .map((item) => PostModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }

  Future<List<PostModel>> getFollowingFeed({
    int page = 0,
    int size = 10,
    required String token,
  }) async {
    final response = await _apiClient.get(
      '${ApiConstants.communityFollowingFeedEndpoint}?page=$page&size=$size',
      token: token,
    );
    if (response is Map<String, dynamic> && response['content'] is List) {
      final list = response['content'] as List;
      return list
          .map((item) => PostModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }

  Future<PostModel> getPostById(int postId, {String? token}) async {
    final response = await _apiClient.get(
      ApiConstants.communityPostDetailEndpoint(postId),
      token: token,
    );
    if (response is Map<String, dynamic>) {
      return PostModel.fromJson(response);
    }
    throw Exception('Dữ liệu bài viết không hợp lệ');
  }

  Future<PostModel> createPost({
    required String content,
    String visibility = 'PUBLIC',
    int? itineraryId,
    List<int>? mediaAssetIds,
    required String token,
  }) async {
    final body = <String, dynamic>{
      'content': content,
      'visibility': visibility,
    };
    if (itineraryId != null) {
      body['itineraryId'] = itineraryId;
    }
    if (mediaAssetIds != null && mediaAssetIds.isNotEmpty) {
      body['mediaAssetIds'] = mediaAssetIds;
    }

    final response = await _apiClient.post(
      ApiConstants.communityPostsEndpoint,
      body: body,
      token: token,
    );
    if (response is Map<String, dynamic>) {
      return PostModel.fromJson(response);
    }
    throw Exception('Không thể tạo bài viết');
  }

  Future<PostModel> updatePost(
    int postId, {
    String? content,
    String? visibility,
    required String token,
  }) async {
    final body = <String, dynamic>{};
    if (content != null) body['content'] = content;
    if (visibility != null) body['visibility'] = visibility;

    final response = await _apiClient.patch(
      ApiConstants.communityPostDetailEndpoint(postId),
      body: body,
      token: token,
    );
    if (response is Map<String, dynamic>) {
      return PostModel.fromJson(response);
    }
    throw Exception('Không thể chỉnh sửa bài viết');
  }

  Future<void> deletePost(int postId, {required String token}) async {
    await _apiClient.delete(
      ApiConstants.communityPostDetailEndpoint(postId),
      token: token,
    );
  }

  Future<void> likePost(int postId, {required String token}) async {
    await _apiClient.post(
      ApiConstants.communityPostLikesEndpoint(postId),
      body: {},
      token: token,
    );
  }

  Future<void> unlikePost(int postId, {required String token}) async {
    await _apiClient.delete(
      ApiConstants.communityPostLikesEndpoint(postId),
      token: token,
    );
  }

  Future<List<PostCommentModel>> getComments(
    int postId, {
    int page = 0,
    int size = 20,
    String? token,
  }) async {
    final response = await _apiClient.get(
      '${ApiConstants.communityPostCommentsEndpoint(postId)}?page=$page&size=$size',
      token: token,
    );
    if (response is Map<String, dynamic> && response['content'] is List) {
      final list = response['content'] as List;
      return list
          .map((item) =>
              PostCommentModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }

  Future<PostCommentModel> addComment(
    int postId, {
    required String content,
    required String token,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.communityPostCommentsEndpoint(postId),
      body: {'content': content},
      token: token,
    );
    if (response is Map<String, dynamic>) {
      return PostCommentModel.fromJson(response);
    }
    throw Exception('Không thể đăng bình luận');
  }

  Future<void> deleteComment(
    int postId,
    int commentId, {
    required String token,
  }) async {
    await _apiClient.delete(
      ApiConstants.communityPostCommentDetailEndpoint(postId, commentId),
      token: token,
    );
  }

  Future<void> reportPost(
    int postId, {
    required String reason,
    String? details,
    required String token,
  }) async {
    await _apiClient.post(
      ApiConstants.communityPostReportEndpoint(postId),
      body: {
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      },
      token: token,
    );
  }

  Future<int> getTotalUnread({required String token}) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.conversationsUnreadTotalEndpoint,
        token: token,
      );
      if (response is Map<String, dynamic> && response['totalUnread'] != null) {
        return int.tryParse('${response['totalUnread']}') ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  Future<Map<String, dynamic>> uploadImage({
    required List<int> bytes,
    required String filename,
    required String token,
  }) async {
    final response = await _apiClient.uploadFile(
      ApiConstants.imageUploadEndpoint,
      bytes: bytes,
      filename: filename,
      token: token,
    );
    if (response is Map<String, dynamic>) {
      final mediaAssetId = response['mediaAssetId'] is int
          ? response['mediaAssetId'] as int
          : int.tryParse('${response['mediaAssetId']}');
      final secureUrl = response['secureUrl']?.toString() ?? '';
      return {
        'mediaAssetId': mediaAssetId,
        'secureUrl': secureUrl,
      };
    }
    throw Exception('Tải ảnh lên thất bại');
  }
}

