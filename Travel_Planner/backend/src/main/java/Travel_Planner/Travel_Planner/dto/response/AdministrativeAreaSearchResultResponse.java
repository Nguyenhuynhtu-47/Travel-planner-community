package Travel_Planner.Travel_Planner.dto.response;

import Travel_Planner.Travel_Planner.model.AdministrativeArea;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdministrativeAreaSearchResultResponse {

    private Long areaId;
    private String code;
    private String name;
    private AdministrativeAreaType areaType;
    private String parentCode;
    private String parentName;

    public static AdministrativeAreaSearchResultResponse fromEntity(AdministrativeArea entity) {
        if (entity == null) {
            return null;
        }
        return AdministrativeAreaSearchResultResponse.builder()
                .areaId(entity.getAreaId())
                .code(entity.getCode())
                .name(entity.getName())
                .areaType(entity.getAreaType())
                .parentCode(entity.getParent() != null ? entity.getParent().getCode() : null)
                .parentName(entity.getParent() != null ? entity.getParent().getName() : null)
                .build();
    }
}

