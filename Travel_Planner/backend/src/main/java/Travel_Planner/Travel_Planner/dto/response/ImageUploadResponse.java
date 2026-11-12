package Travel_Planner.Travel_Planner.dto.response;

public record ImageUploadResponse(Long mediaAssetId, String secureUrl) {
    public ImageUploadResponse(String secureUrl) {
        this(null, secureUrl);
    }
}
