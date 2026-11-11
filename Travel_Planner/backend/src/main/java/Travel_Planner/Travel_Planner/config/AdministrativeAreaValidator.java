package Travel_Planner.Travel_Planner.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.*;

/**
 * Independent Validator & Checksum Engine for Phase 3.1.2 Administrative Areas Catalog.
 *
 * Provides:
 * 1. Structural and Count validation (34 provinces, 3,321 communes, breakdown by area type).
 * 2. Hierarchy integrity (0 orphan communes, no province parent, 2-tier tree, no cycles).
 * 3. Canonical order-independent SHA-256 checksum computation for source dataset and database contents.
 * 4. Deep database-to-source reconciliation audit pinpointing field-level discrepancies.
 */
@Component
public class AdministrativeAreaValidator {

    private static final Logger log = LoggerFactory.getLogger(AdministrativeAreaValidator.class);
    public static final String CANONICAL_SCHEMA_VERSION = "v1";

    public static final int EXPECTED_TOTAL_PROVINCES = 34;
    public static final int EXPECTED_CENTRAL_CITIES = 9;
    public static final int EXPECTED_PROVINCES = 25;

    public static final int EXPECTED_TOTAL_COMMUNES = 3321;
    public static final int EXPECTED_WARDS = 709;
    public static final int EXPECTED_COMMUNES_COUNT = 2599;
    public static final int EXPECTED_SPECIAL_ZONES = 13;

    public static class ValidationResult {
        private final boolean valid;
        private final List<String> errors;

        public ValidationResult(boolean valid, List<String> errors) {
            this.valid = valid;
            this.errors = Collections.unmodifiableList(errors);
        }

        public boolean isValid() { return valid; }
        public List<String> getErrors() { return errors; }

        @Override
        public String toString() {
            return "ValidationResult{valid=" + valid + ", errors=" + errors + "}";
        }
    }

    public static class DatabaseAuditResult {
        private final boolean match;
        private final String sourceChecksum;
        private final String databaseChecksum;
        private final List<String> discrepancies;

        public DatabaseAuditResult(boolean match, String sourceChecksum, String databaseChecksum, List<String> discrepancies) {
            this.match = match;
            this.sourceChecksum = sourceChecksum;
            this.databaseChecksum = databaseChecksum;
            this.discrepancies = Collections.unmodifiableList(discrepancies);
        }

        public boolean isMatch() { return match; }
        public String getSourceChecksum() { return sourceChecksum; }
        public String getDatabaseChecksum() { return databaseChecksum; }
        public List<String> getDiscrepancies() { return discrepancies; }

        @Override
        public String toString() {
            return "DatabaseAuditResult{match=" + match + ", sourceChecksum=" + sourceChecksum +
                    ", databaseChecksum=" + databaseChecksum + ", discrepanciesCount=" + discrepancies.size() + "}";
        }
    }

