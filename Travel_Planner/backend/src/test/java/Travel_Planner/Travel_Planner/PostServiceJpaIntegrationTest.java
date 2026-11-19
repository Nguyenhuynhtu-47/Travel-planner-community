package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.CreatePostRequest;
import Travel_Planner.Travel_Planner.model.MediaAsset;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.MediaAssetStatus;
import Travel_Planner.Travel_Planner.model.enums.PostVisibility;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.MediaAssetRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import Travel_Planner.Travel_Planner.dto.request.UpdatePostRequest;
import Travel_Planner.Travel_Planner.dto.response.PostResponse;

@SpringBootTest
class PostServiceJpaIntegrationTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private MediaAssetRepository mediaAssetRepository;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();
    }

    @Test
    @DisplayName("Create post via HTTP POST /api/community/posts with real service and DB")
    @WithMockUser(username = "http_author")
    void testCreatePostHttp() throws Exception {
        User user = userRepository.findByUsername("http_author").orElseGet(() -> {
            User u = User.builder()
                    .username("http_author")
                    .email("http_author@example.com")
                    .password("secret123")
                    .handle("http_author")
                    .fullName("HTTP Author")
                    .status(UserStatus.ACTIVE)
                    .role(Role.USER)
                    .build();
            return userRepository.save(u);
        });

        MediaAsset asset = MediaAsset.builder()
                .uploadedBy(user)
                .cloudinaryPublicId("test/http_test_" + System.currentTimeMillis())
                .secureUrl("https://cloudinary.com/http_test.jpg")
                .mediaType("IMAGE")
                .status(MediaAssetStatus.UNATTACHED)
                .build();
        asset = mediaAssetRepository.save(asset);

        CreatePostRequest request = CreatePostRequest.builder()
                .content("HTTP Post content")
                .visibility(PostVisibility.PUBLIC)
                .mediaAssetIds(List.of(asset.getMediaAssetId()))
                .build();

        MvcResult result = mockMvc.perform(post("/api/community/posts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andReturn();

        String responseBody = result.getResponse().getContentAsString();
        System.out.println("RESPONSE BODY: " + responseBody);

        MediaAsset reloaded = mediaAssetRepository.findById(asset.getMediaAssetId()).orElseThrow();
        assertEquals(MediaAssetStatus.ATTACHED, reloaded.getStatus());
    }

    @Test
    @DisplayName("Update post via HTTP PATCH /api/community/posts/{id} keeping old media and adding new media")
    @WithMockUser(username = "http_author")
    void testUpdatePostKeepOldAndAddNewMedia() throws Exception {
        User user = userRepository.findByUsername("http_author").orElseThrow();

        // 1. Create asset 1
        MediaAsset asset1 = MediaAsset.builder()
                .uploadedBy(user)
                .cloudinaryPublicId("test/asset1_" + System.currentTimeMillis())
                .secureUrl("https://cloudinary.com/asset1.jpg")
                .mediaType("IMAGE")
                .status(MediaAssetStatus.UNATTACHED)
                .build();
        asset1 = mediaAssetRepository.save(asset1);

        // 2. Create post with asset 1
        CreatePostRequest createReq = CreatePostRequest.builder()
                .content("Initial Post Content")
                .visibility(PostVisibility.PUBLIC)
                .mediaAssetIds(List.of(asset1.getMediaAssetId()))
                .build();

        MvcResult createResult = mockMvc.perform(post("/api/community/posts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(createReq)))
                .andExpect(status().isCreated())
                .andReturn();

        PostResponse createdPost = objectMapper.readValue(createResult.getResponse().getContentAsString(), PostResponse.class);
        Long postId = createdPost.getPostId();

        // 3. Create asset 2 (newly picked image)
        MediaAsset asset2 = MediaAsset.builder()
                .uploadedBy(user)
                .cloudinaryPublicId("test/asset2_" + System.currentTimeMillis())
                .secureUrl("https://cloudinary.com/asset2.jpg")
                .mediaType("IMAGE")
                .status(MediaAssetStatus.UNATTACHED)
                .build();
        asset2 = mediaAssetRepository.save(asset2);

        // 4. Update post keeping asset 1 and adding asset 2
        UpdatePostRequest updateReq = UpdatePostRequest.builder()
                .content("Updated Post Content")
                .visibility(PostVisibility.PUBLIC)
                .mediaAssetIds(List.of(asset1.getMediaAssetId(), asset2.getMediaAssetId()))
                .build();

        MvcResult updateResult = mockMvc.perform(patch("/api/community/posts/" + postId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(updateReq)))
                .andExpect(status().isOk())
                .andReturn();

        PostResponse updatedPost = objectMapper.readValue(updateResult.getResponse().getContentAsString(), PostResponse.class);
        assertEquals(2, updatedPost.getMediaAssetIds().size());
        assertEquals(asset1.getMediaAssetId(), updatedPost.getMediaAssetIds().get(0));
        assertEquals(asset2.getMediaAssetId(), updatedPost.getMediaAssetIds().get(1));
    }
}
