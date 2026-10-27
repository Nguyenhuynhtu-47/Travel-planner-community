package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.model.Destination;
import Travel_Planner.Travel_Planner.model.enums.DestinationStatus;
import Travel_Planner.Travel_Planner.repository.DestinationRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.math.BigDecimal;

import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
class DestinationControllerTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private DestinationRepository destinationRepository;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(context).build();
    }

    @Test
    void getDestinationsShouldReturnOk() throws Exception {
        // Ensure at least one destination exists
        Destination testDest = Destination.builder()
                .name("Hồ Xuân Hương Test")
                .address("Đà Lạt, Lâm Đồng")
                .description("Hồ cảnh quan trung tâm thành phố")
                .latitude(new BigDecimal("11.9404190"))
                .longitude(new BigDecimal("108.4377770"))
                .status(DestinationStatus.ACTIVE)
                .build();
        destinationRepository.save(testDest);

        mockMvc.perform(get("/api/destinations")
                .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.length()", greaterThanOrEqualTo(1)));
    }

    @Test
    void getDestinationsWithKeywordFilter() throws Exception {
        Destination testDest = Destination.builder()
                .name("Núi Langbiang Test Filter")
                .address("Lạc Dương, Lâm Đồng")
                .description("Đỉnh núi cao nhất Đà Lạt")
                .status(DestinationStatus.ACTIVE)
                .build();
        destinationRepository.save(testDest);

        mockMvc.perform(get("/api/destinations")
                .param("keyword", "Langbiang")
                .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$[0].name").value("Núi Langbiang Test Filter"));
    }
}
