package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.response.ImageUploadResponse;
import Travel_Planner.Travel_Planner.service.ImageUploadService;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/media")
public class ImageUploadController {
    private final ImageUploadService imageUploadService;

    public ImageUploadController(ImageUploadService imageUploadService) {
        this.imageUploadService = imageUploadService;
    }

    @PostMapping(path = "/images", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ImageUploadResponse> uploadImage(
            @RequestPart("file") MultipartFile file,
            @AuthenticationPrincipal UserDetails actor) {
        String username = actor == null ? null : actor.getUsername();
        ImageUploadResponse response = imageUploadService.uploadImage(file, username);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }
}
