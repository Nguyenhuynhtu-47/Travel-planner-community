package Travel_Planner.Travel_Planner.exception;

import org.springframework.http.HttpStatus;

/**
 * Thrown when a mandatory Strict Audit record fails to persist to the database.
 * Extends RuntimeException via AppException so Spring automatically rolls back
 * the enclosing transactional business operation.
 */
public class AuditTrailPersistenceException extends AppException {

    public static final String DEFAULT_SAFE_MESSAGE =
            "Không thể ghi nhận nhật ký kiểm toán hệ thống. Thao tác đã bị hủy bỏ.";

    public AuditTrailPersistenceException(String safeMessage) {
        super(safeMessage != null && !safeMessage.isBlank() ? safeMessage : DEFAULT_SAFE_MESSAGE,
                HttpStatus.INTERNAL_SERVER_ERROR);
    }

    public AuditTrailPersistenceException(String safeMessage, Throwable cause) {
        this(safeMessage);
        if (cause != null) {
            initCause(cause);
        }
    }
}
