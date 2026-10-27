package Travel_Planner.Travel_Planner.dto.request;

import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreateDayRequest {

    @Size(max = 150, message = "Tiêu đề ngày tối đa 150 ký tự")
    private String title;

    private LocalDate date;
}
