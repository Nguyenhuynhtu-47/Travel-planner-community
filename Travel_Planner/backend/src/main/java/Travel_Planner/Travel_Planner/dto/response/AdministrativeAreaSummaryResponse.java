package Travel_Planner.Travel_Planner.dto.response;

import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaTrustClassification;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdministrativeAreaSummaryResponse {
    private Long areaId;
    private String code;
    private String name;
    private AdministrativeAreaType areaType;
    private Long parentAreaId;
    private String parentCode;
    private String parentName;
    private AdministrativeAreaTrustClassification trustClassification;
}

