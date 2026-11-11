package Travel_Planner.Travel_Planner.dto.request;

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
public class BatchResolvePlacesRequest {

    @Builder.Default
    private boolean dryRun = false;

    @Builder.Default
    private boolean overwriteExisting = false;

    private List<Long> placeIds;
}

