package Travel_Planner.Travel_Planner.dto.request;

import Travel_Planner.Travel_Planner.model.enums.ShareTargetType;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ShareBatchRequest {

    @NotNull(message = "Loại nội dung chia sẻ không được để trống")
    private ShareTargetType targetType;

    @NotNull(message = "Mã nội dung chia sẻ không được để trống")
    private Long targetId;

    @NotEmpty(message = "Danh sách người nhận không được để trống")
    @Size(min = 1, max = 10, message = "Số lượng người nhận phải từ 1 đến 10")
    private List<Integer> recipientUserIds;

    @Size(max = 4000, message = "Lời nhắn không được vượt quá 4.000 ký tự")
    private String note;

    @Size(max = 64, message = "Mã phiên chia sẻ không hợp lệ")
    private String shareBatchId;
}
