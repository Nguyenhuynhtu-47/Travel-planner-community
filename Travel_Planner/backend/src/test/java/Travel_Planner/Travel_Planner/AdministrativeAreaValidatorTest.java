package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.AdministrativeAreaMigrationRunner.CommuneSourceDto;
import Travel_Planner.Travel_Planner.config.AdministrativeAreaMigrationRunner.ProvinceSourceDto;
import Travel_Planner.Travel_Planner.config.AdministrativeAreaValidator;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

public class AdministrativeAreaValidatorTest {

    private AdministrativeAreaValidator validator;

    @BeforeEach
    void setUp() {
        validator = new AdministrativeAreaValidator();
    }

    @Test
    @DisplayName("Canonical checksum is completely order-independent")
    void testCanonicalChecksum_isOrderIndependent() {
        ProvinceSourceDto p1 = new ProvinceSourceDto("01", "Hà Nội", "CENTRAL_CITY", null, "ACTIVE");
        ProvinceSourceDto p2 = new ProvinceSourceDto("79", "Hồ Chí Minh", "CENTRAL_CITY", null, "ACTIVE");

        CommuneSourceDto c1 = new CommuneSourceDto("00004", "Phường Ba Đình", "WARD", "01", "ACTIVE");
        CommuneSourceDto c2 = new CommuneSourceDto("26740", "Phường Sài Gòn", "WARD", "79", "ACTIVE");

        List<ProvinceSourceDto> provsOrder1 = List.of(p1, p2);
        List<CommuneSourceDto> commsOrder1 = List.of(c1, c2);

        List<ProvinceSourceDto> provsOrder2 = List.of(p2, p1);
        List<CommuneSourceDto> commsOrder2 = List.of(c2, c1);

        String checksum1 = validator.computeCanonicalChecksum(provsOrder1, commsOrder1);
        String checksum2 = validator.computeCanonicalChecksum(provsOrder2, commsOrder2);

        assertNotNull(checksum1);
        assertEquals(64, checksum1.length());
        assertEquals(checksum1, checksum2, "Shuffling source entries must yield identical canonical checksum");
    }

    @Test
    @DisplayName("Canonical checksum changes when any unit name is modified")
    void testCanonicalChecksum_changesWhenNameModified() {
        ProvinceSourceDto p1 = new ProvinceSourceDto("01", "Hà Nội", "CENTRAL_CITY", null, "ACTIVE");
        CommuneSourceDto c1 = new CommuneSourceDto("00004", "Phường Ba Đình", "WARD", "01", "ACTIVE");

        String originalChecksum = validator.computeCanonicalChecksum(List.of(p1), List.of(c1));

        // Tamper commune name
        CommuneSourceDto c1Tampered = new CommuneSourceDto("00004", "Phường Phúc Xá", "WARD", "01", "ACTIVE");
        String tamperedChecksum = validator.computeCanonicalChecksum(List.of(p1), List.of(c1Tampered));

        assertNotEquals(originalChecksum, tamperedChecksum, "Modifying a unit name must change canonical checksum");
    }

    @Test
    @DisplayName("Canonical checksum changes when any parentCode is modified")
    void testCanonicalChecksum_changesWhenParentModified() {
        ProvinceSourceDto p1 = new ProvinceSourceDto("68", "Lâm Đồng", "PROVINCE", null, "ACTIVE");
        ProvinceSourceDto p2 = new ProvinceSourceDto("60", "Bình Thuận", "PROVINCE", null, "ACTIVE");

        CommuneSourceDto specialZone = new CommuneSourceDto("23272", "Đặc khu Phú Quý", "SPECIAL_ZONE", "68", "ACTIVE");
        String correctChecksum = validator.computeCanonicalChecksum(List.of(p1, p2), List.of(specialZone));

        // Tamper parent to 60 (Bình Thuận)
        CommuneSourceDto tamperedZone = new CommuneSourceDto("23272", "Đặc khu Phú Quý", "SPECIAL_ZONE", "60", "ACTIVE");
        String tamperedChecksum = validator.computeCanonicalChecksum(List.of(p1, p2), List.of(tamperedZone));

        assertNotEquals(correctChecksum, tamperedChecksum, "Modifying parent code must change canonical checksum");
    }

