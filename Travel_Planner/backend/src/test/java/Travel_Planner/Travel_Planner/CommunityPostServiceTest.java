package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.*;
import Travel_Planner.Travel_Planner.dto.response.*;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ConflictException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.service.impl.MediaCleanupService;
import Travel_Planner.Travel_Planner.service.impl.PostServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;

import java.time.LocalDateTime;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CommunityPostServiceTest {

    @Mock
    private PostRepository postRepository;
    @Mock
    private MediaAssetRepository mediaAssetRepository;
    @Mock
    private PostMediaRepository postMediaRepository;
    @Mock
    private PostLikeRepository postLikeRepository;
    @Mock
    private PostCommentRepository postCommentRepository;
    @Mock
    private PostReportRepository postReportRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private ItineraryRepository itineraryRepository;
    @Mock
    private FriendshipRepository friendshipRepository;

    private PostServiceImpl postService;

    private User activeUser;
    private User inactiveUser;
    private User otherUser;
    private User adminUser;

    @BeforeEach
    void setUp() {
        postService = new PostServiceImpl(
                postRepository,
                mediaAssetRepository,
                postMediaRepository,
                postLikeRepository,
                postCommentRepository,
                postReportRepository,
                userRepository,
                itineraryRepository,
                friendshipRepository
        );

        activeUser = User.builder()
                .userId(1)
                .username("active_user")
                .handle("active_u")
                .fullName("Active User")
                .status(UserStatus.ACTIVE)
                .role(Role.USER)
                .build();

        inactiveUser = User.builder()
                .userId(2)
                .username("inactive_user")
                .handle("inactive_u")
                .fullName("Inactive User")
                .status(UserStatus.INACTIVE)
                .role(Role.USER)
                .build();

        otherUser = User.builder()
                .userId(3)
                .username("other_user")
                .handle("other_u")
                .fullName("Other User")
                .status(UserStatus.ACTIVE)
                .role(Role.USER)
                .build();

        adminUser = User.builder()
                .userId(99)
                .username("admin_user")
                .handle("admin_u")
                .fullName("Admin")
                .status(UserStatus.ACTIVE)
                .role(Role.ADMIN)
                .build();
    }

    @Test
    @DisplayName("Create post successfully with valid text and mediaAssetIds")
    void createPost_success() {
        when(userRepository.findByUsername("active_user")).thenReturn(Optional.of(activeUser));

        MediaAsset asset1 = MediaAsset.builder()
                .mediaAssetId(101L)
                .uploadedBy(activeUser)
                .cloudinaryPublicId("cloud_101")
                .secureUrl("https://cloudinary.com/101.jpg")
                .status(MediaAssetStatus.UNATTACHED)
                .build();

        when(mediaAssetRepository.findByIdsForUpdate(List.of(101L))).thenReturn(List.of(asset1));
        when(postRepository.save(any(Post.class))).thenAnswer(invocation -> {
            Post p = invocation.getArgument(0);
            p.setPostId(501L);
            p.setCreatedAt(LocalDateTime.now());
            p.setUpdatedAt(LocalDateTime.now());
            return p;
        });

        CreatePostRequest request = CreatePostRequest.builder()
                .content("Hành trình khám phá Tây Bắc")
                .visibility(PostVisibility.PUBLIC)
                .mediaAssetIds(List.of(101L))
                .build();

        PostResponse response = postService.createPost(request, "active_user");

        assertNotNull(response);
        assertEquals(501L, response.getPostId());
        assertEquals("Hành trình khám phá Tây Bắc", response.getContent());
        assertEquals(1, response.getMediaUrls().size());
        assertEquals("https://cloudinary.com/101.jpg", response.getMediaUrls().get(0));
        assertEquals(MediaAssetStatus.ATTACHED, asset1.getStatus());
        verify(postMediaRepository).save(any(PostMedia.class));
    }

    @Test
    @DisplayName("Create post rejects duplicate mediaAssetIds with 400 Bad Request")
    void createPost_duplicateMediaIds_throws400() {
        when(userRepository.findByUsername("active_user")).thenReturn(Optional.of(activeUser));

        CreatePostRequest request = CreatePostRequest.builder()
                .content("Test duplicate")
                .mediaAssetIds(List.of(101L, 101L))
                .build();

        BadRequestException ex = assertThrows(BadRequestException.class,
                () -> postService.createPost(request, "active_user"));
        assertEquals("Danh sách ảnh chứa định danh trùng lặp", ex.getMessage());
    }

    @Test
    @DisplayName("Create post rejects more than 5 mediaAssetIds with 400 Bad Request")
    void createPost_moreThanFiveMediaIds_throws400() {
        when(userRepository.findByUsername("active_user")).thenReturn(Optional.of(activeUser));

        CreatePostRequest request = CreatePostRequest.builder()
                .content("Test max 5")
                .mediaAssetIds(List.of(1L, 2L, 3L, 4L, 5L, 6L))
                .build();

        BadRequestException ex = assertThrows(BadRequestException.class,
                () -> postService.createPost(request, "active_user"));
        assertEquals("Vượt quá giới hạn tối đa 5 ảnh", ex.getMessage());
    }

    @Test
    @DisplayName("Create post with non-existent mediaAssetId throws 404 Not Found")
    void createPost_nonExistentMediaId_throws404() {
        when(userRepository.findByUsername("active_user")).thenReturn(Optional.of(activeUser));
        when(mediaAssetRepository.findByIdsForUpdate(List.of(999L))).thenReturn(Collections.emptyList());

        CreatePostRequest request = CreatePostRequest.builder()
                .content("Test missing")
                .mediaAssetIds(List.of(999L))
                .build();

        ResourceNotFoundException ex = assertThrows(ResourceNotFoundException.class,
                () -> postService.createPost(request, "active_user"));
        assertEquals("Tệp phương tiện không tồn tại", ex.getMessage());
    }

    @Test
    @DisplayName("Create post with unowned mediaAssetId throws 404 Not Found (Anti-Enumeration)")
    void createPost_unownedMediaId_throws404AntiEnumeration() {
        when(userRepository.findByUsername("active_user")).thenReturn(Optional.of(activeUser));

        MediaAsset otherAsset = MediaAsset.builder()
                .mediaAssetId(202L)
                .uploadedBy(otherUser)
                .cloudinaryPublicId("cloud_202")
                .secureUrl("https://cloudinary.com/202.jpg")
                .status(MediaAssetStatus.UNATTACHED)
                .build();

        when(mediaAssetRepository.findByIdsForUpdate(List.of(202L))).thenReturn(List.of(otherAsset));

        CreatePostRequest request = CreatePostRequest.builder()
                .content("Attempting unowned asset")
                .mediaAssetIds(List.of(202L))
                .build();

        ResourceNotFoundException ex = assertThrows(ResourceNotFoundException.class,
                () -> postService.createPost(request, "active_user"));
        assertEquals("Tệp phương tiện không tồn tại hoặc bạn không có quyền truy cập", ex.getMessage());
    }

    @Test
    @DisplayName("Create post with already ATTACHED asset throws 409 Conflict")
    void createPost_alreadyAttached_throws409() {
        when(userRepository.findByUsername("active_user")).thenReturn(Optional.of(activeUser));

        MediaAsset attachedAsset = MediaAsset.builder()
                .mediaAssetId(303L)
                .uploadedBy(activeUser)
                .cloudinaryPublicId("cloud_303")
                .secureUrl("https://cloudinary.com/303.jpg")
                .status(MediaAssetStatus.ATTACHED)
                .build();

        when(mediaAssetRepository.findByIdsForUpdate(List.of(303L))).thenReturn(List.of(attachedAsset));

        CreatePostRequest request = CreatePostRequest.builder()
                .content("Test attached conflict")
                .mediaAssetIds(List.of(303L))
                .build();

        ConflictException ex = assertThrows(ConflictException.class,
                () -> postService.createPost(request, "active_user"));
        assertEquals("Tệp phương tiện đã được sử dụng trong bài viết khác", ex.getMessage());
    }

    @Test
    @DisplayName("Create post with DELETING or DELETED asset throws 409 Conflict")
    void createPost_deletingAsset_throws409() {
        when(userRepository.findByUsername("active_user")).thenReturn(Optional.of(activeUser));

        MediaAsset deletingAsset = MediaAsset.builder()
                .mediaAssetId(404L)
                .uploadedBy(activeUser)
                .cloudinaryPublicId("cloud_404")
                .secureUrl("https://cloudinary.com/404.jpg")
                .status(MediaAssetStatus.DELETING)
                .build();

        when(mediaAssetRepository.findByIdsForUpdate(List.of(404L))).thenReturn(List.of(deletingAsset));

        CreatePostRequest request = CreatePostRequest.builder()
                .content("Test deleting conflict")
                .mediaAssetIds(List.of(404L))
                .build();

        ConflictException ex = assertThrows(ConflictException.class,
                () -> postService.createPost(request, "active_user"));
        assertEquals("Tệp phương tiện đang được xóa hoặc không còn khả dụng", ex.getMessage());
    }

    @Test
    @DisplayName("Create post by INACTIVE user throws 403 Forbidden")
    void createPost_inactiveUser_throws403() {
        when(userRepository.findByUsername("inactive_user")).thenReturn(Optional.of(inactiveUser));

        CreatePostRequest request = CreatePostRequest.builder()
                .content("Inactive trying to post")
                .build();

        ForbiddenException ex = assertThrows(ForbiddenException.class,
                () -> postService.createPost(request, "inactive_user"));
        assertEquals("Tài khoản của bạn đang tạm khóa hoặc chưa được kích hoạt", ex.getMessage());
    }

    @Test
    @DisplayName("Create post - Case 1: Text only without media or itinerary succeeds")
    void createPost_case1_textOnly_success() {
        when(userRepository.findByUsername("active_user")).thenReturn(Optional.of(activeUser));
        when(postRepository.save(any(Post.class))).thenAnswer(invocation -> {
            Post p = invocation.getArgument(0);
            p.setPostId(701L);
            p.setCreatedAt(LocalDateTime.now());
            p.setUpdatedAt(LocalDateTime.now());
            return p;
        });

        CreatePostRequest request = CreatePostRequest.builder()
                .content("Cảm nhận chuyến đi Đà Lạt tuyệt vời!")
                .visibility(PostVisibility.PUBLIC)
                .build();

        PostResponse response = postService.createPost(request, "active_user");

        assertNotNull(response);
        assertEquals(701L, response.getPostId());
        assertEquals("Cảm nhận chuyến đi Đà Lạt tuyệt vời!", response.getContent());
        assertTrue(response.getMediaUrls().isEmpty());
        assertNull(response.getItinerary());
        verifyNoInteractions(mediaAssetRepository);
    }

    @Test
    @DisplayName("Create post - Case 2: Images only without text content succeeds")
    void createPost_case2_imagesOnly_success() {
        when(userRepository.findByUsername("active_user")).thenReturn(Optional.of(activeUser));

        MediaAsset asset = MediaAsset.builder()
                .mediaAssetId(102L)
                .uploadedBy(activeUser)
                .cloudinaryPublicId("cloud_102")
                .secureUrl("https://cloudinary.com/102.jpg")
                .status(MediaAssetStatus.UNATTACHED)
                .build();

        when(mediaAssetRepository.findByIdsForUpdate(List.of(102L))).thenReturn(List.of(asset));
        when(postRepository.save(any(Post.class))).thenAnswer(invocation -> {
            Post p = invocation.getArgument(0);
            p.setPostId(702L);
            p.setCreatedAt(LocalDateTime.now());
            p.setUpdatedAt(LocalDateTime.now());
            return p;
        });

        CreatePostRequest request = CreatePostRequest.builder()
                .mediaAssetIds(List.of(102L))
                .visibility(PostVisibility.PUBLIC)
                .build();

        PostResponse response = postService.createPost(request, "active_user");

        assertNotNull(response);
        assertEquals(702L, response.getPostId());
        assertEquals(1, response.getMediaUrls().size());
        assertEquals("https://cloudinary.com/102.jpg", response.getMediaUrls().get(0));
        assertEquals(MediaAssetStatus.ATTACHED, asset.getStatus());
    }

    @Test
    @DisplayName("Create post - Case 4: Text + images + attached valid public active itinerary succeeds")
    void createPost_case4_textAndImagesAndItinerary_success() {
        when(userRepository.findByUsername("active_user")).thenReturn(Optional.of(activeUser));

        MediaAsset asset = MediaAsset.builder()
                .mediaAssetId(103L)
                .uploadedBy(activeUser)
                .cloudinaryPublicId("cloud_103")
                .secureUrl("https://cloudinary.com/103.jpg")
                .status(MediaAssetStatus.UNATTACHED)
                .build();

        Itinerary itinerary = Itinerary.builder()
                .itineraryId(900)
                .user(activeUser)
                .title("Lịch trình Đà Nẵng 4N3D")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .totalDays(4)
                .build();

        when(mediaAssetRepository.findByIdsForUpdate(List.of(103L))).thenReturn(List.of(asset));
        when(itineraryRepository.findById(900)).thenReturn(Optional.of(itinerary));
        when(postRepository.save(any(Post.class))).thenAnswer(invocation -> {
            Post p = invocation.getArgument(0);
            p.setPostId(704L);
            p.setCreatedAt(LocalDateTime.now());
            p.setUpdatedAt(LocalDateTime.now());
            return p;
        });

        CreatePostRequest request = CreatePostRequest.builder()
                .content("Mọi người tham khảo lịch trình này nhé!")
                .mediaAssetIds(List.of(103L))
                .itineraryId(900)
                .visibility(PostVisibility.PUBLIC)
                .build();

        PostResponse response = postService.createPost(request, "active_user");

        assertNotNull(response);
        assertEquals(704L, response.getPostId());
        assertEquals(1, response.getMediaUrls().size());
        assertNotNull(response.getItinerary());
        assertEquals(900, response.getItinerary().getItineraryId());
        assertEquals("Lịch trình Đà Nẵng 4N3D", response.getItinerary().getTitle());
    }

    @Test
    @DisplayName("Create post rejects empty post (no content, no media, no itinerary) with 400 Bad Request")
    void createPost_emptyPost_throws400() {
        when(userRepository.findByUsername("active_user")).thenReturn(Optional.of(activeUser));

        CreatePostRequest request = CreatePostRequest.builder()
                .content("   ")
                .build();

        BadRequestException ex = assertThrows(BadRequestException.class,
                () -> postService.createPost(request, "active_user"));
        assertEquals("Bài viết phải có ít nhất nội dung văn bản, ảnh hoặc lịch trình", ex.getMessage());
    }

    @Test
    @DisplayName("Public feed multi-query returns posts with media in display order and like state")
    void getPublicFeed_multiQueryStrategy_success() {
        Post post1 = Post.builder()
                .postId(100L)
                .author(activeUser)
                .content("Post 1")
                .visibility(PostVisibility.PUBLIC)
                .status(PostStatus.ACTIVE)
                .likeCount(5)
                .commentCount(2)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        when(userRepository.findByUsername("active_user")).thenReturn(Optional.of(activeUser));
        when(postRepository.findPublicFeed(any(Pageable.class))).thenReturn(new PageImpl<>(List.of(post1)));

        MediaAsset ma1 = MediaAsset.builder().mediaAssetId(1L).secureUrl("https://res.cloudinary.com/img1.jpg").build();
        MediaAsset ma2 = MediaAsset.builder().mediaAssetId(2L).secureUrl("https://res.cloudinary.com/img2.jpg").build();

        PostMedia pm1 = PostMedia.builder().post(post1).mediaAsset(ma1).displayOrder(0).build();
        PostMedia pm2 = PostMedia.builder().post(post1).mediaAsset(ma2).displayOrder(1).build();

        when(postMediaRepository.findByPostIdsWithAsset(List.of(100L))).thenReturn(List.of(pm1, pm2));
        when(postLikeRepository.findLikedPostIds(List.of(100L), 1)).thenReturn(List.of(100L));

        PageResponse<PostResponse> feed = postService.getPublicFeed(0, 10, "active_user");

        assertEquals(1, feed.getContent().size());
        PostResponse item = feed.getContent().get(0);
        assertEquals(100L, item.getPostId());
        assertEquals(2, item.getMediaUrls().size());
        assertEquals("https://res.cloudinary.com/img1.jpg", item.getMediaUrls().get(0));
        assertEquals("https://res.cloudinary.com/img2.jpg", item.getMediaUrls().get(1));
        assertTrue(item.isLikedByMe());
        assertTrue(item.isOwner());
    }

    @Test
    @DisplayName("Attached Itinerary privacy: renders full card when PUBLIC and ACTIVE")
    void attachedItinerary_publicAndActive_rendersCard() {
        Itinerary itinerary = Itinerary.builder()
                .itineraryId(10)
                .user(otherUser)
                .title("Chuyến đi Đà Lạt")
                .coverImage("https://img.com/dalat.jpg")
                .totalDays(3)
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .build();

        Post post = Post.builder()
                .postId(200L)
                .author(activeUser)
                .itinerary(itinerary)
                .content("Chia sẻ lịch trình")
                .visibility(PostVisibility.PUBLIC)
                .status(PostStatus.ACTIVE)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        when(postRepository.findByIdWithDetails(200L)).thenReturn(Optional.of(post));
        when(postMediaRepository.findByPost_PostIdOrderByDisplayOrderAsc(200L)).thenReturn(Collections.emptyList());

        PostResponse response = postService.getPostById(200L, null);

        assertNotNull(response.getItinerary());
        assertEquals("Chuyến đi Đà Lạt", response.getItinerary().getTitle());
        assertEquals(3, response.getItinerary().getTotalDays());
        assertEquals(3, response.getItinerary().getOwner().getUserId());
        assertFalse(response.isItineraryUnavailable());
        assertNull(response.getItineraryUnavailableReason());
    }

    @Test
    @DisplayName("Attached Itinerary privacy: returns UNAVAILABLE when itinerary is PRIVATE or DELETED")
    void attachedItinerary_privateOrDeleted_returnsUnavailableFallback() {
        Itinerary privateItinerary = Itinerary.builder()
                .itineraryId(20)
                .user(otherUser)
                .title("Lịch trình bí mật")
                .visibility(Visibility.PRIVATE)
                .status(ItineraryStatus.ACTIVE)
                .build();

        Post post = Post.builder()
                .postId(201L)
                .author(activeUser)
                .itinerary(privateItinerary)
                .content("Chia sẻ lịch trình bí mật")
                .visibility(PostVisibility.PUBLIC)
                .status(PostStatus.ACTIVE)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        when(postRepository.findByIdWithDetails(201L)).thenReturn(Optional.of(post));
        when(postMediaRepository.findByPost_PostIdOrderByDisplayOrderAsc(201L)).thenReturn(Collections.emptyList());

        PostResponse response = postService.getPostById(201L, null);

        assertNull(response.getItinerary());
        assertTrue(response.isItineraryUnavailable());
        assertEquals("UNAVAILABLE", response.getItineraryUnavailableReason());
    }

    @Test
    @DisplayName("FRIENDS post allows mutual friend, rejects non-friend with 403 Forbidden")
    void getPostById_friendsVisibility() {
        Post friendsPost = Post.builder()
                .postId(300L)
                .author(activeUser)
                .content("Chỉ bạn bè thấy")
                .visibility(PostVisibility.FRIENDS)
                .status(PostStatus.ACTIVE)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        when(userRepository.findByUsername("other_user")).thenReturn(Optional.of(otherUser));
        when(postRepository.findByIdWithDetails(300L)).thenReturn(Optional.of(friendsPost));

        // When not friends:
        when(friendshipRepository.findByUserLow_UserIdAndUserHigh_UserId(1, 3)).thenReturn(Optional.empty());

        ForbiddenException ex = assertThrows(ForbiddenException.class,
                () -> postService.getPostById(300L, "other_user"));
        assertEquals("Bài viết này chỉ dành cho bạn bè", ex.getMessage());

        // When mutual friends:
        Friendship mutual = new Friendship();
        mutual.setStatus(FriendshipStatus.ACCEPTED);
        when(friendshipRepository.findByUserLow_UserIdAndUserHigh_UserId(1, 3)).thenReturn(Optional.of(mutual));
        when(postMediaRepository.findByPost_PostIdOrderByDisplayOrderAsc(300L)).thenReturn(Collections.emptyList());
        when(postLikeRepository.existsByPost_PostIdAndUser_UserId(300L, 3)).thenReturn(false);

        PostResponse response = postService.getPostById(300L, "other_user");
        assertNotNull(response);
        assertEquals("Chỉ bạn bè thấy", response.getContent());
    }

    @Test
    @DisplayName("PRIVATE post only visible to author, returns 404 Not Found to other users")
    void getPostById_privateVisibility_antiEnumeration() {
        Post privatePost = Post.builder()
                .postId(400L)
                .author(activeUser)
                .content("Nhật ký riêng tư")
                .visibility(PostVisibility.PRIVATE)
                .status(PostStatus.ACTIVE)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        when(userRepository.findByUsername("other_user")).thenReturn(Optional.of(otherUser));
        when(postRepository.findByIdWithDetails(400L)).thenReturn(Optional.of(privatePost));

        ResourceNotFoundException ex = assertThrows(ResourceNotFoundException.class,
                () -> postService.getPostById(400L, "other_user"));
        assertEquals("Bài viết không tồn tại", ex.getMessage());
    }

    @Test
    @DisplayName("Like post is idempotent and increments like count")
    void likePost_idempotent() {
        Post post = Post.builder()
                .postId(500L)
                .author(otherUser)
                .visibility(PostVisibility.PUBLIC)
                .status(PostStatus.ACTIVE)
                .likeCount(0)
                .build();

        when(userRepository.findByUsername("active_user")).thenReturn(Optional.of(activeUser));
        when(postRepository.findByIdWithDetails(500L)).thenReturn(Optional.of(post));
        when(postLikeRepository.existsByPost_PostIdAndUser_UserId(500L, 1)).thenReturn(false);

        postService.likePost(500L, "active_user");

        verify(postLikeRepository).save(any(PostLike.class));
        verify(postRepository).incrementLikeCount(500L);

        // Second call when already liked:
        when(postLikeRepository.existsByPost_PostIdAndUser_UserId(500L, 1)).thenReturn(true);
        postService.likePost(500L, "active_user");
        verify(postRepository, times(1)).incrementLikeCount(500L); // Still 1 time!
    }

    @Test
    @DisplayName("Unlike post is idempotent and decrements like count")
    void unlikePost_idempotent() {
        Post post = Post.builder()
                .postId(500L)
                .author(otherUser)
                .visibility(PostVisibility.PUBLIC)
                .status(PostStatus.ACTIVE)
                .likeCount(1)
                .build();

        when(userRepository.findByUsername("active_user")).thenReturn(Optional.of(activeUser));
        when(postRepository.findByIdWithDetails(500L)).thenReturn(Optional.of(post));
        when(postLikeRepository.existsByPost_PostIdAndUser_UserId(500L, 1)).thenReturn(true);

        postService.unlikePost(500L, "active_user");

        verify(postLikeRepository).deleteByPost_PostIdAndUser_UserId(500L, 1);
        verify(postRepository).decrementLikeCount(500L);
    }

    @Test
    @DisplayName("Flat comments: addComment saves comment and increments count")
    void addComment_flatComment_success() {
        Post post = Post.builder()
                .postId(600L)
                .author(otherUser)
                .visibility(PostVisibility.PUBLIC)
                .status(PostStatus.ACTIVE)
                .commentCount(0)
                .build();

        when(userRepository.findByUsername("active_user")).thenReturn(Optional.of(activeUser));
        when(postRepository.findByIdWithDetails(600L)).thenReturn(Optional.of(post));
        when(postCommentRepository.save(any(PostComment.class))).thenAnswer(inv -> {
            PostComment c = inv.getArgument(0);
            c.setPostCommentId(701L);
            c.setCreatedAt(LocalDateTime.now());
            c.setUpdatedAt(LocalDateTime.now());
            return c;
        });

        CreatePostCommentRequest request = new CreatePostCommentRequest("Thật là một hành trình thú vị!");
        PostCommentResponse response = postService.addComment(600L, request, "active_user");

        assertNotNull(response);
        assertEquals(701L, response.getCommentId());
        assertEquals("Thật là một hành trình thú vị!", response.getContent());
        verify(postRepository).incrementCommentCount(600L);
    }

    @Test
    @DisplayName("Soft delete post: marks status DELETED and keeps media ATTACHED")
    void deletePost_softDelete_preservesMedia() {
        Post post = Post.builder()
                .postId(700L)
                .author(activeUser)
                .status(PostStatus.ACTIVE)
                .build();

        when(userRepository.findByUsername("active_user")).thenReturn(Optional.of(activeUser));
        when(postRepository.findById(700L)).thenReturn(Optional.of(post));

        postService.deletePost(700L, "active_user");

        assertEquals(PostStatus.DELETED, post.getStatus());
        assertNotNull(post.getDeletedAt());
        verify(postRepository).save(post);
        verifyNoInteractions(mediaAssetRepository);
    }

    @Test
    @DisplayName("Admin hard-purge post cascades attached media to DELETING")
    void purgePost_adminHardPurge_cascadesMediaToDeleting() {
        when(userRepository.findByUsername("admin_user")).thenReturn(Optional.of(adminUser));

        Post post = Post.builder()
                .postId(800L)
                .author(activeUser)
                .status(PostStatus.DELETED)
                .build();

        when(postRepository.findById(800L)).thenReturn(Optional.of(post));

        MediaAsset asset = MediaAsset.builder()
                .mediaAssetId(900L)
                .status(MediaAssetStatus.ATTACHED)
                .build();

        PostMedia pm = PostMedia.builder()
                .post(post)
                .mediaAsset(asset)
                .displayOrder(0)
                .build();

        when(postMediaRepository.findByPost_PostIdOrderByDisplayOrderAsc(800L)).thenReturn(List.of(pm));

        postService.purgePost(800L, "admin_user");

        assertEquals(MediaAssetStatus.DELETING, asset.getStatus());
        verify(mediaAssetRepository).save(asset);
        verify(postLikeRepository).deleteByPost_PostId(800L);
        verify(postCommentRepository).deleteByPost_PostId(800L);
        verify(postMediaRepository).deleteByPost_PostId(800L);
        verify(postRepository).delete(post);
    }

    @Test
    @DisplayName("Admin report post and resolution")
    void reportAndResolvePost_success() {
        Post post = Post.builder()
                .postId(900L)
                .author(otherUser)
                .visibility(PostVisibility.PUBLIC)
                .status(PostStatus.ACTIVE)
                .build();

        when(userRepository.findByUsername("active_user")).thenReturn(Optional.of(activeUser));
        when(postRepository.findByIdWithDetails(900L)).thenReturn(Optional.of(post));
        when(postReportRepository.save(any(PostReport.class))).thenAnswer(inv -> {
            PostReport r = inv.getArgument(0);
            r.setReportId(11L);
            r.setCreatedAt(LocalDateTime.now());
            return r;
        });

        CreatePostReportRequest request = new CreatePostReportRequest("Spam", "Nội dung quảng cáo sai sự thật");
        PostReportResponse reportResponse = postService.reportPost(900L, request, "active_user");

        assertNotNull(reportResponse);
        assertEquals(11L, reportResponse.getReportId());
        assertEquals("Spam", reportResponse.getReason());
        assertEquals(ReportStatus.PENDING, reportResponse.getStatus());

        // Admin resolve
        when(userRepository.findByUsername("admin_user")).thenReturn(Optional.of(adminUser));
        PostReport savedReport = PostReport.builder()
                .reportId(11L)
                .post(post)
                .reporter(activeUser)
                .reason("Spam")
                .status(ReportStatus.PENDING)
                .createdAt(LocalDateTime.now())
                .build();

        when(postReportRepository.findById(11L)).thenReturn(Optional.of(savedReport));
        when(postReportRepository.save(any(PostReport.class))).thenAnswer(inv -> inv.getArgument(0));

        PostReportResponse resolved = postService.resolveReport(11L, ReportStatus.RESOLVED, "admin_user");
        assertEquals(ReportStatus.RESOLVED, resolved.getStatus());
        assertNotNull(resolved.getResolvedBy());
        assertEquals(99, resolved.getResolvedBy().getUserId());
    }

    @Test
    @DisplayName("User cannot report their own post")
    void reportPost_selfReport_throws400() {
        Post ownPost = Post.builder()
                .postId(950L)
                .author(activeUser)
                .visibility(PostVisibility.PUBLIC)
                .status(PostStatus.ACTIVE)
                .build();

        when(userRepository.findByUsername("active_user")).thenReturn(Optional.of(activeUser));
        when(postRepository.findByIdWithDetails(950L)).thenReturn(Optional.of(ownPost));

        CreatePostReportRequest request = new CreatePostReportRequest("Spam", null);
        BadRequestException ex = assertThrows(BadRequestException.class,
                () -> postService.reportPost(950L, request, "active_user"));
        assertEquals("Bạn không thể tự báo cáo bài viết của chính mình", ex.getMessage());
    }
}

