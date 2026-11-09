package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.CreateCommentRequest;
import Travel_Planner.Travel_Planner.dto.response.CommentResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;

public interface CommentService {
    PageResponse<CommentResponse> getComments(Integer itineraryId, int page, int size);

    CommentResponse createComment(Integer itineraryId, CreateCommentRequest request, String currentUsername);

    PageResponse<CommentResponse> getActivityComments(Integer activityId, int page, int size);
    CommentResponse createActivityComment(Integer activityId, CreateCommentRequest request, String currentUsername);
    PageResponse<CommentResponse> getReplies(Integer commentId, int page, int size);
    CommentResponse createReply(Integer commentId, CreateCommentRequest request, String currentUsername);
    CommentResponse updateComment(Integer commentId, CreateCommentRequest request, String currentUsername);
    void deleteComment(Integer commentId, String currentUsername);
}