    @Test
    @DisplayName("Canonical checksum changes when any areaType is modified")
    void testCanonicalChecksum_changesWhenAreaTypeModified() {
        ProvinceSourceDto p1 = new ProvinceSourceDto("01", "Hà Nội", "CENTRAL_CITY", null, "ACTIVE");
        CommuneSourceDto c1 = new CommuneSourceDto("00004", "Phường Ba Đình", "WARD", "01", "ACTIVE");

        String checksum1 = validator.computeCanonicalChecksum(List.of(p1), List.of(c1));

        CommuneSourceDto c1TypeChanged = new CommuneSourceDto("00004", "Phường Ba Đình", "COMMUNE", "01", "ACTIVE");
        String checksum2 = validator.computeCanonicalChecksum(List.of(p1), List.of(c1TypeChanged));

        assertNotEquals(checksum1, checksum2, "Modifying area type must change canonical checksum");
    }

    @Test
    @DisplayName("Validator catches missing fields, duplicate codes and invalid parents")
    void testValidatorCatchesDiscrepancies() {
        List<ProvinceSourceDto> provinces = new ArrayList<>();
        provinces.add(new ProvinceSourceDto("01", "", "CENTRAL_CITY", null, "ACTIVE")); // blank name
        provinces.add(new ProvinceSourceDto("01", "Duplicate Hà Nội", "CENTRAL_CITY", null, "ACTIVE")); // duplicate code
        provinces.add(new ProvinceSourceDto("04", "Cao Bằng", "PROVINCE", "01", "ACTIVE")); // province with parent

        List<CommuneSourceDto> communes = new ArrayList<>();
        communes.add(new CommuneSourceDto("00004", "Ba Đình", "WARD", "99", "ACTIVE")); // invalid parent
        communes.add(new CommuneSourceDto("00008", "Ngọc Hà", "INVALID_TYPE", "01", "ACTIVE")); // invalid type
        communes.add(new CommuneSourceDto("00004", "Duplicate Ba Đình", "WARD", "01", "ACTIVE")); // duplicate commune code

        AdministrativeAreaValidator.ValidationResult result = validator.validateSourceData(provinces, communes);
        assertFalse(result.isValid());
        assertTrue(result.getErrors().size() >= 5);
    }

    @Test
    @DisplayName("Canonical checksum changes when a record is deleted")
    void testCanonicalChecksum_changesWhenRecordDeleted() {
        ProvinceSourceDto p1 = new ProvinceSourceDto("01", "Hà Nội", "CENTRAL_CITY", null, "ACTIVE");
        ProvinceSourceDto p2 = new ProvinceSourceDto("79", "Hồ Chí Minh", "CENTRAL_CITY", null, "ACTIVE");
        CommuneSourceDto c1 = new CommuneSourceDto("00004", "Phường Ba Đình", "WARD", "01", "ACTIVE");

        String fullChecksum = validator.computeCanonicalChecksum(List.of(p1, p2), List.of(c1));
        String deletedChecksum = validator.computeCanonicalChecksum(List.of(p1), List.of(c1)); // p2 deleted

        assertNotEquals(fullChecksum, deletedChecksum, "Deleting a record must change canonical checksum");
    }

    @Test
    @DisplayName("Canonical checksum changes when a record is added")
    void testCanonicalChecksum_changesWhenRecordAdded() {
        ProvinceSourceDto p1 = new ProvinceSourceDto("01", "Hà Nội", "CENTRAL_CITY", null, "ACTIVE");
        CommuneSourceDto c1 = new CommuneSourceDto("00004", "Phường Ba Đình", "WARD", "01", "ACTIVE");

        String baseChecksum = validator.computeCanonicalChecksum(List.of(p1), List.of(c1));

        CommuneSourceDto c2 = new CommuneSourceDto("00008", "Phường Ngọc Hà", "WARD", "01", "ACTIVE");
        String addedChecksum = validator.computeCanonicalChecksum(List.of(p1), List.of(c1, c2));

        assertNotEquals(baseChecksum, addedChecksum, "Adding a record must change canonical checksum");
    }