    /**
     * Validates structural invariants, counts, type distributions, and hierarchical consistency of raw sources.
     */
    public ValidationResult validateSourceData(
            List<AdministrativeAreaMigrationRunner.ProvinceSourceDto> provinces,
            List<AdministrativeAreaMigrationRunner.CommuneSourceDto> communes
    ) {
        List<String> errors = new ArrayList<>();

        if (provinces == null || provinces.isEmpty()) {
            errors.add("Province source dataset is null or empty");
            return new ValidationResult(false, errors);
        }
        if (communes == null || communes.isEmpty()) {
            errors.add("Commune source dataset is null or empty");
            return new ValidationResult(false, errors);
        }

        // 1. Total Counts
        if (provinces.size() != EXPECTED_TOTAL_PROVINCES) {
            errors.add(String.format("Expected exactly %d provinces, found %d", EXPECTED_TOTAL_PROVINCES, provinces.size()));
        }
        if (communes.size() != EXPECTED_TOTAL_COMMUNES) {
            errors.add(String.format("Expected exactly %d communes, found %d", EXPECTED_TOTAL_COMMUNES, communes.size()));
        }

        // 2. Province Breakdown & Integrity
        Set<String> provinceCodes = new HashSet<>();
        int centralCityCount = 0;
        int provinceTypeCount = 0;

        for (AdministrativeAreaMigrationRunner.ProvinceSourceDto p : provinces) {
            if (p.code == null || p.code.isBlank()) {
                errors.add("Province has null or blank code: " + p);
                continue;
            }
            if (p.name == null || p.name.isBlank()) {
                errors.add("Province " + p.code + " has null or blank name");
            }
            if (!provinceCodes.add(p.code)) {
                errors.add("Duplicate province code: " + p.code);
            }
            if (p.parentCode != null && !p.parentCode.isBlank()) {
                errors.add("Province " + p.code + " cannot have parentCode (must be root): " + p.parentCode);
            }
            if ("CENTRAL_CITY".equals(p.areaType)) {
                centralCityCount++;
            } else if ("PROVINCE".equals(p.areaType)) {
                provinceTypeCount++;
            } else {
                errors.add("Invalid province areaType for code " + p.code + ": " + p.areaType);
            }
        }

        if (centralCityCount != EXPECTED_CENTRAL_CITIES) {
            errors.add(String.format("Expected %d CENTRAL_CITY units, found %d", EXPECTED_CENTRAL_CITIES, centralCityCount));
        }
        if (provinceTypeCount != EXPECTED_PROVINCES) {
            errors.add(String.format("Expected %d PROVINCE units, found %d", EXPECTED_PROVINCES, provinceTypeCount));
        }

        // 3. Commune Breakdown & Hierarchy
        Set<String> communeCodes = new HashSet<>();
        int wardCount = 0;
        int communeCount = 0;
        int specialZoneCount = 0;

        for (AdministrativeAreaMigrationRunner.CommuneSourceDto c : communes) {
            if (c.code == null || c.code.isBlank()) {
                errors.add("Commune has null or blank code: " + c);
                continue;
            }
            if (c.name == null || c.name.isBlank()) {
                errors.add("Commune " + c.code + " has null or blank name");
            }
            if (!communeCodes.add(c.code)) {
                errors.add("Duplicate commune code: " + c.code);
            }
            if (provinceCodes.contains(c.code)) {
                errors.add("Commune code collides with province code: " + c.code);
            }
            if (c.parentCode == null || c.parentCode.isBlank()) {
                errors.add("Commune " + c.code + " is orphan (missing parentCode)");
            } else if (!provinceCodes.contains(c.parentCode)) {
                errors.add("Commune " + c.code + " references non-existent parent province: " + c.parentCode);
            }

            if ("WARD".equals(c.areaType)) {
                wardCount++;
            } else if ("COMMUNE".equals(c.areaType)) {
                communeCount++;
            } else if ("SPECIAL_ZONE".equals(c.areaType)) {
                specialZoneCount++;
            } else {
                errors.add("Invalid commune areaType for code " + c.code + ": " + c.areaType);
            }
        }

        if (wardCount != EXPECTED_WARDS) {
            errors.add(String.format("Expected %d WARD units, found %d", EXPECTED_WARDS, wardCount));
        }
        if (communeCount != EXPECTED_COMMUNES_COUNT) {
            errors.add(String.format("Expected %d COMMUNE units, found %d", EXPECTED_COMMUNES_COUNT, communeCount));
        }
        if (specialZoneCount != EXPECTED_SPECIAL_ZONES) {
            errors.add(String.format("Expected %d SPECIAL_ZONE units, found %d", EXPECTED_SPECIAL_ZONES, specialZoneCount));
        }

        return new ValidationResult(errors.isEmpty(), errors);
    }

    /**
     * Computes the order-independent canonical content SHA-256 checksum from source DTOs.
     * Normalizes each entry into: code|name|areaType|parentCode
     * Sorted alphabetically and prefixed with schema version.
     */
    public String computeCanonicalChecksum(
            List<AdministrativeAreaMigrationRunner.ProvinceSourceDto> provinces,
            List<AdministrativeAreaMigrationRunner.CommuneSourceDto> communes
    ) {
        List<String> entries = new ArrayList<>(provinces.size() + communes.size());

        for (AdministrativeAreaMigrationRunner.ProvinceSourceDto p : provinces) {
            String pCode = p.parentCode != null ? p.parentCode.trim() : "";
            entries.add(p.code.trim() + "|" + p.name.trim() + "|" + p.areaType.trim() + "|" + pCode);
        }
        for (AdministrativeAreaMigrationRunner.CommuneSourceDto c : communes) {
            String pCode = c.parentCode != null ? c.parentCode.trim() : "";
            entries.add(c.code.trim() + "|" + c.name.trim() + "|" + c.areaType.trim() + "|" + pCode);
        }

        Collections.sort(entries);
        return hashCanonicalEntries(entries);
    }

