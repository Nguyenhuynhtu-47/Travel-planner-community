package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.CreateCommentRequest;
import Travel_Planner.Travel_Planner.dto.response.CommentResponse;
import Travel_Planner.Travel_Planner.dto.response.CreatorSummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.service.CommentService;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import java.util.Map;

@Service
public class CommentServiceImpl implements CommentService {
    private static final int DEFAULT_PAGE_SIZE = 10;
    private static final int MAX_PAGE_SIZE = 50;
    private final CommentRepository comments;
    private final ItineraryRepository itineraries;
    private final ActivityRepository activities;
    private final UserRepository users;

    public CommentServiceImpl(CommentRepository comments, ItineraryRepository itineraries,
                              ActivityRepository activities, UserRepository users) {
        this.comments = comments;
        this.itineraries = itineraries;
        this.activities = activities;
        this.users = users;
    }

    @Override @Transactional(readOnly = true)
    public PageResponse<CommentResponse> getComments(Integer itineraryId, int page, int size) {
        requirePublicItinerary(itineraryId);
        return toRootPage(comments.pageItineraryRoots(itineraryId, CommentStatus.ACTIVE, CommentStatus.DELETED,
                pageRequest(page, size, Sort.Direction.DESC)));
    }

    @Override @Transactional
    public CommentResponse createComment(Integer itineraryId, CreateCommentRequest request, String username) {
        Itinerary itinerary = requirePublicItinerary(itineraryId);
        User author = requireActiveUser(username);
        Comment comment = new Comment();
        comment.setUser(author); comment.setItinerary(itinerary);
        comment.setContent(validateContent(request)); comment.setStatus(CommentStatus.ACTIVE);
        comment = comments.saveAndFlush(comment);
        comment.setRootComment(comment);
        comment = comments.save(comment);
        itineraries.incrementCommentCount(itineraryId);
        return toResponse(comment);
    }

    @Override @Transactional(readOnly = true)
    public PageResponse<CommentResponse> getActivityComments(Integer activityId, int page, int size) {
        Activity activity = requirePublicActivity(activityId);
        return toRootPage(comments.pageActivityRoots(activity.getActivityId(), CommentStatus.ACTIVE,
                CommentStatus.DELETED, pageRequest(page, size, Sort.Direction.DESC)));
    }

    @Override @Transactional
    public CommentResponse createActivityComment(Integer activityId, CreateCommentRequest request, String username) {
        Activity activity = requirePublicActivity(activityId);
        User author = requireActiveUser(username);
        Comment comment = new Comment();
        comment.setUser(author); comment.setActivity(activity);
        comment.setItinerary(activity.getItineraryDay().getItinerary());
        comment.setContent(validateContent(request)); comment.setStatus(CommentStatus.ACTIVE);
        comment = comments.saveAndFlush(comment);
        comment.setRootComment(comment);
        comment = comments.save(comment);
        return toResponse(comment);
    }

    @Override @Transactional(readOnly = true)
    public PageResponse<CommentResponse> getReplies(Integer commentId, int page, int size) {
        Comment parent = findComment(commentId);
        requireTargetPublic(parent);
        Comment root = resolveRoot(parent);
        return PageResponse.from(comments.pageThreadReplies(root.getCommentId(), CommentStatus.ACTIVE,
                CommentStatus.DELETED, pageRequest(page, size, Sort.Direction.ASC)).map(this::toResponse));
    }

    @Override @Transactional
    public CommentResponse createReply(Integer commentId, CreateCommentRequest request, String username) {
        Comment parent = findComment(commentId);
        Itinerary itinerary = requireTargetPublic(parent);
        if (parent.getStatus() != CommentStatus.ACTIVE) throw new ResourceNotFoundException("Không tìm thấy bình luận");
        User author = requireActiveUser(username);
        Comment root = resolveRoot(parent);
        Comment reply = new Comment();
        reply.setUser(author); reply.setItinerary(itinerary); reply.setActivity(parent.getActivity());
        reply.setParentComment(parent); reply.setRootComment(root);
        reply.setContent(validateContent(request)); reply.setStatus(CommentStatus.ACTIVE);
        reply = comments.save(reply);
        if (reply.getActivity() == null && reply.getItinerary() != null)
            itineraries.incrementCommentCount(reply.getItinerary().getItineraryId());
        return toResponse(reply);
    }

