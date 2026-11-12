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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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
}
