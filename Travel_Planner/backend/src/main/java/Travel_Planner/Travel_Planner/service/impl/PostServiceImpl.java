package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.*;
import Travel_Planner.Travel_Planner.dto.response.*;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ConflictException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.service.PostService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class PostServiceImpl implements PostService {

    private static final Logger logger = LoggerFactory.getLogger(PostServiceImpl.class);

    private final PostRepository postRepository;
    private final MediaAssetRepository mediaAssetRepository;
    private final PostMediaRepository postMediaRepository;
    private final PostLikeRepository postLikeRepository;
    private final PostCommentRepository postCommentRepository;
    private final PostReportRepository postReportRepository;
    private final UserRepository userRepository;
    private final ItineraryRepository itineraryRepository;
    private final FriendshipRepository friendshipRepository;

    public PostServiceImpl(
            PostRepository postRepository,
            MediaAssetRepository mediaAssetRepository,
            PostMediaRepository postMediaRepository,
            PostLikeRepository postLikeRepository,
            PostCommentRepository postCommentRepository,
            PostReportRepository postReportRepository,
            UserRepository userRepository,
            ItineraryRepository itineraryRepository,
            FriendshipRepository friendshipRepository) {
        this.postRepository = postRepository;
        this.mediaAssetRepository = mediaAssetRepository;
        this.postMediaRepository = postMediaRepository;
        this.postLikeRepository = postLikeRepository;
        this.postCommentRepository = postCommentRepository;
        this.postReportRepository = postReportRepository;
        this.userRepository = userRepository;
        this.itineraryRepository = itineraryRepository;
        this.friendshipRepository = friendshipRepository;
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<PostResponse> getPublicFeed(int page, int size, String viewerUsername) {
        if (page < 0 || size < 1) {
            throw new BadRequestException("Thông tin phân trang không hợp lệ");
        }
        int pageSize = Math.min(size, 50);
        Pageable pageable = PageRequest.of(page, pageSize);

        User viewer = resolveOptionalUser(viewerUsername);
        Integer viewerId = viewer != null ? viewer.getUserId() : null;

        // Query 1: Paginated posts with author and itinerary
        Page<Post> postsPage = postRepository.findPublicFeed(pageable);
        List<Post> posts = postsPage.getContent();
        if (posts.isEmpty()) {
            return PageResponse.from(postsPage.map(p -> null));
        }

        List<Long> postIds = posts.stream().map(Post::getPostId).toList();

        // Query 2: Batch fetch media assets
        Map<Long, List<String>> mediaUrlsByPost = new HashMap<>();
        Map<Long, List<Long>> mediaAssetIdsByPost = new HashMap<>();
        List<PostMedia> postMediaList = postMediaRepository.findByPostIdsWithAsset(postIds);
        for (PostMedia pm : postMediaList) {
            Long postId = pm.getPost().getPostId();
            mediaUrlsByPost.computeIfAbsent(postId, k -> new ArrayList<>()).add(pm.getMediaAsset().getSecureUrl());
            mediaAssetIdsByPost.computeIfAbsent(postId, k -> new ArrayList<>()).add(pm.getMediaAsset().getMediaAssetId());
        }

        // Query 3: Viewer like states
        Set<Long> likedPostIds = Collections.emptySet();
        if (viewerId != null) {
            likedPostIds = new HashSet<>(postLikeRepository.findLikedPostIds(postIds, viewerId));
        }

        Set<Long> finalLikedPostIds = likedPostIds;
        List<PostResponse> responseList = posts.stream().map(post -> {
            List<String> urls = mediaUrlsByPost.getOrDefault(post.getPostId(), Collections.emptyList());
            List<Long> assetIds = mediaAssetIdsByPost.getOrDefault(post.getPostId(), Collections.emptyList());
            boolean liked = finalLikedPostIds.contains(post.getPostId());
            return toPostResponse(post, urls, assetIds, liked, viewerId);
        }).toList();

        return PageResponse.<PostResponse>builder()
                .content(responseList)
                .pageNumber(postsPage.getNumber())
                .pageSize(postsPage.getSize())
                .totalElements(postsPage.getTotalElements())
                .totalPages(postsPage.getTotalPages())
                .last(postsPage.isLast())
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<PostResponse> getFollowingFeed(int page, int size, String viewerUsername) {
        User viewer = getActiveUser(viewerUsername);
        if (page < 0 || size < 1) {
            throw new BadRequestException("Thông tin phân trang không hợp lệ");
        }
        int pageSize = Math.min(size, 50);
        Pageable pageable = PageRequest.of(page, pageSize);

        Page<Post> postsPage = postRepository.findFollowingFeed(viewer.getUserId(), pageable);
        List<Post> posts = postsPage.getContent();
        if (posts.isEmpty()) {
            return PageResponse.from(postsPage.map(p -> null));
        }

        List<Long> postIds = posts.stream().map(Post::getPostId).toList();

        Map<Long, List<String>> mediaUrlsByPost = new HashMap<>();
        Map<Long, List<Long>> mediaAssetIdsByPost = new HashMap<>();
        List<PostMedia> postMediaList = postMediaRepository.findByPostIdsWithAsset(postIds);
        for (PostMedia pm : postMediaList) {
            Long postId = pm.getPost().getPostId();
            mediaUrlsByPost.computeIfAbsent(postId, k -> new ArrayList<>()).add(pm.getMediaAsset().getSecureUrl());
            mediaAssetIdsByPost.computeIfAbsent(postId, k -> new ArrayList<>()).add(pm.getMediaAsset().getMediaAssetId());
        }

        Set<Long> likedPostIds = new HashSet<>(postLikeRepository.findLikedPostIds(postIds, viewer.getUserId()));

        List<PostResponse> responseList = posts.stream().map(post -> {
            List<String> urls = mediaUrlsByPost.getOrDefault(post.getPostId(), Collections.emptyList());
            List<Long> assetIds = mediaAssetIdsByPost.getOrDefault(post.getPostId(), Collections.emptyList());
            boolean liked = likedPostIds.contains(post.getPostId());
            return toPostResponse(post, urls, assetIds, liked, viewer.getUserId());
        }).toList();

        return PageResponse.<PostResponse>builder()
                .content(responseList)
                .pageNumber(postsPage.getNumber())
                .pageSize(postsPage.getSize())
                .totalElements(postsPage.getTotalElements())
                .totalPages(postsPage.getTotalPages())
                .last(postsPage.isLast())
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public PostResponse getPostById(Long postId, String viewerUsername) {
        User viewer = resolveOptionalUser(viewerUsername);
        Post post = getAuthorizedPost(postId, viewer);

        List<PostMedia> postMediaList = postMediaRepository.findByPost_PostIdOrderByDisplayOrderAsc(postId);
        List<String> urls = postMediaList.stream().map(pm -> pm.getMediaAsset().getSecureUrl()).toList();
        List<Long> assetIds = postMediaList.stream().map(pm -> pm.getMediaAsset().getMediaAssetId()).toList();

        boolean liked = false;
        Integer viewerId = null;
        if (viewer != null) {
            viewerId = viewer.getUserId();
            liked = postLikeRepository.existsByPost_PostIdAndUser_UserId(postId, viewerId);
        }

        return toPostResponse(post, urls, assetIds, liked, viewerId);
    }

    @Override
    @Transactional
    public PostResponse createPost(CreatePostRequest request, String authorUsername) {
        User author = getActiveUser(authorUsername);

        if ((request.getContent() == null || request.getContent().trim().isEmpty())
                && (request.getMediaAssetIds() == null || request.getMediaAssetIds().isEmpty())
                && request.getItineraryId() == null) {
            throw new BadRequestException("Bài viết phải có ít nhất nội dung văn bản, ảnh hoặc lịch trình");
        }

        // Validate attached itinerary if present
        Itinerary itinerary = null;
        if (request.getItineraryId() != null) {
            itinerary = itineraryRepository.findById(request.getItineraryId())
                    .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lịch trình"));
            if (itinerary.getVisibility() != Visibility.PUBLIC
                    || itinerary.getStatus() != ItineraryStatus.ACTIVE
                    || itinerary.getUser() == null
                    || itinerary.getUser().getStatus() != UserStatus.ACTIVE) {
                throw new BadRequestException("Chỉ được đính kèm lịch trình công khai và đang hoạt động");
            }
        }

        // Validate and lock media assets if present
        List<MediaAsset> lockedAssets = new ArrayList<>();
        if (request.getMediaAssetIds() != null && !request.getMediaAssetIds().isEmpty()) {
            List<Long> assetIds = request.getMediaAssetIds();
            Set<Long> uniqueIds = new HashSet<>(assetIds);
            if (uniqueIds.size() != assetIds.size()) {
                throw new BadRequestException("Danh sách ảnh chứa định danh trùng lặp");
            }
            if (assetIds.size() > 5) {
                throw new BadRequestException("Vượt quá giới hạn tối đa 5 ảnh");
            }

            List<Long> sortedIds = assetIds.stream().sorted().toList();
            List<MediaAsset> foundAssets = mediaAssetRepository.findByIdsForUpdate(sortedIds);
            if (foundAssets.size() != sortedIds.size()) {
                throw new ResourceNotFoundException("Tệp phương tiện không tồn tại");
            }

            Map<Long, MediaAsset> assetMap = foundAssets.stream()
                    .collect(Collectors.toMap(MediaAsset::getMediaAssetId, a -> a));

            for (Long id : assetIds) {
                MediaAsset a = assetMap.get(id);
                if (a == null || !a.getUploadedBy().getUserId().equals(author.getUserId())) {
                    throw new ResourceNotFoundException("Tệp phương tiện không tồn tại hoặc bạn không có quyền truy cập");
                }
                if (a.getStatus() == MediaAssetStatus.ATTACHED) {
                    throw new ConflictException("Tệp phương tiện đã được sử dụng trong bài viết khác");
                }
                if (a.getStatus() == MediaAssetStatus.DELETING || a.getStatus() == MediaAssetStatus.DELETED) {
                    throw new ConflictException("Tệp phương tiện đang được xóa hoặc không còn khả dụng");
                }
                lockedAssets.add(a);
            }
        }

        PostVisibility visibility = request.getVisibility() != null ? request.getVisibility() : PostVisibility.PUBLIC;

        Post post = Post.builder()
                .author(author)
                .itinerary(itinerary)
                .content(request.getContent() != null ? request.getContent().trim() : "")
                .visibility(visibility)
                .status(PostStatus.ACTIVE)
                .likeCount(0)
                .commentCount(0)
                .build();

        post = postRepository.save(post);

        List<String> mediaUrls = new ArrayList<>();
        List<Long> mediaAssetIds = new ArrayList<>();

        for (int i = 0; i < lockedAssets.size(); i++) {
            MediaAsset asset = lockedAssets.get(i);
            asset.setStatus(MediaAssetStatus.ATTACHED);
            asset.setUpdatedAt(LocalDateTime.now());
            mediaAssetRepository.save(asset);

            PostMedia pm = PostMedia.builder()
                    .post(post)
                    .mediaAsset(asset)
                    .displayOrder(i)
                    .build();
            postMediaRepository.save(pm);

            mediaUrls.add(asset.getSecureUrl());
            mediaAssetIds.add(asset.getMediaAssetId());
        }

        return toPostResponse(post, mediaUrls, mediaAssetIds, false, author.getUserId());
    }

    @Override
    @Transactional
    public PostResponse updatePost(Long postId, UpdatePostRequest request, String authorUsername) {
        User author = getActiveUser(authorUsername);
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new ResourceNotFoundException("Bài viết không tồn tại"));

        if (!post.getAuthor().getUserId().equals(author.getUserId())) {
            throw new ForbiddenException("Bạn không có quyền chỉnh sửa bài viết này");
        }
        if (post.getStatus() != PostStatus.ACTIVE) {
            throw new ResourceNotFoundException("Bài viết không tồn tại hoặc đã bị xóa");
        }

        if (request.getContent() != null) {
            post.setContent(request.getContent().trim());
        }
        if (request.getVisibility() != null) {
            post.setVisibility(request.getVisibility());
        }
        post.setUpdatedAt(LocalDateTime.now());
        post = postRepository.save(post);

        List<PostMedia> postMediaList = postMediaRepository.findByPost_PostIdOrderByDisplayOrderAsc(postId);
        List<String> urls = postMediaList.stream().map(pm -> pm.getMediaAsset().getSecureUrl()).toList();
        List<Long> assetIds = postMediaList.stream().map(pm -> pm.getMediaAsset().getMediaAssetId()).toList();
        boolean liked = postLikeRepository.existsByPost_PostIdAndUser_UserId(postId, author.getUserId());

        return toPostResponse(post, urls, assetIds, liked, author.getUserId());
    }

    @Override
    @Transactional
    public void deletePost(Long postId, String actorUsername) {
        User actor = getActiveUser(actorUsername);
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new ResourceNotFoundException("Bài viết không tồn tại"));

        boolean isAuthor = post.getAuthor().getUserId().equals(actor.getUserId());
        boolean isAdmin = actor.getRole() == Role.ADMIN;
        if (!isAuthor && !isAdmin) {
            throw new ForbiddenException("Bạn không có quyền xóa bài viết này");
        }

        // Soft delete: keep attached media to allow restoration
        post.setStatus(PostStatus.DELETED);
        post.setDeletedAt(LocalDateTime.now());
        postRepository.save(post);
    }

    @Override
    @Transactional
    public void likePost(Long postId, String actorUsername) {
        User actor = getActiveUser(actorUsername);
        Post post = getAuthorizedPost(postId, actor);

        if (!postLikeRepository.existsByPost_PostIdAndUser_UserId(postId, actor.getUserId())) {
            PostLike like = PostLike.builder()
                    .post(post)
                    .user(actor)
                    .build();
            postLikeRepository.save(like);
            postRepository.incrementLikeCount(postId);
        }
    }

    @Override
    @Transactional
    public void unlikePost(Long postId, String actorUsername) {
        User actor = getActiveUser(actorUsername);
        getAuthorizedPost(postId, actor);

        if (postLikeRepository.existsByPost_PostIdAndUser_UserId(postId, actor.getUserId())) {
            postLikeRepository.deleteByPost_PostIdAndUser_UserId(postId, actor.getUserId());
            postRepository.decrementLikeCount(postId);
        }
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<PostCommentResponse> getComments(Long postId, int page, int size, String viewerUsername) {
        User viewer = resolveOptionalUser(viewerUsername);
        getAuthorizedPost(postId, viewer);

        if (page < 0 || size < 1) {
            throw new BadRequestException("Thông tin phân trang không hợp lệ");
        }
        Pageable pageable = PageRequest.of(page, Math.min(size, 50));
        Page<PostComment> commentsPage = postCommentRepository.findByPostIdActive(postId, pageable);

        Integer viewerId = viewer != null ? viewer.getUserId() : null;

        List<PostCommentResponse> content = commentsPage.getContent().stream().map(c -> {
            boolean isOwner = viewerId != null && viewerId.equals(c.getUser().getUserId());
            PostAuthorResponse authorResponse = PostAuthorResponse.builder()
                    .userId(c.getUser().getUserId())
                    .handle(c.getUser().getHandle())
                    .username(c.getUser().getUsername())
                    .fullName(c.getUser().getFullName())
                    .avatar(c.getUser().getAvatar())
                    .build();
            return PostCommentResponse.builder()
                    .commentId(c.getPostCommentId())
                    .postId(postId)
                    .content(c.getContent())
                    .author(authorResponse)
                    .isOwner(isOwner)
                    .createdAt(c.getCreatedAt())
                    .updatedAt(c.getUpdatedAt())
                    .build();
        }).toList();

        return PageResponse.<PostCommentResponse>builder()
                .content(content)
                .pageNumber(commentsPage.getNumber())
                .pageSize(commentsPage.getSize())
                .totalElements(commentsPage.getTotalElements())
                .totalPages(commentsPage.getTotalPages())
                .last(commentsPage.isLast())
                .build();
    }

    @Override
    @Transactional
    public PostCommentResponse addComment(Long postId, CreatePostCommentRequest request, String authorUsername) {
        User author = getActiveUser(authorUsername);
        Post post = getAuthorizedPost(postId, author);

        PostComment comment = PostComment.builder()
                .post(post)
                .user(author)
                .content(request.getContent().trim())
                .status(CommentStatus.ACTIVE)
                .build();

        comment = postCommentRepository.save(comment);
        postRepository.incrementCommentCount(postId);

        PostAuthorResponse authorResponse = PostAuthorResponse.builder()
                .userId(author.getUserId())
                .handle(author.getHandle())
                .username(author.getUsername())
                .fullName(author.getFullName())
                .avatar(author.getAvatar())
                .build();

        return PostCommentResponse.builder()
                .commentId(comment.getPostCommentId())
                .postId(postId)
                .content(comment.getContent())
                .author(authorResponse)
                .isOwner(true)
                .createdAt(comment.getCreatedAt())
                .updatedAt(comment.getUpdatedAt())
                .build();
    }

    @Override
    @Transactional
    public PostCommentResponse updateComment(Long postId, Long commentId, UpdatePostCommentRequest request, String authorUsername) {
        User author = getActiveUser(authorUsername);
        getAuthorizedPost(postId, author);

        PostComment comment = postCommentRepository.findById(commentId)
                .orElseThrow(() -> new ResourceNotFoundException("Bình luận không tồn tại"));

        if (!comment.getUser().getUserId().equals(author.getUserId())) {
            throw new ForbiddenException("Bạn không có quyền chỉnh sửa bình luận này");
        }
        if (comment.getStatus() != CommentStatus.ACTIVE) {
            throw new ResourceNotFoundException("Bình luận không tồn tại hoặc đã bị xóa");
        }

        comment.setContent(request.getContent().trim());
        comment.setUpdatedAt(LocalDateTime.now());
        comment = postCommentRepository.save(comment);

        PostAuthorResponse authorResponse = PostAuthorResponse.builder()
                .userId(author.getUserId())
                .handle(author.getHandle())
                .username(author.getUsername())
                .fullName(author.getFullName())
                .avatar(author.getAvatar())
                .build();

        return PostCommentResponse.builder()
                .commentId(comment.getPostCommentId())
                .postId(postId)
                .content(comment.getContent())
                .author(authorResponse)
                .isOwner(true)
                .createdAt(comment.getCreatedAt())
                .updatedAt(comment.getUpdatedAt())
                .build();
    }

    @Override
    @Transactional
    public void deleteComment(Long postId, Long commentId, String actorUsername) {
        User actor = getActiveUser(actorUsername);
        Post post = getAuthorizedPost(postId, actor);

        PostComment comment = postCommentRepository.findById(commentId)
                .orElseThrow(() -> new ResourceNotFoundException("Bình luận không tồn tại"));

        boolean isCommentAuthor = comment.getUser().getUserId().equals(actor.getUserId());
        boolean isPostAuthor = post.getAuthor().getUserId().equals(actor.getUserId());
        boolean isAdmin = actor.getRole() == Role.ADMIN;

        if (!isCommentAuthor && !isPostAuthor && !isAdmin) {
            throw new ForbiddenException("Bạn không có quyền xóa bình luận này");
        }

        comment.setStatus(CommentStatus.DELETED);
        comment.setUpdatedAt(LocalDateTime.now());
        postCommentRepository.save(comment);
        postRepository.decrementCommentCount(postId);
    }

    @Override
    @Transactional
    public PostReportResponse reportPost(Long postId, CreatePostReportRequest request, String reporterUsername) {
        User reporter = getActiveUser(reporterUsername);
        Post post = getAuthorizedPost(postId, reporter);

        if (post.getAuthor().getUserId().equals(reporter.getUserId())) {
            throw new BadRequestException("Bạn không thể tự báo cáo bài viết của chính mình");
        }

        PostReport report = PostReport.builder()
                .post(post)
                .reporter(reporter)
                .reason(request.getReason().trim())
                .details(request.getDetails() != null ? request.getDetails().trim() : null)
                .status(ReportStatus.PENDING)
                .build();

        report = postReportRepository.save(report);

        PostAuthorResponse reporterResponse = PostAuthorResponse.builder()
                .userId(reporter.getUserId())
                .handle(reporter.getHandle())
                .username(reporter.getUsername())
                .fullName(reporter.getFullName())
                .avatar(reporter.getAvatar())
                .build();

        return PostReportResponse.builder()
                .reportId(report.getReportId())
                .postId(postId)
                .reporter(reporterResponse)
                .reason(report.getReason())
                .details(report.getDetails())
                .status(report.getStatus())
                .createdAt(report.getCreatedAt())
                .build();
    }

    // ==================== ADMIN MODERATION ====================

    @Override
    @Transactional(readOnly = true)
    public PageResponse<PostResponse> getAdminPosts(PostStatus status, int page, int size) {
        if (page < 0 || size < 1) {
            throw new BadRequestException("Thông tin phân trang không hợp lệ");
        }
        Pageable pageable = PageRequest.of(page, Math.min(size, 50), Sort.by(Sort.Direction.DESC, "createdAt", "postId"));
        Page<Post> postsPage = status != null ? postRepository.findByStatus(status, pageable) : postRepository.findAll(pageable);

        List<Post> posts = postsPage.getContent();
        if (posts.isEmpty()) {
            return PageResponse.from(postsPage.map(p -> null));
        }

        List<Long> postIds = posts.stream().map(Post::getPostId).toList();
        Map<Long, List<String>> mediaUrlsByPost = new HashMap<>();
        Map<Long, List<Long>> mediaAssetIdsByPost = new HashMap<>();
        List<PostMedia> postMediaList = postMediaRepository.findByPostIdsWithAsset(postIds);
        for (PostMedia pm : postMediaList) {
            Long postId = pm.getPost().getPostId();
            mediaUrlsByPost.computeIfAbsent(postId, k -> new ArrayList<>()).add(pm.getMediaAsset().getSecureUrl());
            mediaAssetIdsByPost.computeIfAbsent(postId, k -> new ArrayList<>()).add(pm.getMediaAsset().getMediaAssetId());
        }

        List<PostResponse> content = posts.stream().map(post -> {
            List<String> urls = mediaUrlsByPost.getOrDefault(post.getPostId(), Collections.emptyList());
            List<Long> assetIds = mediaAssetIdsByPost.getOrDefault(post.getPostId(), Collections.emptyList());
            return toPostResponse(post, urls, assetIds, false, null);
        }).toList();

        return PageResponse.<PostResponse>builder()
                .content(content)
                .pageNumber(postsPage.getNumber())
                .pageSize(postsPage.getSize())
                .totalElements(postsPage.getTotalElements())
                .totalPages(postsPage.getTotalPages())
                .last(postsPage.isLast())
                .build();
    }

    @Override
    @Transactional
    public PostResponse moderatePost(Long postId, ModeratePostRequest request, String adminUsername) {
        User admin = getActiveUser(adminUsername);
        if (admin.getRole() != Role.ADMIN) {
            throw new ForbiddenException("Chỉ quản trị viên mới có quyền kiểm duyệt bài viết");
        }

        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new ResourceNotFoundException("Bài viết không tồn tại"));

        post.setStatus(request.getStatus());
        post.setModeratedAt(LocalDateTime.now());
        post.setModeratedBy(admin);
        post.setModerationReason(request.getModerationReason());
        post = postRepository.save(post);

        List<PostMedia> postMediaList = postMediaRepository.findByPost_PostIdOrderByDisplayOrderAsc(postId);
        List<String> urls = postMediaList.stream().map(pm -> pm.getMediaAsset().getSecureUrl()).toList();
        List<Long> assetIds = postMediaList.stream().map(pm -> pm.getMediaAsset().getMediaAssetId()).toList();

        return toPostResponse(post, urls, assetIds, false, admin.getUserId());
    }

    @Override
    @Transactional
    public void purgePost(Long postId, String adminUsername) {
        User admin = getActiveUser(adminUsername);
        if (admin.getRole() != Role.ADMIN) {
            throw new ForbiddenException("Chỉ quản trị viên mới có quyền xóa vĩnh viễn bài viết");
        }

        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new ResourceNotFoundException("Bài viết không tồn tại"));

        // Ordering Invariant (Section 3.7.4):
        // 1. Find attached media assets and set status to DELETING
        List<PostMedia> mediaList = postMediaRepository.findByPost_PostIdOrderByDisplayOrderAsc(postId);
        for (PostMedia pm : mediaList) {
            MediaAsset asset = pm.getMediaAsset();
            asset.setStatus(MediaAssetStatus.DELETING);
            asset.setUpdatedAt(LocalDateTime.now());
            mediaAssetRepository.save(asset);
        }

        // 2. Delete relations
        postLikeRepository.deleteByPost_PostId(postId);
        postCommentRepository.deleteByPost_PostId(postId);
        postMediaRepository.deleteByPost_PostId(postId);

        // 3. Delete post
        postRepository.delete(post);
        logger.info("Admin {} hard-purged post id={}, marked {} media assets as DELETING", admin.getUsername(), postId, mediaList.size());
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<PostReportResponse> getAdminReports(ReportStatus status, int page, int size) {
        if (page < 0 || size < 1) {
            throw new BadRequestException("Thông tin phân trang không hợp lệ");
        }
        Pageable pageable = PageRequest.of(page, Math.min(size, 50), Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<PostReport> reportsPage = status != null ? postReportRepository.findByStatus(status, pageable) : postReportRepository.findAll(pageable);

        List<PostReportResponse> content = reportsPage.getContent().stream().map(r -> {
            PostAuthorResponse reporter = PostAuthorResponse.builder()
                    .userId(r.getReporter().getUserId())
                    .handle(r.getReporter().getHandle())
                    .username(r.getReporter().getUsername())
                    .fullName(r.getReporter().getFullName())
                    .avatar(r.getReporter().getAvatar())
                    .build();

            PostAuthorResponse resolver = null;
            if (r.getResolvedBy() != null) {
                resolver = PostAuthorResponse.builder()
                        .userId(r.getResolvedBy().getUserId())
                        .handle(r.getResolvedBy().getHandle())
                        .username(r.getResolvedBy().getUsername())
                        .fullName(r.getResolvedBy().getFullName())
                        .avatar(r.getResolvedBy().getAvatar())
                        .build();
            }

            return PostReportResponse.builder()
                    .reportId(r.getReportId())
                    .postId(r.getPost().getPostId())
                    .reporter(reporter)
                    .reason(r.getReason())
                    .details(r.getDetails())
                    .status(r.getStatus())
                    .createdAt(r.getCreatedAt())
                    .resolvedAt(r.getResolvedAt())
                    .resolvedBy(resolver)
                    .build();
        }).toList();

        return PageResponse.<PostReportResponse>builder()
                .content(content)
                .pageNumber(reportsPage.getNumber())
                .pageSize(reportsPage.getSize())
                .totalElements(reportsPage.getTotalElements())
                .totalPages(reportsPage.getTotalPages())
                .last(reportsPage.isLast())
                .build();
    }

    @Override
    @Transactional
    public PostReportResponse resolveReport(Long reportId, ReportStatus resolution, String adminUsername) {
        User admin = getActiveUser(adminUsername);
        if (admin.getRole() != Role.ADMIN) {
            throw new ForbiddenException("Chỉ quản trị viên mới có quyền xử lý báo cáo");
        }

        PostReport report = postReportRepository.findById(reportId)
                .orElseThrow(() -> new ResourceNotFoundException("Báo cáo không tồn tại"));

        report.setStatus(resolution);
        report.setResolvedAt(LocalDateTime.now());
        report.setResolvedBy(admin);
        report = postReportRepository.save(report);

        PostAuthorResponse reporter = PostAuthorResponse.builder()
                .userId(report.getReporter().getUserId())
                .handle(report.getReporter().getHandle())
                .username(report.getReporter().getUsername())
                .fullName(report.getReporter().getFullName())
                .avatar(report.getReporter().getAvatar())
                .build();

        PostAuthorResponse resolver = PostAuthorResponse.builder()
                .userId(admin.getUserId())
                .handle(admin.getHandle())
                .username(admin.getUsername())
                .fullName(admin.getFullName())
                .avatar(admin.getAvatar())
                .build();

        return PostReportResponse.builder()
                .reportId(report.getReportId())
                .postId(report.getPost().getPostId())
                .reporter(reporter)
                .reason(report.getReason())
                .details(report.getDetails())
                .status(report.getStatus())
                .createdAt(report.getCreatedAt())
                .resolvedAt(report.getResolvedAt())
                .resolvedBy(resolver)
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<MediaAssetResponse> getAdminMediaAssets(MediaAssetStatus status, boolean deadLetterOnly, int page, int size) {
        if (page < 0 || size < 1) {
            throw new BadRequestException("Thông tin phân trang không hợp lệ");
        }
        Pageable pageable = PageRequest.of(page, Math.min(size, 50), Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<MediaAsset> pageResult;
        if (deadLetterOnly) {
            pageResult = mediaAssetRepository.findByDeadLetteredAtIsNotNull(pageable);
        } else if (status != null) {
            pageResult = mediaAssetRepository.findByStatus(status, pageable);
        } else {
            pageResult = mediaAssetRepository.findAll(pageable);
        }

        List<MediaAssetResponse> content = pageResult.getContent().stream().map(a -> MediaAssetResponse.builder()
                .mediaAssetId(a.getMediaAssetId())
                .uploadedByUserId(a.getUploadedBy().getUserId())
                .uploadedByUsername(a.getUploadedBy().getUsername())
                .cloudinaryPublicId(a.getCloudinaryPublicId())
                .secureUrl(a.getSecureUrl())
                .mediaType(a.getMediaType())
                .status(a.getStatus())
                .claimToken(a.getClaimToken())
                .lockedAt(a.getLockedAt())
                .lockedBy(a.getLockedBy())
                .retryCount(a.getRetryCount())
                .nextRetryAt(a.getNextRetryAt())
                .deadLetteredAt(a.getDeadLetteredAt())
                .lastError(a.getLastError())
                .createdAt(a.getCreatedAt())
                .updatedAt(a.getUpdatedAt())
                .build()).toList();

        return PageResponse.<MediaAssetResponse>builder()
                .content(content)
                .pageNumber(pageResult.getNumber())
                .pageSize(pageResult.getSize())
                .totalElements(pageResult.getTotalElements())
                .totalPages(pageResult.getTotalPages())
                .last(pageResult.isLast())
                .build();
    }

    @Override
    @Transactional
    public void retryMediaAsset(Long mediaAssetId, String adminUsername) {
        User admin = getActiveUser(adminUsername);
        if (admin.getRole() != Role.ADMIN) {
            throw new ForbiddenException("Chỉ quản trị viên mới có quyền kích hoạt retry media");
        }

        MediaAsset asset = mediaAssetRepository.findById(mediaAssetId)
                .orElseThrow(() -> new ResourceNotFoundException("Tệp phương tiện không tồn tại"));

        asset.setDeadLetteredAt(null);
        asset.setRetryCount(0);
        asset.setNextRetryAt(LocalDateTime.now());
        asset.setLastError(null);
        asset.setClaimToken(null);
        asset.setLockedAt(null);
        asset.setLockedBy(null);
        asset.setUpdatedAt(LocalDateTime.now());
        mediaAssetRepository.save(asset);
        logger.info("Admin {} reset retry on media asset id={}", admin.getUsername(), mediaAssetId);
    }

    // ==================== HELPER METHODS ====================

    private User getActiveUser(String username) {
        if (username == null || username.isBlank()) {
            throw new UnauthorizedException("Bạn cần đăng nhập");
        }
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new UnauthorizedException("Phiên đăng nhập không hợp lệ"));
        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new ForbiddenException("Tài khoản của bạn đang tạm khóa hoặc chưa được kích hoạt");
        }
        return user;
    }

    private User resolveOptionalUser(String username) {
        if (username == null || username.isBlank()) {
            return null;
        }
        return userRepository.findByUsername(username).orElse(null);
    }

    private Post getAuthorizedPost(Long postId, User viewer) {
        Post post = postRepository.findByIdWithDetails(postId)
                .orElseThrow(() -> new ResourceNotFoundException("Bài viết không tồn tại"));

        if (post.getStatus() != PostStatus.ACTIVE) {
            throw new ResourceNotFoundException("Bài viết không tồn tại");
        }
        if (post.getAuthor().getStatus() != UserStatus.ACTIVE) {
            throw new ResourceNotFoundException("Bài viết không tồn tại");
        }

        if (post.getVisibility() == PostVisibility.PRIVATE) {
            if (viewer == null || !viewer.getUserId().equals(post.getAuthor().getUserId())) {
                throw new ResourceNotFoundException("Bài viết không tồn tại");
            }
        } else if (post.getVisibility() == PostVisibility.FRIENDS) {
            if (viewer == null) {
                throw new ForbiddenException("Bài viết này chỉ dành cho bạn bè");
            }
            if (!viewer.getUserId().equals(post.getAuthor().getUserId())) {
                Integer lowId = Math.min(viewer.getUserId(), post.getAuthor().getUserId());
                Integer highId = Math.max(viewer.getUserId(), post.getAuthor().getUserId());
                boolean isFriend = friendshipRepository.findByUserLow_UserIdAndUserHigh_UserId(lowId, highId)
                        .map(f -> f.getStatus() == FriendshipStatus.ACCEPTED).orElse(false);
                if (!isFriend) {
                    throw new ForbiddenException("Bài viết này chỉ dành cho bạn bè");
                }
            }
        }
        return post;
    }

    private PostResponse toPostResponse(Post post, List<String> mediaUrls, List<Long> mediaAssetIds, boolean isLikedByMe, Integer viewerUserId) {
        PostAuthorResponse authorResponse = PostAuthorResponse.builder()
                .userId(post.getAuthor().getUserId())
                .handle(post.getAuthor().getHandle())
                .username(post.getAuthor().getUsername())
                .fullName(post.getAuthor().getFullName())
                .avatar(post.getAuthor().getAvatar())
                .build();

        PostItineraryAttachmentResult itineraryResult = resolveItineraryAttachment(post.getItinerary());
        boolean isOwner = viewerUserId != null && viewerUserId.equals(post.getAuthor().getUserId());

        return PostResponse.builder()
                .postId(post.getPostId())
                .content(post.getContent())
                .author(authorResponse)
                .mediaUrls(mediaUrls != null ? mediaUrls : Collections.emptyList())
                .mediaAssetIds(mediaAssetIds != null ? mediaAssetIds : Collections.emptyList())
                .itinerary(itineraryResult.response())
                .itineraryUnavailable(itineraryResult.unavailable())
                .itineraryUnavailableReason(itineraryResult.unavailableReason())
                .visibility(post.getVisibility())
                .status(post.getStatus())
                .likeCount(post.getLikeCount() != null ? post.getLikeCount() : 0)
                .commentCount(post.getCommentCount() != null ? post.getCommentCount() : 0)
                .isLikedByMe(isLikedByMe)
                .isOwner(isOwner)
                .createdAt(post.getCreatedAt())
                .updatedAt(post.getUpdatedAt())
                .build();
    }

    private PostItineraryAttachmentResult resolveItineraryAttachment(Itinerary itinerary) {
        if (itinerary == null) {
            return new PostItineraryAttachmentResult(null, false, null);
        }

        // Section 6.1 Independent Identity Principle & Privacy Check
        if (itinerary.getVisibility() == Visibility.PUBLIC
                && itinerary.getStatus() == ItineraryStatus.ACTIVE
                && itinerary.getUser() != null
                && itinerary.getUser().getStatus() == UserStatus.ACTIVE) {

            User owner = itinerary.getUser();
            PostAuthorResponse ownerResponse = PostAuthorResponse.builder()
                    .userId(owner.getUserId())
                    .handle(owner.getHandle())
                    .username(owner.getUsername())
                    .fullName(owner.getFullName())
                    .avatar(owner.getAvatar())
                    .build();

            PostItineraryAttachmentResponse dto = PostItineraryAttachmentResponse.builder()
                    .itineraryId(itinerary.getItineraryId())
                    .title(itinerary.getTitle())
                    .coverImage(itinerary.getCoverImage())
                    .totalDays(itinerary.getTotalDays())
                    .budget(itinerary.getBudget())
                    .location(itinerary.getLocation())
                    .averageRating(null)
                    .owner(ownerResponse)
                    .build();

            return new PostItineraryAttachmentResult(dto, false, null);
        } else {
            logger.info("Attached itinerary id={} is unavailable to public viewers (visibility={}, status={}, ownerStatus={})",
                    itinerary.getItineraryId(),
                    itinerary.getVisibility(),
                    itinerary.getStatus(),
                    itinerary.getUser() != null ? itinerary.getUser().getStatus() : "null");
            // Section 6.2 Generic Reason Code: Airtight privacy, zero metadata leaked
            return new PostItineraryAttachmentResult(null, true, "UNAVAILABLE");
        }
    }

    private record PostItineraryAttachmentResult(
            PostItineraryAttachmentResponse response,
            boolean unavailable,
            String unavailableReason) {
    }
}

