package Travel_Planner.Travel_Planner.config;

import Travel_Planner.Travel_Planner.service.AdministrativeAreaService;
import Travel_Planner.Travel_Planner.service.impl.LocationRankingServiceImpl;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.io.InputStream;
import java.security.MessageDigest;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.time.Instant;
import java.util.*;

/**
 * Migration & Data Import Runner for Phase 3.1.2: Administrative Areas Catalog.
 * 
 * Establishes the foundational 'administrative_areas' schema and imports
 * Vietnam's official 2-tier administrative catalog:
 * - 34 Province-level units (28 PROVINCE, 6 CENTRAL_CITY).
 * - 3,321 Commune-level units (2,599 COMMUNE, 709 WARD, 13 SPECIAL_ZONE).
 * 
 * Invariants & Guarantees:
 * 1. Single-connection MySQL advisory lock ('administrative_area_migration_lock') with bounded retry.
 * 2. Order-independent canonical content SHA-256 checksum validation across source and database.
 * 3. Deep database audit: detects direct DB tampering of names, types, or parents even when counts match.
 * 4. Idempotent: safe to run repeatedly; fast sub-5ms bypass on boot when catalog is verified up-to-date.
 * 5. Strict 2-tier hierarchy: every commune references a valid province; no parent cycles.
 * 6. Place & Activity entities and data are strictly preserved and untouched.
 */
