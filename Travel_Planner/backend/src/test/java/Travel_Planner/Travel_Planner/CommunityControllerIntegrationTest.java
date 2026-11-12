package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.CreatePostCommentRequest;
import Travel_Planner.Travel_Planner.dto.request.CreatePostRequest;
import Travel_Planner.Travel_Planner.dto.request.ModeratePostRequest;
import Travel_Planner.Travel_Planner.dto.response.*;
import Travel_Planner.Travel_Planner.model.enums.PostStatus;
import Travel_Planner.Travel_Planner.model.enums.PostVisibility;
import Travel_Planner.Travel_Planner.service.MessagingService;
import Travel_Planner.Travel_Planner.service.PostService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.time.LocalDateTime;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
class CommunityControllerIntegrationTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private ObjectMapper objectMapper;

    @MockitoBean
    private PostService postService;

    @MockitoBean
    private MessagingService messagingService;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();
    }

    @Test
    @DisplayName("GET /api/community/feed is publicly accessible without token")
    void getPublicFeed_publicAccess_success() throws Exception {
        PostAuthorResponse author = PostAuthorResponse.builder()
                .userId(1)
                .handle("test_user")
                .fullName("Test User")
                .build();

        PostResponse post = PostResponse.builder()
                .postId(10L)
                .content("Bình minh trên biển Mỹ Khê")
                .author(author)
                .mediaUrls(List.of("https://res.cloudinary.com/beach.jpg"))
                .visibility(PostVisibility.PUBLIC)
                .status(PostStatus.ACTIVE)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        PageResponse<PostResponse> pageResponse = PageResponse.<PostResponse>builder()
                .content(List.of(post))
                .pageNumber(0)
                .pageSize(10)
                .totalElements(1)
                .totalPages(1)
                .last(true)
                .build();

        when(postService.getPublicFeed(0, 10, null)).thenReturn(pageResponse);

        mockMvc.perform(get("/api/community/feed?page=0&size=10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].postId").value(10))
                .andExpect(jsonPath("$.content[0].content").value("Bình minh trên biển Mỹ Khê"))
                .andExpect(jsonPath("$.content[0].mediaUrls[0]").value("https://res.cloudinary.com/beach.jpg"));
    }

    @Test
    @WithMockUser(username = "traveller_an")
    @DisplayName("GET /api/conversations/unread-total returns aggregated unread count")
    void getUnreadTotal_authenticated_success() throws Exception {
        when(messagingService.totalUnread("traveller_an")).thenReturn(7L);

        mockMvc.perform(get("/api/conversations/unread-total"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalUnread").value(7));
    }

    @Test
    @WithMockUser(username = "traveller_an")
    @DisplayName("POST /api/community/posts creates new post")
    void createPost_authenticated_success() throws Exception {
        CreatePostRequest request = CreatePostRequest.builder()
                .content("Du lịch Hội An")
                .visibility(PostVisibility.PUBLIC)
                .mediaAssetIds(List.of(101L))
                .build();

        PostResponse response = PostResponse.builder()
                .postId(20L)
                .content("Du lịch Hội An")
                .visibility(PostVisibility.PUBLIC)
                .status(PostStatus.ACTIVE)
                .build();

        when(postService.createPost(any(CreatePostRequest.class), eq("traveller_an"))).thenReturn(response);

        mockMvc.perform(post("/api/community/posts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.postId").value(20))
                .andExpect(jsonPath("$.content").value("Du lịch Hội An"));
    }

    @Test
    @WithMockUser(username = "traveller_an")
    @DisplayName("POST /api/community/posts/{id}/likes likes post")
    void likePost_authenticated_success() throws Exception {
        mockMvc.perform(post("/api/community/posts/20/likes"))
                .andExpect(status().isOk());

        verify(postService).likePost(20L, "traveller_an");
    }

    @Test
    @WithMockUser(username = "traveller_an")
    @DisplayName("POST /api/community/posts/{id}/comments adds comment")
    void addComment_authenticated_success() throws Exception {
        CreatePostCommentRequest request = new CreatePostCommentRequest("Thích bài viết này!");

        PostCommentResponse response = PostCommentResponse.builder()
                .commentId(30L)
                .postId(20L)
                .content("Thích bài viết này!")
                .build();

        when(postService.addComment(eq(20L), any(CreatePostCommentRequest.class), eq("traveller_an"))).thenReturn(response);

        mockMvc.perform(post("/api/community/posts/20/comments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.commentId").value(30))
                .andExpect(jsonPath("$.content").value("Thích bài viết này!"));
    }

    @Test
    @WithMockUser(username = "admin_user", roles = {"ADMIN"})
    @DisplayName("PATCH /api/admin/community/posts/{id}/moderate allows admin to moderate post")
    void moderatePost_admin_success() throws Exception {
        ModeratePostRequest request = new ModeratePostRequest(PostStatus.HIDDEN, "Vi phạm tiêu chuẩn cộng đồng");

        PostResponse response = PostResponse.builder()
                .postId(20L)
                .status(PostStatus.HIDDEN)
                .build();

        when(postService.moderatePost(eq(20L), any(ModeratePostRequest.class), eq("admin_user"))).thenReturn(response);

        mockMvc.perform(patch("/api/admin/community/posts/20/moderate")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("HIDDEN"));
    }

    @Test
    @WithMockUser(username = "regular_user", roles = {"USER"})
    @DisplayName("PATCH /api/admin/community/posts/{id}/moderate forbids non-admin users")
    void moderatePost_nonAdmin_forbidden() throws Exception {
        ModeratePostRequest request = new ModeratePostRequest(PostStatus.HIDDEN, "Vi phạm tiêu chuẩn cộng đồng");

        mockMvc.perform(patch("/api/admin/community/posts/20/moderate")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isForbidden());
    }
}
