package Travel_Planner.Travel_Planner.dto.response;

import Travel_Planner.Travel_Planner.model.SystemSetting;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SystemSettingResponse {

    private String settingKey;
    private String settingValue;
    private String settingGroup;
    private String description;
    private String valueType;
    private LocalDateTime updatedAt;
    private String updatedBy;

    public static SystemSettingResponse fromEntity(SystemSetting entity) {
        return SystemSettingResponse.builder()
                .settingKey(entity.getSettingKey())
                .settingValue(entity.getSettingValue())
                .settingGroup(entity.getSettingGroup())
                .description(entity.getDescription())
                .valueType(entity.getValueType())
                .updatedAt(entity.getUpdatedAt())
                .updatedBy(entity.getUpdatedBy())
                .build();
    }
}
