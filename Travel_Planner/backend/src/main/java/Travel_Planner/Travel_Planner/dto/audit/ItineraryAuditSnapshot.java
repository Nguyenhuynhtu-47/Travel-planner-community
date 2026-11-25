package Travel_Planner.Travel_Planner.dto.audit;

import Travel_Planner.Travel_Planner.model.Itinerary;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * Allowlist-only snapshot DTO for Itinerary audit records.
 * Ensures private trip activity contents are never copied into audit snapshots.
 */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ItineraryAuditSnapshot implements AuditSnapshot {

    private Integer itineraryId;
    private String title;
    private Integer totalDays;
    private String visibility;
    private String status;

    public static ItineraryAuditSnapshot from(Itinerary itinerary) {
        if (itinerary == null) {
            return null;
        }
        return ItineraryAuditSnapshot.builder()
                .itineraryId(itinerary.getItineraryId())
                .title(itinerary.getTitle())
                .totalDays(itinerary.getTotalDays())
                .visibility(itinerary.getVisibility() != null ? itinerary.getVisibility().name() : null)
                .status(itinerary.getStatus() != null ? itinerary.getStatus().name() : null)
                .build();
    }
}
