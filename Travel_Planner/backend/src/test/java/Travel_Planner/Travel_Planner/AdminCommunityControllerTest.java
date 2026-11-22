package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.ModeratePostRequest;
import Travel_Planner.Travel_Planner.dto.request.ResolveReportRequest;
import Travel_Planner.Travel_Planner.dto.response.*;
import Travel_Planner.Travel_Planner.model.enums.MediaAssetStatus;
import Travel_Planner.Travel_Planner.model.enums.PostStatus;
import Travel_Planner.Travel_Planner.model.enums.ReportStatus;
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
class AdminCommunityControllerTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private ObjectMapper objectMapper;

    @MockitoBean
    private PostService postService;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();
    }

    @Test
    @WithMockUser(username = "admin_user", roles = {"ADMIN"})
    @DisplayName("GET /api/admin/community/posts returns paginated posts for admin")
    void getPosts_admin_success() throws Exception {
        PostResponse post = PostResponse.builder()
                .postId(1L)
                .content("Nội dung bài viết")
                .status(PostStatus.ACTIVE)
                .build();
        PageResponse<PostResponse> pageResponse = PageResponse.<PostResponse>builder()
                .content(List.of(post))
                .pageNumber(0)
                .pageSize(20)
                .totalElements(1)
                .totalPages(1)
                .last(true)
                .build();

        when(postService.getAdminPosts(eq(PostStatus.ACTIVE), eq(0), eq(20))).thenReturn(pageResponse);

        mockMvc.perform(get("/api/admin/community/posts?status=ACTIVE&page=0&size=20"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].postId").value(1))
                .andExpect(jsonPath("$.content[0].status").value("ACTIVE"));
    }

    @Test
    @WithMockUser(username = "regular_user", roles = {"USER"})
    @DisplayName("GET /api/admin/community/posts blocks regular user with 403")
    void getPosts_regularUser_forbidden() throws Exception {
        mockMvc.perform(get("/api/admin/community/posts"))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(username = "admin_user", roles = {"ADMIN"})
    @DisplayName("GET /api/admin/community/posts/{id} returns post detail for admin")
    void getPostById_admin_success() throws Exception {
        PostResponse post = PostResponse.builder()
                .postId(5L)
                .content("Chi tiết bài viết")
                .status(PostStatus.HIDDEN)
                .moderationReason("Vi phạm tiêu chuẩn")
                .build();

        when(postService.getAdminPostById(eq(5L), eq("admin_user"))).thenReturn(post);

        mockMvc.perform(get("/api/admin/community/posts/5"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.postId").value(5))
                .andExpect(jsonPath("$.moderationReason").value("Vi phạm tiêu chuẩn"));
    }

    @Test
    @WithMockUser(username = "admin_user", roles = {"ADMIN"})
    @DisplayName("PATCH /api/admin/community/posts/{id}/moderate updates post status and reason")
    void moderatePost_admin_success() throws Exception {
        ModeratePostRequest request = new ModeratePostRequest(PostStatus.HIDDEN, "Quảng cáo spam");
        PostResponse response = PostResponse.builder()
                .postId(5L)
                .status(PostStatus.HIDDEN)
                .moderationReason("Quảng cáo spam")
                .build();

        when(postService.moderatePost(eq(5L), any(ModeratePostRequest.class), eq("admin_user"))).thenReturn(response);

        mockMvc.perform(patch("/api/admin/community/posts/5/moderate")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("HIDDEN"))
                .andExpect(jsonPath("$.moderationReason").value("Quảng cáo spam"));
    }

    @Test
    @WithMockUser(username = "admin_user", roles = {"ADMIN"})
    @DisplayName("DELETE /api/admin/community/posts/{id}/purge permanently purges post")
    void purgePost_admin_success() throws Exception {
        mockMvc.perform(delete("/api/admin/community/posts/5/purge"))
                .andExpect(status().isNoContent());

        verify(postService).purgePost(5L, "admin_user");
    }

    @Test
    @WithMockUser(username = "admin_user", roles = {"ADMIN"})
    @DisplayName("GET /api/admin/community/reports returns paginated reports")
    void getReports_admin_success() throws Exception {
        PostReportResponse report = PostReportResponse.builder()
                .reportId(10L)
                .postId(5L)
                .reason("Spam")
                .status(ReportStatus.PENDING)
                .createdAt(LocalDateTime.now())
                .build();
        PageResponse<PostReportResponse> pageResponse = PageResponse.<PostReportResponse>builder()
                .content(List.of(report))
                .pageNumber(0)
                .pageSize(20)
                .totalElements(1)
                .totalPages(1)
                .last(true)
                .build();

        when(postService.getAdminReports(eq(ReportStatus.PENDING), eq(0), eq(20))).thenReturn(pageResponse);

        mockMvc.perform(get("/api/admin/community/reports?status=PENDING&page=0&size=20"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].reportId").value(10))
                .andExpect(jsonPath("$.content[0].status").value("PENDING"));
    }

    @Test
    @WithMockUser(username = "admin_user", roles = {"ADMIN"})
    @DisplayName("GET /api/admin/community/reports/{id} returns report detail")
    void getReportById_admin_success() throws Exception {
        PostReportResponse report = PostReportResponse.builder()
                .reportId(10L)
                .postId(5L)
                .reason("Lừa đảo")
                .status(ReportStatus.PENDING)
                .build();

        when(postService.getAdminReportById(eq(10L), eq("admin_user"))).thenReturn(report);

        mockMvc.perform(get("/api/admin/community/reports/10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reportId").value(10))
                .andExpect(jsonPath("$.reason").value("Lừa đảo"));
    }

    @Test
    @WithMockUser(username = "admin_user", roles = {"ADMIN"})
    @DisplayName("PATCH /api/admin/community/reports/{id}/resolve via query parameter")
    void resolveReport_viaQueryParam_success() throws Exception {
        PostReportResponse report = PostReportResponse.builder()
                .reportId(10L)
                .postId(5L)
                .status(ReportStatus.RESOLVED)
                .build();

        when(postService.resolveReport(eq(10L), eq(ReportStatus.RESOLVED), eq("admin_user"))).thenReturn(report);

        mockMvc.perform(patch("/api/admin/community/reports/10/resolve?resolution=RESOLVED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("RESOLVED"));
    }

    @Test
    @WithMockUser(username = "admin_user", roles = {"ADMIN"})
    @DisplayName("PATCH /api/admin/community/reports/{id}/resolve via JSON request body")
    void resolveReport_viaJsonBody_success() throws Exception {
        ResolveReportRequest body = ResolveReportRequest.builder()
                .resolution(ReportStatus.RESOLVED)
                .build();
        PostReportResponse report = PostReportResponse.builder()
                .reportId(10L)
                .postId(5L)
                .status(ReportStatus.RESOLVED)
                .build();

        when(postService.resolveReport(eq(10L), eq(ReportStatus.RESOLVED), eq("admin_user"))).thenReturn(report);

        mockMvc.perform(patch("/api/admin/community/reports/10/resolve")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("RESOLVED"));
    }

    @Test
    @WithMockUser(username = "admin_user", roles = {"ADMIN"})
    @DisplayName("GET /api/admin/media-assets returns media assets list")
    void getMediaAssets_admin_success() throws Exception {
        MediaAssetResponse asset = MediaAssetResponse.builder()
                .mediaAssetId(99L)
                .secureUrl("https://cloudinary.com/test.jpg")
                .status(MediaAssetStatus.DELETING)
                .retryCount(1)
                .build();
        PageResponse<MediaAssetResponse> pageResponse = PageResponse.<MediaAssetResponse>builder()
                .content(List.of(asset))
                .pageNumber(0)
                .pageSize(20)
                .totalElements(1)
                .totalPages(1)
                .last(true)
                .build();

        when(postService.getAdminMediaAssets(eq(null), eq(false), eq(0), eq(20))).thenReturn(pageResponse);

        mockMvc.perform(get("/api/admin/media-assets"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].mediaAssetId").value(99))
                .andExpect(jsonPath("$.content[0].status").value("DELETING"));
    }

    @Test
    @WithMockUser(username = "admin_user", roles = {"ADMIN"})
    @DisplayName("POST /api/admin/media-assets/{id}/retry triggers retry for media asset")
    void retryMediaAsset_admin_success() throws Exception {
        mockMvc.perform(post("/api/admin/media-assets/99/retry"))
                .andExpect(status().isOk());

        verify(postService).retryMediaAsset(99L, "admin_user");
    }
}