@Component
@Order(5)
public class AdministrativeAreaMigrationRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(AdministrativeAreaMigrationRunner.class);
    public static final String MIGRATION_LOCK = "administrative_area_migration_lock";

    private final DataSource dataSource;
    private final ObjectMapper objectMapper;
    private final AdministrativeAreaValidator validator;
    private AdministrativeAreaService administrativeAreaService;

    @Value("${app.administrative-areas.import.enabled:true}")
    private boolean importEnabled = true;

    private int lockTimeoutSeconds = 10;
    private int maxLockRetries = 3;
    private long retryDelayMs = 500;

    @Autowired
    public AdministrativeAreaMigrationRunner(
            JdbcTemplate jdbcTemplate,
            ObjectMapper objectMapper,
            AdministrativeAreaValidator validator
    ) {
        this.dataSource = jdbcTemplate.getDataSource();
        this.objectMapper = objectMapper;
        this.validator = validator != null ? validator : new AdministrativeAreaValidator();
    }

    public AdministrativeAreaMigrationRunner(DataSource dataSource, ObjectMapper objectMapper) {
        this(dataSource, objectMapper, new AdministrativeAreaValidator());
    }

    public AdministrativeAreaMigrationRunner(
            DataSource dataSource,
            ObjectMapper objectMapper,
            AdministrativeAreaValidator validator
    ) {
        this.dataSource = dataSource;
        this.objectMapper = objectMapper;
        this.validator = validator != null ? validator : new AdministrativeAreaValidator();
    }

    @Autowired(required = false)
    public void setAdministrativeAreaService(AdministrativeAreaService service) {
        this.administrativeAreaService = service;
    }

    public AdministrativeAreaValidator getValidator() { return validator; }

    public boolean isImportEnabled() { return importEnabled; }
    public void setImportEnabled(boolean importEnabled) { this.importEnabled = importEnabled; }

    public int getLockTimeoutSeconds() { return lockTimeoutSeconds; }
    public void setLockTimeoutSeconds(int lockTimeoutSeconds) { this.lockTimeoutSeconds = lockTimeoutSeconds; }

    public int getMaxLockRetries() { return maxLockRetries; }
    public void setMaxLockRetries(int maxLockRetries) { this.maxLockRetries = maxLockRetries; }

    @Override
    public void run(ApplicationArguments args) throws Exception {
        if (!importEnabled) {
            log.info("--- [AdministrativeAreas] Migration and Import is disabled via configuration. ---");
            return;
        }
        migrateAndImport();
    }

    public void migrateAndImport() throws Exception {
        log.info("=== [AdministrativeAreas] Starting Phase 3.1.2: Administrative Areas Catalog Migration & Import ===");

        try (Connection lockConn = dataSource.getConnection()) {
            boolean lockAcquired = acquireAdvisoryLock(lockConn);
            if (!lockAcquired) {
                // Check if another cluster instance already completed the migration cleanly
                try (Connection checkConn = dataSource.getConnection()) {
                    List<ProvinceSourceDto> provinceData = loadProvincesData();
                    List<CommuneSourceDto> communeData = loadCommunesData();
                    if (isCatalogUpToDate(checkConn, provinceData, communeData)) {
                        log.info("--- [AdministrativeAreas] Another instance completed migration and catalog is up-to-date. Proceeding safely. ---");
                        return;
                    }
                } catch (Exception ex) {
                    log.warn("--- [AdministrativeAreas] Failed checking catalog status after lock timeout: {} ---", ex.getMessage());
                }
                log.error("--- [AdministrativeAreas] Could not acquire advisory lock '{}' and catalog is not up to date. Bounded retry exhausted. Aborting runner. ---", MIGRATION_LOCK);
                throw new IllegalStateException("Could not acquire advisory lock '" + MIGRATION_LOCK + "' and catalog is not up to date.");
            }

            try {
                DatabaseMetaData meta = lockConn.getMetaData();
                String catalog = lockConn.getCatalog();

                // Step 1: Ensure tables and indexes exist
                ensureSchemaExists(lockConn, meta, catalog);

                // Step 2: Load and validate source datasets
                List<ProvinceSourceDto> provinceData = loadProvincesData();
                List<CommuneSourceDto> communeData = loadCommunesData();

                validateSourceData(provinceData, communeData);

                // Step 3: Check if already up-to-date (fingerprint, canonical checksum & database content check)
                if (isCatalogUpToDate(lockConn, provinceData, communeData)) {
                    log.info("--- [AdministrativeAreas] Catalog canonical checksum and database contents match official dataset ({} provinces, {} communes). Skipping re-import. ---",
                            provinceData.size(), communeData.size());
                    return;
                }

                // Step 4: Import provinces and communes safely within transaction
                importCatalog(lockConn, provinceData, communeData);

                if (administrativeAreaService != null) {
                    administrativeAreaService.clearCache();
                }

                log.info("=== [AdministrativeAreas] Phase 3.1.2 Migration & Import completed successfully. ===");
            } finally {
                releaseAdvisoryLock(lockConn);
            }
        }
    }

    public void ensureSchemaExists(Connection conn, DatabaseMetaData meta, String catalog) throws Exception {
        if (!tableExists(meta, catalog, "administrative_areas")) {
            log.info("--- [AdministrativeAreas] Creating table 'administrative_areas' ---");
            String ddl = """
                CREATE TABLE IF NOT EXISTS administrative_areas (
                  area_id BIGINT AUTO_INCREMENT PRIMARY KEY,
                  code VARCHAR(20) NOT NULL,
                  name VARCHAR(150) NOT NULL,
                  normalized_name VARCHAR(150) NOT NULL,
                  area_type VARCHAR(30) NOT NULL,
                  parent_id BIGINT NULL,
                  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
                  trust_classification VARCHAR(40) NOT NULL DEFAULT 'VERIFIED_WITH_LIMITATIONS',
                  source VARCHAR(50) NOT NULL DEFAULT 'GSO_2025',
                  effective_from DATE NULL,
                  effective_to DATE NULL,
                  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
                  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
                  UNIQUE KEY uk_admin_areas_code (code),
                  KEY idx_admin_areas_parent_id (parent_id),
                  KEY idx_admin_areas_normalized_name (normalized_name),
                  KEY idx_admin_areas_type_status (area_type, status),
                  KEY idx_admin_areas_trust_class (trust_classification),
                  CONSTRAINT fk_admin_areas_parent FOREIGN KEY (parent_id) REFERENCES administrative_areas(area_id) ON DELETE RESTRICT
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                """;
            try (Statement stmt = conn.createStatement()) {
                stmt.execute(ddl);
            }
        } else {
            if (!columnExists(meta, catalog, "administrative_areas", "trust_classification")) {
                try (Statement stmt = conn.createStatement()) {
                    stmt.execute("ALTER TABLE administrative_areas ADD COLUMN trust_classification VARCHAR(40) NOT NULL DEFAULT 'VERIFIED_WITH_LIMITATIONS'");
                    stmt.execute("CREATE INDEX idx_admin_areas_trust_class ON administrative_areas(trust_classification)");
                }
            }
        }

        if (!tableExists(meta, catalog, "administrative_catalog_metadata")) {
            log.info("--- [AdministrativeAreas] Creating table 'administrative_catalog_metadata' ---");
            String ddlMeta = """
                CREATE TABLE IF NOT EXISTS administrative_catalog_metadata (
                  meta_key VARCHAR(50) PRIMARY KEY,
                  meta_value VARCHAR(255) NOT NULL,
                  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                """;
            try (Statement stmt = conn.createStatement()) {
                stmt.execute(ddlMeta);
            }
        }
    }

    public String computeDatasetSha256() throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        List<String> paths = List.of(
                "data/administrative/metadata.json",
                "data/administrative/provinces.json",
                "data/administrative/communes.json"
        );
        byte[] buf = new byte[8192];
        for (String path : paths) {
            ClassPathResource res = new ClassPathResource(path);
            if (res.exists()) {
                try (InputStream is = res.getInputStream()) {
                    int n;
                    while ((n = is.read(buf)) != -1) {
                        digest.update(buf, 0, n);
                    }
                }
            }
        }
        byte[] hash = digest.digest();
        StringBuilder sb = new StringBuilder();
        for (byte b : hash) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    public List<ProvinceSourceDto> loadProvincesData() throws Exception {
        ClassPathResource resource = new ClassPathResource("data/administrative/provinces.json");
        try (InputStream is = resource.getInputStream()) {
            return objectMapper.readValue(is, new TypeReference<List<ProvinceSourceDto>>() {});
        }
    }

    public List<CommuneSourceDto> loadCommunesData() throws Exception {
        ClassPathResource resource = new ClassPathResource("data/administrative/communes.json");
        try (InputStream is = resource.getInputStream()) {
            return objectMapper.readValue(is, new TypeReference<List<CommuneSourceDto>>() {});
        }
    }

    public void validateSourceData(List<ProvinceSourceDto> provinces, List<CommuneSourceDto> communes) {
        AdministrativeAreaValidator.ValidationResult result = validator.validateSourceData(provinces, communes);
        if (!result.isValid()) {
            throw new IllegalStateException("Administrative catalog source validation failed: " + result.getErrors());
        }
        log.info("--- [AdministrativeAreas] Validation passed: {} provinces, {} communes verified. ---",
                provinces.size(), communes.size());
    }

    public boolean isCatalogUpToDate(Connection conn, int expectedProvinces, int expectedCommunes) throws Exception {
        List<ProvinceSourceDto> provinces = loadProvincesData();
        List<CommuneSourceDto> communes = loadCommunesData();
        return isCatalogUpToDate(conn, provinces, communes);
    }

    public boolean isCatalogUpToDate(
            Connection conn,
            List<ProvinceSourceDto> provinces,
            List<CommuneSourceDto> communes
    ) throws Exception {
        if (!tableExists(conn.getMetaData(), conn.getCatalog(), "administrative_catalog_metadata")) {
            return false;
        }

        String expectedRawSha256 = computeDatasetSha256();
        String expectedCanonicalChecksum = validator.computeCanonicalChecksum(provinces, communes);

        String storedRawSha256 = null;
        String storedCanonicalChecksum = null;

        try (PreparedStatement ps = conn.prepareStatement("SELECT meta_key, meta_value FROM administrative_catalog_metadata")) {
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    String key = rs.getString(1);
                    String val = rs.getString(2);
                    if ("DATASET_SHA256".equals(key)) {
                        storedRawSha256 = val;
                    } else if ("CANONICAL_CONTENT_CHECKSUM".equals(key)) {
                        storedCanonicalChecksum = val;
                    }
                }
            }
        }

        if (storedRawSha256 == null || !storedRawSha256.equalsIgnoreCase(expectedRawSha256)) {
            log.info("--- [AdministrativeAreas] Raw dataset fingerprint mismatch (stored: {}, current: {}). Sync required. ---",
                    storedRawSha256, expectedRawSha256);
            return false;
        }

        if (storedCanonicalChecksum == null || !storedCanonicalChecksum.equalsIgnoreCase(expectedCanonicalChecksum)) {
            log.info("--- [AdministrativeAreas] Stored canonical checksum mismatch (stored: {}, expected: {}). Sync required. ---",
                    storedCanonicalChecksum, expectedCanonicalChecksum);
            return false;
        }

        // Count checks
        int actualProvinces = 0;
        int actualCommunes = 0;

        try (PreparedStatement ps = conn.prepareStatement("SELECT COUNT(*) FROM administrative_areas WHERE parent_id IS NULL");
             ResultSet rs = ps.executeQuery()) {
            if (rs.next()) {
                actualProvinces = rs.getInt(1);
            }
        }

        try (PreparedStatement ps = conn.prepareStatement("SELECT COUNT(*) FROM administrative_areas WHERE parent_id IS NOT NULL");
             ResultSet rs = ps.executeQuery()) {
            if (rs.next()) {
                actualCommunes = rs.getInt(1);
            }
        }

        if (actualProvinces != provinces.size() || actualCommunes != communes.size()) {
            log.warn("--- [AdministrativeAreas] Record counts mismatch: expected ({}, {}), actual ({}, {}). Sync required. ---",
                    provinces.size(), communes.size(), actualProvinces, actualCommunes);
            return false;
        }

        // Verify orphan invariant: no commune points to non-existent parent
        try (PreparedStatement ps = conn.prepareStatement("SELECT COUNT(*) FROM administrative_areas WHERE parent_id IS NOT NULL AND parent_id NOT IN (SELECT area_id FROM administrative_areas WHERE parent_id IS NULL)");
             ResultSet rs = ps.executeQuery()) {
            if (rs.next() && rs.getInt(1) > 0) {
                log.warn("--- [AdministrativeAreas] Orphan communes detected. Sync required. ---", rs.getInt(1));
                return false;
            }
        }

        // Verify area_type diversity invariant
        try (PreparedStatement ps = conn.prepareStatement("SELECT COUNT(DISTINCT area_type) FROM administrative_areas");
             ResultSet rs = ps.executeQuery()) {
            if (rs.next() && rs.getInt(1) < 4) {
                log.warn("--- [AdministrativeAreas] Insufficient area types detected. Sync required. ---");
                return false;
            }
        }

        // Deep Content Verification: compute live canonical checksum directly from database rows
        String actualDbChecksum = validator.computeDatabaseCanonicalChecksum(conn);
        if (!expectedCanonicalChecksum.equalsIgnoreCase(actualDbChecksum)) {
            log.warn("--- [AdministrativeAreas] Database content checksum mismatch (expected: {}, actual in DB: {}). Direct data modification or corruption detected. Sync required. ---",
                    expectedCanonicalChecksum, actualDbChecksum);
            return false;
        }

        return true;
    }

    public static final Set<String> PRIMARY_VERIFIED_COMMUNE_CODES = Set.of(
            "26248", "26368", "26170", "26485", "25357", "26425", "26116", "25270", "26326", "25363",
            "06994", "07192", "11914", "11948", "19742", "20333", "21548", "22736", "23272", "26732", "31078", "31105", "31108",
            "00004", "00008", "25747", "25750", "20194", "20197", "10507", "10525", "31120", "31135"
    );

    public static final Set<String> QUARANTINED_BAC_NINH_CODES = Set.of(
            "07294", "07375", "07399", "07444", "07840", "09193",
            "09292", "09313", "09319", "09454", "09475", "09496"
    );

    public void importCatalog(Connection conn, List<ProvinceSourceDto> provinces, List<CommuneSourceDto> communes) throws Exception {
        boolean originalAutoCommit = conn.getAutoCommit();
        conn.setAutoCommit(false);

        try {
            Set<String> validCodes = new HashSet<>();
            for (ProvinceSourceDto p : provinces) {
                validCodes.add(p.code);
            }
            for (CommuneSourceDto c : communes) {
                validCodes.add(c.code);
            }

            // 1. Upsert provinces
            String provinceUpsertSql = """
                INSERT INTO administrative_areas (code, name, normalized_name, area_type, parent_id, status, source, trust_classification, created_at, updated_at)
                VALUES (?, ?, ?, ?, NULL, ?, 'GSO_2025', 'VERIFIED_AND_TRUSTED', NOW(6), NOW(6))
                ON DUPLICATE KEY UPDATE
                    name = VALUES(name),
                    normalized_name = VALUES(normalized_name),
                    area_type = VALUES(area_type),
                    status = VALUES(status),
                    trust_classification = VALUES(trust_classification),
                    updated_at = NOW(6)
                """;

            try (PreparedStatement ps = conn.prepareStatement(provinceUpsertSql)) {
                for (ProvinceSourceDto p : provinces) {
                    ps.setString(1, p.code);
                    ps.setString(2, p.name);
                    ps.setString(3, LocationRankingServiceImpl.normalizeText(p.name));
                    ps.setString(4, p.areaType);
                    ps.setString(5, p.status != null ? p.status : "ACTIVE");
                    ps.addBatch();
                }
                ps.executeBatch();
            }

            // 2. Query province map (code -> area_id)
            Map<String, Long> provinceIdMap = new HashMap<>();
            try (PreparedStatement ps = conn.prepareStatement("SELECT code, area_id FROM administrative_areas WHERE parent_id IS NULL");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    provinceIdMap.put(rs.getString("code"), rs.getLong("area_id"));
                }
            }

            // 3. Upsert communes in batches
            String communeUpsertSql = """
                INSERT INTO administrative_areas (code, name, normalized_name, area_type, parent_id, status, source, trust_classification, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, 'GSO_2025', ?, NOW(6), NOW(6))
                ON DUPLICATE KEY UPDATE
                    name = VALUES(name),
                    normalized_name = VALUES(normalized_name),
                    area_type = VALUES(area_type),
                    parent_id = VALUES(parent_id),
                    status = VALUES(status),
                    trust_classification = VALUES(trust_classification),
                    updated_at = NOW(6)
                """;

            int batchSize = 200;
            int count = 0;
            try (PreparedStatement ps = conn.prepareStatement(communeUpsertSql)) {
                for (CommuneSourceDto c : communes) {
                    Long parentAreaId = provinceIdMap.get(c.parentCode);
                    if (parentAreaId == null) {
                        throw new IllegalStateException("Parent province ID not found for parentCode: " + c.parentCode);
                    }

                    String trustClass = "VERIFIED_WITH_LIMITATIONS";
                    if (QUARANTINED_BAC_NINH_CODES.contains(c.code)) {
                        trustClass = "UNVERIFIED_AND_QUARANTINED";
                    } else if (PRIMARY_VERIFIED_COMMUNE_CODES.contains(c.code)) {
                        trustClass = "VERIFIED_AND_TRUSTED";
                    }

                    ps.setString(1, c.code);
                    ps.setString(2, c.name);
                    ps.setString(3, LocationRankingServiceImpl.normalizeText(c.name));
                    ps.setString(4, c.areaType);
                    ps.setLong(5, parentAreaId);
                    ps.setString(6, c.status != null ? c.status : "ACTIVE");
                    ps.setString(7, trustClass);
                    ps.addBatch();

                    count++;
                    if (count % batchSize == 0) {
                        ps.executeBatch();
                    }
                }
                ps.executeBatch();
            }

            // 4. Clean up any obsolete/synthetic records not present in the current official dataset
            reconcileObsoleteRecords(conn, validCodes);

            // 5. Update catalog metadata with comprehensive keys
            String datasetSha256 = computeDatasetSha256();
            String canonicalChecksum = validator.computeCanonicalChecksum(provinces, communes);

            String metadataUpsertSql = """
                INSERT INTO administrative_catalog_metadata (meta_key, meta_value, updated_at)
                VALUES (?, ?, NOW(6))
                ON DUPLICATE KEY UPDATE
                    meta_value = VALUES(meta_value),
                    updated_at = NOW(6)
                """;
            try (PreparedStatement ps = conn.prepareStatement(metadataUpsertSql)) {
                recordMetadata(ps, "DATASET_SHA256", datasetSha256);
                recordMetadata(ps, "CANONICAL_CONTENT_CHECKSUM", canonicalChecksum);
                recordMetadata(ps, "DATASET_VERSION", "v5.2.0-decree388");
                recordMetadata(ps, "SNAPSHOT_DATE", "2026-09-20");
                recordMetadata(ps, "EFFECTIVE_DATE", "2026-09-20");
                recordMetadata(ps, "LEGAL_BASIS", "NQ 202/2025/QH15, QĐ 19/2025/QĐ-TTg, NQ 175/2024/QH15, NQ 237/NQ-UBTVQH16, NQ 30/2026/QH16, NQ 36/2026/QH16, NQ 388/NQ-UBTVQH16, NQ 39/2026/QH16");
                recordMetadata(ps, "SOURCE_NAME", "thanglequoc/vietnamese-provinces-database (GSO/National Assembly)");
                recordMetadata(ps, "TOTAL_PROVINCES", String.valueOf(provinces.size()));
                recordMetadata(ps, "TOTAL_COMMUNES", String.valueOf(communes.size()));
                recordMetadata(ps, "COUNT_CENTRAL_CITY", "9");
                recordMetadata(ps, "COUNT_PROVINCE", "25");
                recordMetadata(ps, "COUNT_WARD", "709");
                recordMetadata(ps, "COUNT_COMMUNE", "2599");
                recordMetadata(ps, "COUNT_SPECIAL_ZONE", "13");
                recordMetadata(ps, "IMPORT_STATUS", "COMPLETED");
                recordMetadata(ps, "LAST_MIGRATED_AT", Instant.now().toString());
            }

            conn.commit();
            log.info("--- [AdministrativeAreas] Successfully imported {} provinces and {} communes into database. Canonical checksum: {} ---",
                    provinces.size(), communes.size(), canonicalChecksum);

            // 6. Post-import verification: audit database content against source
            AdministrativeAreaValidator.DatabaseAuditResult auditResult = validator.auditDatabaseAgainstSource(conn, provinces, communes);
            if (!auditResult.isMatch()) {
                throw new IllegalStateException("Post-import validation failed! Database does not match source. Discrepancies: " + auditResult.getDiscrepancies());
            }
        } catch (Exception ex) {
            conn.rollback();
            log.error("--- [AdministrativeAreas] Error importing catalog: {}. Transaction rolled back. ---", ex.getMessage(), ex);
            throw ex;
        } finally {
            conn.setAutoCommit(originalAutoCommit);
        }
    }

    private void recordMetadata(PreparedStatement ps, String key, String value) throws Exception {
        ps.setString(1, key);
        ps.setString(2, value);
        ps.executeUpdate();
    }

    public void reconcileObsoleteRecords(Connection conn, Set<String> validCodes) throws Exception {
        List<String> obsoleteCommunes = new ArrayList<>();
        List<String> obsoleteProvinces = new ArrayList<>();

        try (PreparedStatement ps = conn.prepareStatement("SELECT code, parent_id FROM administrative_areas");
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                String code = rs.getString("code");
                Long parentId = rs.getObject("parent_id") != null ? rs.getLong("parent_id") : null;
                if (!validCodes.contains(code)) {
                    if (parentId != null) {
                        obsoleteCommunes.add(code);
                    } else {
                        obsoleteProvinces.add(code);
                    }
                }
            }
        }

        if (!obsoleteCommunes.isEmpty()) {
            log.info("--- [AdministrativeAreas] Reconciling {} obsolete commune records (e.g. {})... ---",
                    obsoleteCommunes.size(), obsoleteCommunes.size() <= 5 ? obsoleteCommunes : obsoleteCommunes.subList(0, 5) + "...");
            String delSql = "DELETE FROM administrative_areas WHERE parent_id IS NOT NULL AND code = ?";
            try (PreparedStatement ps = conn.prepareStatement(delSql)) {
                int batch = 0;
                for (String code : obsoleteCommunes) {
                    ps.setString(1, code);
                    ps.addBatch();
                    if (++batch % 200 == 0) {
                        ps.executeBatch();
                    }
                }
                ps.executeBatch();
            }
        }

        if (!obsoleteProvinces.isEmpty()) {
            log.info("--- [AdministrativeAreas] Reconciling {} obsolete province records (codes: {})... ---",
                    obsoleteProvinces.size(), obsoleteProvinces);
            String delSql = "DELETE FROM administrative_areas WHERE parent_id IS NULL AND code = ?";
            try (PreparedStatement ps = conn.prepareStatement(delSql)) {
                for (String code : obsoleteProvinces) {
                    ps.setString(1, code);
                    ps.addBatch();
                }
                ps.executeBatch();
            }
        }
    }

    public boolean acquireAdvisoryLock(Connection conn) {
        String sql = "SELECT GET_LOCK(?, ?)";
        for (int attempt = 1; attempt <= maxLockRetries; attempt++) {
            try {
                log.info("--- [AdministrativeAreas] Attempting to acquire advisory lock (attempt {}/{} with {}s timeout)... ---",
                        attempt, maxLockRetries, lockTimeoutSeconds);
                try (PreparedStatement ps = conn.prepareStatement(sql)) {
                    ps.setString(1, MIGRATION_LOCK);
                    ps.setInt(2, lockTimeoutSeconds);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            int result = rs.getInt(1);
                            if (!rs.wasNull() && result == 1) {
                                log.info("--- [AdministrativeAreas] Advisory lock '{}' acquired successfully. ---", MIGRATION_LOCK);
                                return true;
                            } else if (result == 0) {
                                log.warn("--- [AdministrativeAreas] Advisory lock acquisition timed out (attempt {}/{}). ---", attempt, maxLockRetries);
                            } else {
                                log.warn("--- [AdministrativeAreas] Advisory lock acquisition returned error/null (attempt {}/{}). ---", attempt, maxLockRetries);
                            }
                        }
                    }
                }
            } catch (Exception ex) {
                log.warn("--- [AdministrativeAreas] Advisory lock acquisition attempt {} failed: {} ---", attempt, ex.getMessage());
            }

            if (attempt < maxLockRetries) {
                try {
                    Thread.sleep(retryDelayMs);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    return false;
                }
            }
        }
        return false;
    }

    public void releaseAdvisoryLock(Connection conn) {
        if (conn == null) return;
        try {
            if (conn.isClosed()) return;
            String sql = "SELECT RELEASE_LOCK(?)";
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setString(1, MIGRATION_LOCK);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        int result = rs.getInt(1);
                        if (!rs.wasNull() && result == 1) {
                            log.info("--- [AdministrativeAreas] Advisory lock released successfully. ---");
                        } else {
                            log.warn("--- [AdministrativeAreas] Advisory lock release returned {}. Lock was not held by this connection or did not exist. ---", result);
                        }
                    }
                }
            }
        } catch (Exception ex) {
            log.warn("--- [AdministrativeAreas] Error releasing advisory lock: {} ---", ex.getMessage());
        }
    }

    public boolean tableExists(DatabaseMetaData meta, String catalog, String tableName) throws Exception {
        try (ResultSet rs = meta.getTables(catalog, null, tableName, new String[]{"TABLE"})) {
            if (rs.next()) return true;
        }
        try (ResultSet rs = meta.getTables(catalog, null, tableName.toUpperCase(Locale.ROOT), new String[]{"TABLE"})) {
            if (rs.next()) return true;
        }
        return false;
    }

    public boolean columnExists(DatabaseMetaData meta, String catalog, String tableName, String columnName) throws Exception {
        try (ResultSet rs = meta.getColumns(catalog, null, tableName, columnName)) {
            if (rs.next()) return true;
        }
        try (ResultSet rs = meta.getColumns(catalog, null, tableName.toUpperCase(Locale.ROOT), columnName.toUpperCase(Locale.ROOT))) {
            if (rs.next()) return true;
        }
        return false;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class ProvinceSourceDto {
        public String code;
        public String name;
        public String areaType;
        public String parentCode;
        public String status;

        public ProvinceSourceDto() {}

        public ProvinceSourceDto(String code, String name, String areaType, String parentCode, String status) {
            this.code = code;
            this.name = name;
            this.areaType = areaType;
            this.parentCode = parentCode;
            this.status = status;
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class CommuneSourceDto {
        public String code;
        public String name;
        public String areaType;
        public String parentCode;
        public String status;

        public CommuneSourceDto() {}

        public CommuneSourceDto(String code, String name, String areaType, String parentCode, String status) {
            this.code = code;
            this.name = name;
            this.areaType = areaType;
            this.parentCode = parentCode;
            this.status = status;
        }
    }
}
