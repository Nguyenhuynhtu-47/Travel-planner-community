package Travel_Planner.Travel_Planner.dto.response;

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
public class BatchLinkingReportResponse {
    private int totalPlacesExamined;
    private int linkedCount;
    private int skippedCount;
    private int quarantinedCount;
    private int ambiguousCount;
    private int noMatchCount;
    private boolean dryRun;
    private List<PlaceResolutionResultResponse> results;
}

