package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.CreateCommentRequest;
import Travel_Planner.Travel_Planner.dto.response.CommentResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;

public interface CommentService {
    PageResponse<CommentResponse> getComments(Integer itineraryId, int page, int size);

    CommentResponse createComment(Integer itineraryId, CreateCommentRequest request, String currentUsername);
}
