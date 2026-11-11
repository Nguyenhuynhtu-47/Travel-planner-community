package Travel_Planner.Travel_Planner.model.enums;

/**
 * Types of administrative units under Vietnam's 2-tier local government structure
 * effective from 01/07/2025 (Nghị quyết số 202/2025/QH15).
 */
public enum AdministrativeAreaType {
    PROVINCE,       // Tỉnh
    CENTRAL_CITY,   // Thành phố trực thuộc Trung ương
    COMMUNE,        // Xã
    WARD,           // Phường
    SPECIAL_ZONE;   // Đặc khu (hải đảo, khu kinh tế đặc biệt)

    public boolean isProvinceLevel() {
        return this == PROVINCE || this == CENTRAL_CITY;
    }

    public boolean isCommuneLevel() {
        return this == COMMUNE || this == WARD || this == SPECIAL_ZONE;
    }
}

