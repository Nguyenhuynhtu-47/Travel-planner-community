package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DestinationResponse {
    private Integer destinationId;
    private String name;
    private String address;
    private String description;
    private String imageUrl;
    private BigDecimal latitude;
    private BigDecimal longitude;
}