    /**
     * Computes the order-independent canonical content SHA-256 checksum directly from database rows.
     */
    public String computeDatabaseCanonicalChecksum(Connection conn) throws Exception {
        String sql = """
            SELECT c.code, c.name, c.area_type, p.code AS parent_code
            FROM administrative_areas c
            LEFT JOIN administrative_areas p ON c.parent_id = p.area_id
            """;

        List<String> entries = new ArrayList<>();
        try (PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                String code = rs.getString("code");
                String name = rs.getString("name");
                String areaType = rs.getString("area_type");
                String parentCode = rs.getString("parent_code");
                if (parentCode == null) parentCode = "";

                entries.add(code.trim() + "|" + name.trim() + "|" + areaType.trim() + "|" + parentCode.trim());
            }
        }

        Collections.sort(entries);
        return hashCanonicalEntries(entries);
    }

    /**
     * Performs a comprehensive record-by-record comparison between database and source records.
     */
    public DatabaseAuditResult auditDatabaseAgainstSource(
            Connection conn,
            List<AdministrativeAreaMigrationRunner.ProvinceSourceDto> provinces,
            List<AdministrativeAreaMigrationRunner.CommuneSourceDto> communes
    ) throws Exception {
        String sourceChecksum = computeCanonicalChecksum(provinces, communes);
        String dbChecksum = computeDatabaseCanonicalChecksum(conn);

        List<String> discrepancies = new ArrayList<>();

        // Map source records by code
        Map<String, String> sourceCanonicalMap = new HashMap<>();
        for (AdministrativeAreaMigrationRunner.ProvinceSourceDto p : provinces) {
            String pCode = p.parentCode != null ? p.parentCode.trim() : "";
            sourceCanonicalMap.put(p.code.trim(), p.code.trim() + "|" + p.name.trim() + "|" + p.areaType.trim() + "|" + pCode);
        }
        for (AdministrativeAreaMigrationRunner.CommuneSourceDto c : communes) {
            String pCode = c.parentCode != null ? c.parentCode.trim() : "";
            sourceCanonicalMap.put(c.code.trim(), c.code.trim() + "|" + c.name.trim() + "|" + c.areaType.trim() + "|" + pCode);
        }

        // Map DB records by code
        Map<String, String> dbCanonicalMap = new HashMap<>();
        String sql = """
            SELECT c.code, c.name, c.area_type, p.code AS parent_code
            FROM administrative_areas c
            LEFT JOIN administrative_areas p ON c.parent_id = p.area_id
            """;
        try (PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                String code = rs.getString("code").trim();
                String name = rs.getString("name").trim();
                String areaType = rs.getString("area_type").trim();
                String parentCode = rs.getString("parent_code");
                if (parentCode == null) parentCode = "";
                parentCode = parentCode.trim();

                dbCanonicalMap.put(code, code + "|" + name + "|" + areaType + "|" + parentCode);
            }
        }

        // Find missing or modified records
        for (Map.Entry<String, String> entry : sourceCanonicalMap.entrySet()) {
            String code = entry.getKey();
            String sourceEntry = entry.getValue();
            String dbEntry = dbCanonicalMap.get(code);

            if (dbEntry == null) {
                discrepancies.add("Missing record in database: " + sourceEntry);
            } else if (!sourceEntry.equals(dbEntry)) {
                discrepancies.add(String.format("Record discrepancy for code %s: expected [%s], found [%s]", code, sourceEntry, dbEntry));
            }
        }

        // Find extra records in DB
        for (String dbCode : dbCanonicalMap.keySet()) {
            if (!sourceCanonicalMap.containsKey(dbCode)) {
                discrepancies.add("Unexpected extra record in database: " + dbCanonicalMap.get(dbCode));
            }
        }

        boolean match = discrepancies.isEmpty() && sourceChecksum.equalsIgnoreCase(dbChecksum);
        return new DatabaseAuditResult(match, sourceChecksum, dbChecksum, discrepancies);
    }

    private String hashCanonicalEntries(List<String> sortedEntries) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            digest.update((CANONICAL_SCHEMA_VERSION + "\n").getBytes(StandardCharsets.UTF_8));
            for (String entry : sortedEntries) {
                digest.update((entry + "\n").getBytes(StandardCharsets.UTF_8));
            }
            byte[] hash = digest.digest();
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 algorithm not available", e);
        }
    }
}

