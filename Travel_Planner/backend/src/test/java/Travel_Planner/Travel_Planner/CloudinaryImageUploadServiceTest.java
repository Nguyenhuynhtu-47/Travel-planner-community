package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.exception.AppException;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.service.impl.CloudinaryImageUploadService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.client.RestClient;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class CloudinaryImageUploadServiceTest {
    private CloudinaryImageUploadService imageUploadService;

    @BeforeEach
    void setUp() {
        imageUploadService = new CloudinaryImageUploadService(
                RestClient.builder(),
                "",
                "",
                ""
        );
    }

    @Test
    void rejectsEmptyUpload() {
        MockMultipartFile file = new MockMultipartFile("file", "empty.png", "image/png", new byte[0]);

        assertThrows(BadRequestException.class, () -> imageUploadService.uploadImage(file));
    }

    @Test
    void rejectsUnsupportedFileSignature() {
        MockMultipartFile file = new MockMultipartFile(
                "file",
                "image.svg",
                "image/svg+xml",
                "<svg></svg>".getBytes()
        );

        assertThrows(BadRequestException.class, () -> imageUploadService.uploadImage(file));
    }

    @Test
    void rejectsFilesLargerThanFiveMiB() {
        byte[] bytes = new byte[5 * 1024 * 1024 + 1];
        bytes[0] = (byte) 0x89;
        bytes[1] = 0x50;
        bytes[2] = 0x4E;
        bytes[3] = 0x47;
        bytes[4] = 0x0D;
        bytes[5] = 0x0A;
        bytes[6] = 0x1A;
        bytes[7] = 0x0A;
        MockMultipartFile file = new MockMultipartFile("file", "large.png", "image/png", bytes);

        AppException exception = assertThrows(
                AppException.class,
                () -> imageUploadService.uploadImage(file)
        );
        assertEquals(HttpStatus.BAD_REQUEST, exception.getStatus());
    }

    @Test
    void reportsMissingCloudinaryConfigurationWithoutSendingFile() {
        byte[] pngSignature = {
                (byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
        };
        MockMultipartFile file = new MockMultipartFile("file", "image.png", "image/png", pngSignature);

        AppException exception = assertThrows(
                AppException.class,
                () -> imageUploadService.uploadImage(file)
        );
        assertEquals(HttpStatus.SERVICE_UNAVAILABLE, exception.getStatus());
    }
}
