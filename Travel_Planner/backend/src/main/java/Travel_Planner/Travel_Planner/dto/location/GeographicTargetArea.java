package Travel_Planner.Travel_Planner.dto.location;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * Resolved geographical boundary and center coordinates for a target location.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GeographicTargetArea {

    /**
     * Original target location query (e.g. "Long Xuyên", "Hồ Gươm", "Quận 1").
     */
    private String queryName;

    /**
     * Standardized name from provider geocoding (e.g. "Thành phố Long Xuyên, Tỉnh An Giang").
     */
    private String resolvedName;

    /**
     * Center latitude.
     */
    private double centerLat;

    /**
     * Center longitude.
     */
    private double centerLon;

    /**
     * Bounding box from provider: [minLat, maxLat, minLon, maxLon].
     */
    private List<Double> boundingBox;

    /**
     * Effective maximum radial boundary in kilometers for strict geographical filtering.
     */
    private double maxRadiusKm;

    /**
     * Detected location type (e.g. "city", "town", "district", "landmark", "lake").
     */
    private String targetType;

    /**
     * Province/State name if identified (e.g. "An Giang", "Lâm Đồng", "Hà Nội").
     */
    private String stateOrProvince;
}

