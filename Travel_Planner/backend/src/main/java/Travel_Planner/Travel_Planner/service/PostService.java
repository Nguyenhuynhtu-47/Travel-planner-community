package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.*;
import Travel_Planner.Travel_Planner.dto.response.*;
import Travel_Planner.Travel_Planner.model.enums.MediaAssetStatus;
import Travel_Planner.Travel_Planner.model.enums.PostStatus;
import Travel_Planner.Travel_Planner.model.enums.ReportStatus;

public interface PostService {

    PageResponse<PostResponse> getPublicFeed(int page, int size, String viewerUsername);

    PageResponse<PostResponse> getFollowingFeed(int page, int size, String viewerUsername);

    PostResponse getPostById(Long postId, String viewerUsername);

    PostResponse createPost(CreatePostRequest request, String authorUsername);

    PostResponse updatePost(Long postId, UpdatePostRequest request, String authorUsername);

    void deletePost(Long postId, String actorUsername);

    void likePost(Long postId, String actorUsername);

    void unlikePost(Long postId, String actorUsername);

    PageResponse<PostCommentResponse> getComments(Long postId, int page, int size, String viewerUsername);

    PostCommentResponse addComment(Long postId, CreatePostCommentRequest request, String authorUsername);

    PostCommentResponse updateComment(Long postId, Long commentId, UpdatePostCommentRequest request, String authorUsername);

    void deleteComment(Long postId, Long commentId, String actorUsername);

    PostReportResponse reportPost(Long postId, CreatePostReportRequest request, String reporterUsername);

    // Admin Moderation
    PageResponse<PostResponse> getAdminPosts(PostStatus status, int page, int size);

    PostResponse moderatePost(Long postId, ModeratePostRequest request, String adminUsername);

    void purgePost(Long postId, String adminUsername);

    PageResponse<PostReportResponse> getAdminReports(ReportStatus status, int page, int size);

    PostReportResponse resolveReport(Long reportId, ReportStatus resolution, String adminUsername);

    PageResponse<MediaAssetResponse> getAdminMediaAssets(MediaAssetStatus status, boolean deadLetterOnly, int page, int size);

    void retryMediaAsset(Long mediaAssetId, String adminUsername);
}

