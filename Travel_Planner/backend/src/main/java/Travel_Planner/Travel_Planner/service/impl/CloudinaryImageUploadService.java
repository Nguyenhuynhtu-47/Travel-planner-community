package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.response.ImageUploadResponse;
import Travel_Planner.Travel_Planner.exception.AppException;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.MediaAsset;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.MediaAssetStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.MediaAssetRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.ImageUploadService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.client.MultipartBodyBuilder;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.multipart.MultipartFile;
import tools.jackson.databind.JsonNode;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.UUID;

@Service
public class CloudinaryImageUploadService implements ImageUploadService {
    private static final long MAX_IMAGE_SIZE_BYTES = 5L * 1024 * 1024;
    private static final String IMAGE_FOLDER = "travel-planner";
    private static final Logger logger = LoggerFactory.getLogger(CloudinaryImageUploadService.class);

    private final RestClient restClient;
    private final String cloudName;
    private final String apiKey;
    private final String apiSecret;
    private final UserRepository userRepository;
    private final MediaAssetRepository mediaAssetRepository;

    public CloudinaryImageUploadService(
            RestClient.Builder restClientBuilder,
            @Value("${cloudinary.cloud-name:}") String cloudName,
            @Value("${cloudinary.api-key:}") String apiKey,
            @Value("${cloudinary.api-secret:}") String apiSecret) {
        this(restClientBuilder, cloudName, apiKey, apiSecret, null, null);
    }

    @Autowired
    public CloudinaryImageUploadService(
            RestClient.Builder restClientBuilder,
            @Value("${cloudinary.cloud-name:}") String cloudName,
            @Value("${cloudinary.api-key:}") String apiKey,
            @Value("${cloudinary.api-secret:}") String apiSecret,
            @Autowired(required = false) UserRepository userRepository,
            @Autowired(required = false) MediaAssetRepository mediaAssetRepository) {
        SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
        requestFactory.setConnectTimeout(Duration.ofSeconds(5));
        requestFactory.setReadTimeout(Duration.ofSeconds(20));
        this.restClient = restClientBuilder.requestFactory(requestFactory).build();
        this.cloudName = cloudName;
        this.apiKey = apiKey;
        this.apiSecret = apiSecret;
        this.userRepository = userRepository;
        this.mediaAssetRepository = mediaAssetRepository;
    }

    @Override
    public String uploadImage(MultipartFile file) {
        return uploadImage(file, null).secureUrl();
    }