    @Override @Transactional
    public CommentResponse updateComment(Integer commentId, CreateCommentRequest request, String username) {
        Comment comment = findComment(commentId);
        requireTargetExists(comment);
        User actor = requireActiveUser(username);
        if (!comment.getUser().getUserId().equals(actor.getUserId()) && actor.getRole() != Role.ADMIN)
            throw new UnauthorizedException("Bạn không có quyền sửa bình luận này");
        if (comment.getStatus() != CommentStatus.ACTIVE) throw new ResourceNotFoundException("Không tìm thấy bình luận");
        comment.setContent(validateContent(request));
        return toResponse(comments.save(comment));
    }

    @Override @Transactional
    public void deleteComment(Integer commentId, String username) {
        Comment comment = findComment(commentId);
        requireTargetExists(comment);
        User actor = requireActiveUser(username);
        if (!comment.getUser().getUserId().equals(actor.getUserId()) && actor.getRole() != Role.ADMIN)
            throw new UnauthorizedException("Bạn không có quyền xóa bình luận này");
        if (comment.getStatus() != CommentStatus.ACTIVE) return;
        comment.setStatus(CommentStatus.DELETED);
        comment.setContent("");
        comments.save(comment);
        if (comment.getActivity() == null && comment.getItinerary() != null)
            decrementItineraryCount(comment.getItinerary().getItineraryId());
    }

