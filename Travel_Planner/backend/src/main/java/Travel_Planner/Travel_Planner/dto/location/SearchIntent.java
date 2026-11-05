package Travel_Planner.Travel_Planner.dto.location;

/**
 * Categorizes the semantic intent of a location search query.
 */
public enum SearchIntent {
    /**
     * Searching for a service, POI, or dish inside a specified target location.
     * Examples: "cơm tấm Long Xuyên", "cafe Đà Lạt", "tiệm bánh gần Hồ Gươm", "khách sạn Vũng Tàu".
     */
    POI_IN_LOCATION,

    /**
     * Searching for an administrative area, city, district, or region itself.
     * Examples: "Long Xuyên", "Vũng Tàu", "Đà Lạt", "Quận 1", "Hà Nội".
     */
    LOCALITY,

    /**
     * Searching for a specific brand, chain, or prominent standalone landmark.
     * Examples: "Hồ Gươm", "Dinh Độc Lập", "Starbucks", "Pharmacity", "Bà Nà Hills".
     */
    SPECIFIC_PLACE,

    /**
     * Searching for a category, amenity, or food with no explicit target location specified.
     * Examples: "cơm tấm", "quán cà phê", "khách sạn", "bún bò Huế" (dish name without target city).
     */
    GENERIC_POI
}

