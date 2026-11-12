package Travel_Planner.Travel_Planner.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ResolvePlaceRequest {

    private String provider;

    private String providerPlaceId;

    @NotBlank(message = "Tên địa điểm không được để trống")
    private String name;

    private String address;

    @NotNull(message = "Vĩ độ không được để trống")
    private BigDecimal latitude;

    @NotNull(message = "Kinh độ không được để trống")
    private BigDecimal longitude;

    private String category;

    private String type;

    private String metadataJson;
}

