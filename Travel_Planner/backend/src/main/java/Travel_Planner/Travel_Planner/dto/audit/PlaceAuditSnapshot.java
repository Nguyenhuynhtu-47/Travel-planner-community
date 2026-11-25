package Travel_Planner.Travel_Planner.dto.audit;

import Travel_Planner.Travel_Planner.model.Place;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * Allowlist-only snapshot DTO for Place audit records.
 */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PlaceAuditSnapshot implements AuditSnapshot {

    private Long placeId;
    private String name;
    private String category;
    private String address;
    private String status;
    private String administrativeCode;

    public static PlaceAuditSnapshot from(Place place) {
        if (place == null) {
            return null;
        }
        return PlaceAuditSnapshot.builder()
                .placeId(place.getPlaceId())
                .name(place.getName())
                .category(place.getCategory() != null ? place.getCategory().name() : null)
                .address(place.getAddress())
                .status(place.getStatus() != null ? place.getStatus().name() : null)
                .administrativeCode(place.getAdministrativeArea() != null
                        ? place.getAdministrativeArea().getCode()
                        : null)
                .build();
    }
}