    @Override
    public ImageUploadResponse uploadImage(MultipartFile file, String username) {
        byte[] bytes = validateAndRead(file);
        validateConfiguration();

        CloudinaryUploadResult result;
        try {
            result = uploadValidatedImage(bytes);
        } catch (AppException ex) {
            throw ex;
        } catch (RestClientResponseException ex) {
            int statusCode = ex.getStatusCode().value();
            logger.warn("Cloudinary rejected image upload with HTTP status {}", statusCode);
            throw new AppException(
                    "Cloudinary từ chối yêu cầu tải ảnh (HTTP " + statusCode + "). Kiểm tra cấu hình xác thực.",
                    HttpStatus.BAD_GATEWAY
            );
        } catch (ResourceAccessException ex) {
            logger.error("Could not connect to Cloudinary during image upload", ex);
            throw new AppException("Không thể kết nối đến Cloudinary. Vui lòng thử lại sau.", HttpStatus.BAD_GATEWAY);
        } catch (RestClientException ex) {
            logger.error("Cloudinary image upload request failed", ex);
            throw new AppException("Không thể xử lý phản hồi từ Cloudinary.", HttpStatus.BAD_GATEWAY);
        } catch (Exception ex) {
            logger.error("Unexpected failure while preparing or sending Cloudinary image upload", ex);
            throw new AppException("Máy chủ gặp lỗi khi xử lý ảnh tải lên.", HttpStatus.BAD_GATEWAY);
        }

        if (username != null && userRepository != null && mediaAssetRepository != null) {
            User user = userRepository.findByUsername(username)
                    .orElseThrow(() -> new UnauthorizedException("Phiên đăng nhập không hợp lệ"));
            if (user.getStatus() != UserStatus.ACTIVE) {
                try {
                    deleteCloudinaryImage(result.publicId());
                } catch (Exception ignored) {
                }
                throw new ForbiddenException("Tài khoản của bạn đang tạm khóa hoặc chưa được kích hoạt");
            }

            String publicId = result.publicId() != null && !result.publicId().isBlank()
                    ? result.publicId()
                    : "travel-planner/" + UUID.randomUUID();

            MediaAsset asset = MediaAsset.builder()
                    .uploadedBy(user)
                    .cloudinaryPublicId(publicId)
                    .secureUrl(result.secureUrl())
                    .mediaType("IMAGE")
                    .status(MediaAssetStatus.UNATTACHED)
                    .build();

            try {
                asset = mediaAssetRepository.save(asset);
                return new ImageUploadResponse(asset.getMediaAssetId(), asset.getSecureUrl());
            } catch (Exception dbEx) {
                logger.error("EVENT=CLOUDINARY_ORPHAN_COMPENSATION_FAILED DB save failed for uploaded image publicId={}, attempting compensating delete", publicId, dbEx);
                try {
                    deleteCloudinaryImage(publicId);
                } catch (Exception compEx) {
                    logger.error("EVENT=CLOUDINARY_ORPHAN_COMPENSATION_FAILED Compensating Cloudinary delete failed for publicId={}", publicId, compEx);
                }
                throw new AppException("Lỗi khi lưu trữ thông tin ảnh trong hệ thống", HttpStatus.INTERNAL_SERVER_ERROR);
            }
        }

        return new ImageUploadResponse(null, result.secureUrl());
    }

    @Override
    public void deleteCloudinaryImage(String publicId) {
        if (publicId == null || publicId.isBlank()) return;
        validateConfiguration();
        long timestamp = Instant.now().getEpochSecond();
        String signature = createDestroySignature(publicId, timestamp);

        MultipartBodyBuilder multipart = new MultipartBodyBuilder();
        multipart.part("public_id", publicId);
        multipart.part("api_key", apiKey);
        multipart.part("timestamp", Long.toString(timestamp));
        multipart.part("signature", signature);

        String destroyUrl = "https://api.cloudinary.com/v1_1/" + cloudName + "/image/destroy";
        try {
            JsonNode response = restClient.post()
                    .uri(destroyUrl)
                    .contentType(MediaType.MULTIPART_FORM_DATA)
                    .body(multipart.build())
                    .retrieve()
                    .body(JsonNode.class);
            String result = response == null ? null : response.path("result").asText(null);
            if ("ok".equalsIgnoreCase(result) || "not found".equalsIgnoreCase(result)) {
                logger.info("Cloudinary image destroyed successfully: publicId={}, result={}", publicId, result);
            } else {
                logger.warn("Cloudinary destroy returned non-ok result: publicId={}, result={}", publicId, result);
                throw new AppException("Cloudinary xóa ảnh không thành công: " + result, HttpStatus.BAD_GATEWAY);
            }
        } catch (RestClientResponseException ex) {
            int statusCode = ex.getStatusCode().value();
            if (statusCode == 401) {
                logger.error("SYSTEMIC_CONFIGURATION_FAILURE: Cloudinary credentials invalid during image destroy", ex);
                throw new AppException("Lỗi cấu hình xác thực Cloudinary hệ thống", HttpStatus.UNAUTHORIZED);
            }
            throw new AppException("Cloudinary từ chối yêu cầu xóa ảnh (HTTP " + statusCode + ")", HttpStatus.BAD_GATEWAY);
        } catch (AppException ex) {
            throw ex;
        } catch (Exception ex) {
            logger.error("Failed to delete Cloudinary image: publicId={}", publicId, ex);
            throw new AppException("Không thể kết nối đến Cloudinary để xóa ảnh", HttpStatus.BAD_GATEWAY);
        }
    }

