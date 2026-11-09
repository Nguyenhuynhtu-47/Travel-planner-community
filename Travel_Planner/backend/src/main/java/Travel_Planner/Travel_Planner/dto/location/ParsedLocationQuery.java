package Travel_Planner.Travel_Planner.dto.location;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Structured representation of a user's parsed search query after semantic understanding.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ParsedLocationQuery {

    /**
     * Raw user input string (e.g. "Cơm tấm Long Xuyên").
     */
    private String originalQuery;

    /**
     * Lowercased, accent-stripped and whitespace-normalized query (e.g. "com tam long xuyen").
     */
    private String normalizedQuery;

    /**
     * Isolated subject/activity/food/service keyword (e.g. "cơm tấm", "cafe", "khách sạn").
     */
    private String searchKeyword;

    /**
     * Extracted geographical target name if present (e.g. "Long Xuyên", "Đà Lạt", "Quận 1", "Hồ Gươm").
     */
    private String locationQuery;

    /**
     * High-level functional category (e.g. "FOOD", "CAFE", "STAY", "BAKERY", "PHARMACY", "SUPERMARKET").
     */
    private String placeCategory;

    /**
     * Semantic intent classification.
     */
    private SearchIntent searchIntent;

    /**
     * Whether the query contains a distinct target geographical area.
     */
    public boolean hasExplicitLocation() {
        return locationQuery != null && !locationQuery.isBlank();
    }
}
