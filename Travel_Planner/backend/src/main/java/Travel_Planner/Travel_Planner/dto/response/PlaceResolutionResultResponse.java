package Travel_Planner.Travel_Planner.dto.response;

import Travel_Planner.Travel_Planner.model.enums.ConfidenceClassification;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PlaceResolutionResultResponse {
    private Long placeId;
    private String placeName;
    private String placeAddress;
    private AdministrativeAreaSummaryResponse resolvedArea;
    private ConfidenceClassification confidence;
    private String matchMethod;
    private String explanation;
    private boolean eligibleForAutoLink;
    private boolean currentlyLinked;
    private List<AdministrativeAreaSummaryResponse> candidateAreas;
    private List<String> warnings;
}

