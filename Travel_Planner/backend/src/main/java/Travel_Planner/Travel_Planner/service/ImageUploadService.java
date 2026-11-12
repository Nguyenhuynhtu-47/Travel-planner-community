package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.ImageUploadResponse;
import org.springframework.web.multipart.MultipartFile;

public interface ImageUploadService {
    String uploadImage(MultipartFile file);
    ImageUploadResponse uploadImage(MultipartFile file, String username);
    void deleteCloudinaryImage(String publicId);
}
