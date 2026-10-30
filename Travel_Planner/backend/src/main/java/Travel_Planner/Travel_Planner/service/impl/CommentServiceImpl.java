package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.CreateCommentRequest;
import Travel_Planner.Travel_Planner.dto.response.CommentResponse;
import Travel_Planner.Travel_Planner.dto.response.CreatorSummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.Comment;
import Travel_Planner.Travel_Planner.model.Itinerary;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.CommentStatus;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;
import Travel_Planner.Travel_Planner.repository.CommentRepository;
import Travel_Planner.Travel_Planner.repository.ItineraryRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.CommentService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CommentServiceImpl implements CommentService {
    private static final int DEFAULT_PAGE_SIZE = 10;
    private static final int MAX_PAGE_SIZE = 50;

    private final CommentRepository commentRepository;
    private final ItineraryRepository itineraryRepository;
    private final UserRepository userRepository;

    public CommentServiceImpl(CommentRepository commentRepository,
                              ItineraryRepository itineraryRepository,
                              UserRepository userRepository) {
        this.commentRepository = commentRepository;
        this.itineraryRepository = itineraryRepository;
        this.userRepository = userRepository;
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<CommentResponse> getComments(Integer itineraryId, int page, int size) {
        Itinerary itinerary = getPublicItinerary(itineraryId);
        int normalizedPage = Math.max(0, page);
        int normalizedSize = size <= 0 ? DEFAULT_PAGE_SIZE : Math.min(size, MAX_PAGE_SIZE);
        Page<CommentResponse> comments = commentRepository
                .findByItinerary_ItineraryIdAndStatusOrderByCreatedAtDesc(
                        itinerary.getItineraryId(), CommentStatus.ACTIVE,
                        PageRequest.of(normalizedPage, normalizedSize,
                                Sort.by(Sort.Direction.DESC, "createdAt").and(Sort.by(Sort.Direction.DESC, "commentId"))))
                .map(this::toResponse);
        return PageResponse.from(comments);
    }

    @Override
    @Transactional
    public CommentResponse createComment(Integer itineraryId, CreateCommentRequest request, String currentUsername) {
        if (currentUsername == null || currentUsername.isBlank()) {
            throw new UnauthorizedException("Bạn cần đăng nhập để bình luận");
        }
        Itinerary itinerary = getPublicItinerary(itineraryId);
        User user = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new UnauthorizedException("Phiên đăng nhập không hợp lệ"));
        String content = request.getContent() == null ? "" : request.getContent().trim();
        if (content.isEmpty()) {
            throw new BadRequestException("Nội dung bình luận không được để trống");
        }

        Comment comment = commentRepository.save(Comment.builder()
                .user(user)
                .itinerary(itinerary)
                .content(content)
                .status(CommentStatus.ACTIVE)
                .build());
        itineraryRepository.incrementCommentCount(itinerary.getItineraryId());
        return toResponse(comment);
    }

    private Itinerary getPublicItinerary(Integer itineraryId) {
        Itinerary itinerary = itineraryRepository.findById(itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lịch trình"));
        if (itinerary.getStatus() != ItineraryStatus.ACTIVE
                || itinerary.getVisibility() != Visibility.PUBLIC
                || itinerary.getUser().getStatus() != UserStatus.ACTIVE) {
            throw new ResourceNotFoundException("Không tìm thấy lịch trình công khai");
        }
        return itinerary;
    }

    private CommentResponse toResponse(Comment comment) {
        User user = comment.getUser();
        CreatorSummaryResponse creator = CreatorSummaryResponse.builder()
                .userId(user.getUserId())
                .username(user.getUsername())
                .fullName(user.getFullName())
                .avatar(user.getAvatar())
                .build();
        return CommentResponse.builder()
                .commentId(comment.getCommentId())
                .content(comment.getContent())
                .creator(creator)
                .createdAt(comment.getCreatedAt())
                .updatedAt(comment.getUpdatedAt())
                .build();
    }
}
