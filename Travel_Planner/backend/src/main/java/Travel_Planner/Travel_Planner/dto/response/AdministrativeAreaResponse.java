package Travel_Planner.Travel_Planner.dto.response;

import Travel_Planner.Travel_Planner.model.AdministrativeArea;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaStatus;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdministrativeAreaResponse {

    private Long areaId;
    private String code;
    private String name;
    private String normalizedName;
    private AdministrativeAreaType areaType;
    private AdministrativeAreaStatus status;
    private String parentCode;
    private String parentName;
    private LocalDate effectiveFrom;

    public static AdministrativeAreaResponse fromEntity(AdministrativeArea entity) {
        if (entity == null) {
            return null;
        }
        return AdministrativeAreaResponse.builder()
                .areaId(entity.getAreaId())
                .code(entity.getCode())
                .name(entity.getName())
                .normalizedName(entity.getNormalizedName())
                .areaType(entity.getAreaType())
                .status(entity.getStatus())
                .parentCode(entity.getParent() != null ? entity.getParent().getCode() : null)
                .parentName(entity.getParent() != null ? entity.getParent().getName() : null)
                .effectiveFrom(entity.getEffectiveFrom())
                .build();
    }
}

