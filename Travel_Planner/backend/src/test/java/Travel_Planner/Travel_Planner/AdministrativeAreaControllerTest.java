package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.AdministrativeAreaMigrationRunner;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import static org.hamcrest.Matchers.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
public class AdministrativeAreaControllerTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private AdministrativeAreaMigrationRunner migrationRunner;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() throws Exception {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        // Ensure database has imported data
        migrationRunner.migrateAndImport();
    }

    @Test
    @DisplayName("GET /api/administrative-areas/provinces returns 34 official provinces/central cities")
    void testGetAllProvinces_Returns34Provinces() throws Exception {
        mockMvc.perform(get("/api/administrative-areas/provinces")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(34)))
                .andExpect(jsonPath("$[0].code", notNullValue()))
                .andExpect(jsonPath("$[0].name", notNullValue()))
                .andExpect(jsonPath("$[0].areaType", anyOf(is("PROVINCE"), is("CENTRAL_CITY"))))
                .andExpect(jsonPath("$[0].parentCode", nullValue()));
    }

    @Test
    @DisplayName("GET /api/administrative-areas/{code}/children returns direct children for valid province code")
    void testGetChildren_ValidParentCode_ReturnsChildren() throws Exception {
        // Query children of TP. Hồ Chí Minh (code: "79")
        mockMvc.perform(get("/api/administrative-areas/79/children")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThan(0))))
                .andExpect(jsonPath("$[0].parentCode", is("79")))
                .andExpect(jsonPath("$[0].areaType", anyOf(is("COMMUNE"), is("WARD"), is("SPECIAL_ZONE"))));
    }

    @Test
    @DisplayName("GET /api/administrative-areas/{code}/children returns 404 for unknown parent code")
    void testGetChildren_InvalidParentCode_Returns404() throws Exception {
        mockMvc.perform(get("/api/administrative-areas/UNKNOWN_CODE_99/children")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("GET /api/administrative-areas/search finds areas by exact and unaccented query")
    void testSearch_ExactAndNormalized() throws Exception {
        // Search with diacritics
        mockMvc.perform(get("/api/administrative-areas/search")
                        .param("q", "Hà Nội")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThan(0))))
                .andExpect(jsonPath("$[0].name", containsString("Hà Nội")));

        // Search unaccented lowercase
        mockMvc.perform(get("/api/administrative-areas/search")
                        .param("q", "ha noi")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThan(0))))
                .andExpect(jsonPath("$[0].name", containsString("Hà Nội")));
    }

    @Test
    @DisplayName("GET /api/administrative-areas/search provides parent context for duplicate names")
    void testSearch_Disambiguation_IncludesParentContext() throws Exception {
        mockMvc.perform(get("/api/administrative-areas/search")
                        .param("q", "Châu Thành")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThan(0))))
                .andExpect(jsonPath("$[0].parentName", notNullValue()))
                .andExpect(jsonPath("$[0].parentCode", notNullValue()));
    }

    @Test
    @DisplayName("GET /api/administrative-areas/search with empty query returns empty list")
    void testSearch_EmptyOrBlankQuery_ReturnsEmptyList() throws Exception {
        mockMvc.perform(get("/api/administrative-areas/search")
                        .param("q", "")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(0)));
    }

    @Test
    @DisplayName("GET /api/administrative-areas/{code} returns details for valid official code")
    void testGetByCode_ValidCode_ReturnsDetail() throws Exception {
        mockMvc.perform(get("/api/administrative-areas/01")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code", is("01")))
                .andExpect(jsonPath("$.name", is("Thành phố Hà Nội")))
                .andExpect(jsonPath("$.areaType", is("CENTRAL_CITY")));
    }

    @Test
    @DisplayName("GET /api/administrative-areas/{code} returns 404 for unknown code")
    void testGetByCode_NotFound_Returns404() throws Exception {
        mockMvc.perform(get("/api/administrative-areas/NONEXISTENT_99")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isNotFound());
    }
}