    private Itinerary requirePublicItinerary(Integer id) {
        Itinerary itinerary = itineraries.findByIdWithUser(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lịch trình"));
        if (itinerary.getStatus() != ItineraryStatus.ACTIVE || itinerary.getVisibility() != Visibility.PUBLIC
                || itinerary.getUser().getStatus() != UserStatus.ACTIVE)
            throw new ResourceNotFoundException("Không tìm thấy lịch trình công khai");
        return itinerary;
    }

    private Activity requirePublicActivity(Integer id) {
        Activity activity = activities.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy hoạt động"));
        requirePublicItinerary(activity.getItineraryDay().getItinerary().getItineraryId());
        return activity;
    }

    private Itinerary requireTargetPublic(Comment comment) {
        Itinerary itinerary = requireTargetExists(comment);
        return requirePublicItinerary(itinerary.getItineraryId());
    }

    private Itinerary requireTargetExists(Comment comment) {
        if (comment.getActivity() != null) {
            Integer activityId = comment.getActivity().getActivityId();
            if (activityId == null || !activities.existsById(activityId))
                throw new ResourceNotFoundException("Không tìm thấy hoạt động bình luận");
            ItineraryDay day = comment.getActivity().getItineraryDay();
            if (day == null || day.getItinerary() == null)
                throw new ResourceNotFoundException("Không tìm thấy lịch trình của hoạt động");
            Itinerary activityItinerary = day.getItinerary();
            if (comment.getItinerary() != null && !comment.getItinerary().getItineraryId()
                    .equals(activityItinerary.getItineraryId()))
                throw new BadRequestException("Hoạt động không thuộc lịch trình của bình luận");
            if (!itineraries.existsById(activityItinerary.getItineraryId()))
                throw new ResourceNotFoundException("Không tìm thấy lịch trình bình luận");
            return activityItinerary;
        }
        if (comment.getItinerary() == null
                || !itineraries.existsById(comment.getItinerary().getItineraryId()))
            throw new ResourceNotFoundException("Không tìm thấy lịch trình bình luận");
        return comment.getItinerary();
    }

    private User requireActiveUser(String username) {
        if (username == null || username.isBlank()) throw new UnauthorizedException("Bạn cần đăng nhập");
        User user = users.findByUsername(username).orElseThrow(() -> new UnauthorizedException("Phiên đăng nhập không hợp lệ"));
        if (user.getStatus() != UserStatus.ACTIVE) throw new UnauthorizedException("Tài khoản không hoạt động");
        return user;
    }

    private Comment findComment(Integer id) {
        return comments.findById(id).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy bình luận"));
    }

    private Comment resolveRoot(Comment comment) {
        Comment cursor = comment;
        java.util.Set<Integer> visited = new java.util.HashSet<>();
        Integer itineraryId = targetItinerary(comment).getItineraryId();
        Integer activityId = comment.getActivity() == null ? null : comment.getActivity().getActivityId();
        while (cursor.getParentComment() != null) {
            if (!visited.add(cursor.getCommentId())) throw new BadRequestException("Chuỗi trả lời không hợp lệ");
            cursor = cursor.getParentComment();
            Integer cursorItineraryId = targetItinerary(cursor).getItineraryId();
            Integer cursorActivityId = cursor.getActivity() == null ? null : cursor.getActivity().getActivityId();
            if (!java.util.Objects.equals(itineraryId, cursorItineraryId)
                    || !java.util.Objects.equals(activityId, cursorActivityId))
                throw new BadRequestException("Bình luận cha không cùng lịch trình hoặc hoạt động");
            if (visited.size() > 1000) throw new BadRequestException("Chuỗi trả lời vượt giới hạn an toàn");
        }
        return cursor;
    }

    private PageRequest pageRequest(int page, int size, Sort.Direction direction) {
        int safePage = Math.max(0, page);
        int safeSize = size <= 0 ? DEFAULT_PAGE_SIZE : Math.min(size, MAX_PAGE_SIZE);
        return PageRequest.of(safePage, safeSize, Sort.by(direction, "createdAt").and(Sort.by(direction, "commentId")));
    }

    private String validateContent(CreateCommentRequest request) {
        if (request == null || request.getContent() == null || request.getContent().trim().isEmpty())
            throw new BadRequestException("Nội dung bình luận không được để trống");
        String content = request.getContent().trim();
        if (content.length() > 2000) throw new BadRequestException("Bình luận không được vượt quá 2000 ký tự");
        return content;
    }

    private Itinerary targetItinerary(Comment comment) {
        if (comment.getItinerary() != null) return comment.getItinerary();
        if (comment.getActivity() != null && comment.getActivity().getItineraryDay() != null)
            return comment.getActivity().getItineraryDay().getItinerary();
        throw new ResourceNotFoundException("Không tìm thấy lịch trình bình luận");
    }

    private void decrementItineraryCount(Integer itineraryId) {
        Itinerary itinerary = itineraries.findById(itineraryId).orElse(null);
        if (itinerary != null && itinerary.getCommentCount() > 0) {
            itinerary.setCommentCount(itinerary.getCommentCount() - 1);
            itineraries.save(itinerary);
        }
    }

    private CommentResponse toResponse(Comment comment) {
        CreatorSummaryResponse creator = creator(comment.getUser());
        Comment parent = comment.getParentComment();
        String content = comment.getStatus() == CommentStatus.DELETED ? "Bình luận đã bị xóa" : comment.getContent();
        Integer rootId = comment.getRootComment() == null ? comment.getCommentId() : comment.getRootComment().getCommentId();
        return CommentResponse.builder().commentId(comment.getCommentId()).content(content).creator(creator)
                .createdAt(comment.getCreatedAt()).updatedAt(comment.getUpdatedAt())
                .parentCommentId(parent == null ? null : parent.getCommentId()).rootCommentId(rootId)
                .replyCount(0).deleted(comment.getStatus() == CommentStatus.DELETED)
                .replyToCreator(parent == null ? null : creator(parent.getUser()))
                .targetType(comment.getActivity() == null ? "ITINERARY" : "ACTIVITY")
                .targetId(comment.getActivity() == null ? targetItinerary(comment).getItineraryId() : comment.getActivity().getActivityId())
                .build();
    }

    private PageResponse<CommentResponse> toRootPage(Page<Comment> page) {
        List<Integer> rootIds = page.getContent().stream().map(Comment::getCommentId).toList();
        Map<Integer, Integer> counts = new java.util.HashMap<>();
        if (!rootIds.isEmpty()) comments.countActiveRepliesByRootIds(rootIds, CommentStatus.ACTIVE)
                .forEach(row -> counts.put((Integer) row[0], ((Number) row[1]).intValue()));
        return PageResponse.from(page.map(comment -> {
            CommentResponse response = toResponse(comment);
            response.setReplyCount(counts.getOrDefault(comment.getCommentId(), 0));
            return response;
        }));
    }

    private CreatorSummaryResponse creator(User user) {
        return CreatorSummaryResponse.builder().userId(user.getUserId()).username(user.getUsername()).handle(user.getHandle())
                .fullName(user.getFullName()).avatar(user.getAvatar()).build();
    }
}
