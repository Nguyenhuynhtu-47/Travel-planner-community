package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalTime;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ActivityResponse {
    private Integer activityId;
    private String name;
    private String description;
    private LocalTime startTime;
    private LocalTime endTime;
    private BigDecimal cost;
    private Integer displayOrder;
    private DestinationResponse destination;
}