    @Test
    @DisplayName("Canonical checksum NFC vs NFD demonstrates byte sensitivity")
    void testCanonicalChecksum_nfcVsNfdBehavior() {
        // NFC: precomposed "Hà Nội" (\u0048 \u00e0 \u0020 \u004e \u1ed9 \u0069)
        String nfcName = java.text.Normalizer.normalize("Hà Nội", java.text.Normalizer.Form.NFC);
        // NFD: decomposed "Ha\u0300 No\u0323\u0302i"
        String nfdName = java.text.Normalizer.normalize("Hà Nội", java.text.Normalizer.Form.NFD);

        assertNotEquals(nfcName, nfdName, "NFC and NFD string representations must have different code points");

        ProvinceSourceDto pNfc = new ProvinceSourceDto("01", nfcName, "CENTRAL_CITY", null, "ACTIVE");
        ProvinceSourceDto pNfd = new ProvinceSourceDto("01", nfdName, "CENTRAL_CITY", null, "ACTIVE");

        String nfcChecksum = validator.computeCanonicalChecksum(List.of(pNfc), List.of());
        String nfdChecksum = validator.computeCanonicalChecksum(List.of(pNfd), List.of());

        assertNotEquals(nfcChecksum, nfdChecksum, "Checksum differs across NFC and NFD; datasets must be normalized to NFC");
    }

    @Test
    @DisplayName("Canonical checksum delimiter safety against pipe collisions")
    void testCanonicalChecksum_delimiterCollisionSafety() {
        ProvinceSourceDto p1 = new ProvinceSourceDto("01", "Hà Nội", "CENTRAL_CITY", null, "ACTIVE");
        CommuneSourceDto c1 = new CommuneSourceDto("00004", "Phường Ba Đình", "WARD", "01", "ACTIVE");

        // No record should ever contain the delimiter '|'
        assertFalse(p1.code.contains("|"));
        assertFalse(p1.name.contains("|"));
        assertFalse(c1.code.contains("|"));
        assertFalse(c1.name.contains("|"));
    }

    @Test
    @DisplayName("Canonical checksum whitespace behavior: trim normalizes leading/trailing, sensitive to internal whitespace")
    void testCanonicalChecksum_whitespaceBehavior() {
        ProvinceSourceDto pClean = new ProvinceSourceDto("01", "Hà Nội", "CENTRAL_CITY", null, "ACTIVE");
        ProvinceSourceDto pTrimmed = new ProvinceSourceDto("  01  ", "  Hà Nội  ", "  CENTRAL_CITY  ", null, "ACTIVE");
        ProvinceSourceDto pInternalWs = new ProvinceSourceDto("01", "Hà   Nội", "CENTRAL_CITY", null, "ACTIVE");

        String cleanChecksum = validator.computeCanonicalChecksum(List.of(pClean), List.of());
        String trimmedChecksum = validator.computeCanonicalChecksum(List.of(pTrimmed), List.of());
        String internalWsChecksum = validator.computeCanonicalChecksum(List.of(pInternalWs), List.of());

        // Leading/trailing whitespace is normalized away by .trim()
        assertEquals(cleanChecksum, trimmedChecksum, "Trimming normalizes away leading and trailing whitespace");

        // Internal whitespace differences are preserved and change the checksum
        assertNotEquals(cleanChecksum, internalWsChecksum, "Internal whitespace alters canonical checksum");
    }

    @Test
    @DisplayName("Canonical checksum handles null and empty parentCode equivalently")
    void testCanonicalChecksum_nullAndEmptyParentEquivalent() {
        CommuneSourceDto cNullParent = new CommuneSourceDto("00004", "Phường Ba Đình", "WARD", null, "ACTIVE");
        CommuneSourceDto cEmptyParent = new CommuneSourceDto("00004", "Phường Ba Đình", "WARD", "   ", "ACTIVE");

        String checksumNull = validator.computeCanonicalChecksum(List.of(), List.of(cNullParent));
        String checksumEmpty = validator.computeCanonicalChecksum(List.of(), List.of(cEmptyParent));

        assertEquals(checksumNull, checksumEmpty, "Null parent and blank parent must serialize to identical empty field");
    }
}