    private CloudinaryUploadResult uploadValidatedImage(byte[] bytes) {
        long timestamp = Instant.now().getEpochSecond();
        String extension = imageExtension(bytes);

        MultipartBodyBuilder multipart = new MultipartBodyBuilder();
        multipart.part("file", new ByteArrayResource(bytes) {
            @Override
            public String getFilename() {
                return "travel-image." + extension;
            }
        }).contentType(MediaType.parseMediaType("image/" + extension));
        multipart.part("api_key", apiKey);
        multipart.part("timestamp", Long.toString(timestamp));
        multipart.part("folder", IMAGE_FOLDER);
        multipart.part("signature", createSignature(timestamp));

        String uploadUrl = "https://api.cloudinary.com/v1_1/" + cloudName + "/image/upload";
        JsonNode response = restClient.post()
                .uri(uploadUrl)
                .contentType(MediaType.MULTIPART_FORM_DATA)
                .body(multipart.build())
                .retrieve()
                .body(JsonNode.class);
        String secureUrl = response == null ? null : response.path("secure_url").asText(null);
        String publicId = response == null ? null : response.path("public_id").asText(null);
        if (secureUrl == null || !secureUrl.startsWith("https://") || secureUrl.length() > 500) {
            throw new AppException("Dịch vụ lưu trữ ảnh trả về dữ liệu không hợp lệ", HttpStatus.BAD_GATEWAY);
        }
        return new CloudinaryUploadResult(secureUrl, publicId);
    }

    private byte[] validateAndRead(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BadRequestException("Vui lòng chọn ảnh trước khi tải lên");
        }
        if (file.getSize() > MAX_IMAGE_SIZE_BYTES) {
            throw new BadRequestException("Ảnh không được vượt quá 5 MB");
        }
        try {
            byte[] bytes = file.getBytes();
            if (imageExtension(bytes) == null) {
                throw new BadRequestException("Chỉ chấp nhận ảnh JPEG, PNG hoặc WebP");
            }
            return bytes;
        } catch (IOException ex) {
            throw new BadRequestException("Không thể đọc tệp ảnh đã chọn");
        }
    }

    private String imageExtension(byte[] bytes) {
        if (bytes.length >= 8
                && (bytes[0] & 0xFF) == 0x89
                && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47
                && bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A) {
            return "png";
        }
        if (bytes.length >= 3 && (bytes[0] & 0xFF) == 0xFF
                && (bytes[1] & 0xFF) == 0xD8 && (bytes[2] & 0xFF) == 0xFF) {
            return "jpeg";
        }
        if (bytes.length >= 12 && bytes[0] == 'R' && bytes[1] == 'I'
                && bytes[2] == 'F' && bytes[3] == 'F' && bytes[8] == 'W'
                && bytes[9] == 'E' && bytes[10] == 'B' && bytes[11] == 'P') {
            return "webp";
        }
        return null;
    }

    private void validateConfiguration() {
        if (cloudName == null || !cloudName.matches("[A-Za-z0-9_-]+")
                || apiKey == null || apiKey.isBlank()
                || apiSecret == null || apiSecret.isBlank()) {
            throw new AppException("Dịch vụ tải ảnh chưa được cấu hình trên máy chủ", HttpStatus.SERVICE_UNAVAILABLE);
        }
    }

    private String createSignature(long timestamp) {
        String valueToSign = "folder=" + IMAGE_FOLDER + "&timestamp=" + timestamp + apiSecret;
        try {
            byte[] digest = MessageDigest.getInstance("SHA-1")
                    .digest(valueToSign.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException ex) {
            throw new AppException("Không thể xác thực yêu cầu tải ảnh", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    private String createDestroySignature(String publicId, long timestamp) {
        String valueToSign = "public_id=" + publicId + "&timestamp=" + timestamp + apiSecret;
        try {
            byte[] digest = MessageDigest.getInstance("SHA-1")
                    .digest(valueToSign.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException ex) {
            throw new AppException("Không thể xác thực yêu cầu xóa ảnh", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    public record CloudinaryUploadResult(String secureUrl, String publicId) {
    }
}
