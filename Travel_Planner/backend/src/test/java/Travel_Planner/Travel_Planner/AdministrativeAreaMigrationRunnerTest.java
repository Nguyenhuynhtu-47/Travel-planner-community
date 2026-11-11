package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.AdministrativeAreaMigrationRunner;
import Travel_Planner.Travel_Planner.config.AdministrativeAreaMigrationRunner.CommuneSourceDto;
import Travel_Planner.Travel_Planner.config.AdministrativeAreaMigrationRunner.ProvinceSourceDto;
import Travel_Planner.Travel_Planner.model.AdministrativeArea;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaType;
import Travel_Planner.Travel_Planner.repository.AdministrativeAreaRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

import java.sql.Connection;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
public class AdministrativeAreaMigrationRunnerTest {

    @Autowired
    private AdministrativeAreaMigrationRunner migrationRunner;

    @Autowired
    private AdministrativeAreaRepository repository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    @DisplayName("Verify full official dataset imports 34 provinces and 3,321 communes")
    void testMigrationAndImport_ImportsAllProvincesAndCommunes() throws Exception {
        migrationRunner.migrateAndImport();

        long provinceCount = repository.countByAreaTypeIn(
                List.of(AdministrativeAreaType.PROVINCE, AdministrativeAreaType.CENTRAL_CITY));
        long communeCount = repository.countByParentIsNotNull();

        assertEquals(34, provinceCount, "Must have exactly 34 official province-level units");
        assertEquals(3321, communeCount, "Must have exactly 3,321 official commune-level units");
        assertEquals(3355, repository.count(), "Total administrative areas must equal 3,355");

        // Verify known units exist with valid parent
        AdministrativeArea hcm = repository.findByCode("79").orElseThrow();
        assertEquals("Thành phố Hồ Chí Minh", hcm.getName());
        assertEquals(AdministrativeAreaType.CENTRAL_CITY, hcm.getAreaType());
        assertNull(hcm.getParent(), "Province-level unit must have parent = null");

        AdministrativeArea hn = repository.findByCode("01").orElseThrow();
        assertEquals("Thành phố Hà Nội", hn.getName());
        assertEquals(AdministrativeAreaType.CENTRAL_CITY, hn.getAreaType());
        assertNull(hn.getParent());

        // Check Ba Đình commune
        AdministrativeArea sampleCommune = repository.findByCodeWithParent("00004").orElseThrow();
        assertNotNull(sampleCommune.getParent(), "Commune must have parent province");
        assertEquals("01", sampleCommune.getParent().getCode(), "Parent code must be 01 (Hà Nội)");
        assertEquals("Phường Ba Đình", sampleCommune.getName(), "Sample commune name must match Ba Đình");
        assertTrue(sampleCommune.getAreaType().isCommuneLevel(), "Must be commune level");
    }

    @Test
    @DisplayName("Verify official subdivision distribution matches Decree 388 (709 Wards, 2,599 Communes, 13 Special Zones)")
    void testOfficialSubdivisionDistribution_matchesDecree388() throws Exception {
        migrationRunner.migrateAndImport();

        long wardCount = repository.countByAreaType(AdministrativeAreaType.WARD);
        long communeCount = repository.countByAreaType(AdministrativeAreaType.COMMUNE);
        long specialZoneCount = repository.countByAreaType(AdministrativeAreaType.SPECIAL_ZONE);
        long provinceCount = repository.countByAreaType(AdministrativeAreaType.PROVINCE);
        long centralCityCount = repository.countByAreaType(AdministrativeAreaType.CENTRAL_CITY);

        assertEquals(709, wardCount, "Must have exactly 709 wards (Phường)");
        assertEquals(2599, communeCount, "Must have exactly 2,599 communes (Xã)");
        assertEquals(13, specialZoneCount, "Must have exactly 13 island special zones (Đặc khu)");
        assertEquals(25, provinceCount, "Must have exactly 25 provinces (Tỉnh)");
        assertEquals(9, centralCityCount, "Must have exactly 9 centrally-governed cities (Thành phố trực thuộc TW)");
        assertEquals(3321, wardCount + communeCount + specialZoneCount, "Commune-level total must be 3,321");
        assertEquals(34, provinceCount + centralCityCount, "Province-level total must be 34");
    }

    @Test
    @DisplayName("Critical Mapping Tests: Hanoi, HCMC, and Island Special Zones")
    void testCriticalMappings_HanoiHcmcAndSpecialZones() throws Exception {
        migrationRunner.migrateAndImport();

        // 1. Hanoi critical mappings
        AdministrativeArea baDinh = repository.findByCodeWithParent("00004").orElseThrow();
        assertEquals("Phường Ba Đình", baDinh.getName());
        assertEquals(AdministrativeAreaType.WARD, baDinh.getAreaType());
        assertEquals("01", baDinh.getParent().getCode());

        AdministrativeArea ngocHa = repository.findByCodeWithParent("00008").orElseThrow();
        assertEquals("Phường Ngọc Hà", ngocHa.getName());
        assertEquals(AdministrativeAreaType.WARD, ngocHa.getAreaType());
        assertEquals("01", ngocHa.getParent().getCode());

        // 2. HCMC critical mappings
        AdministrativeArea saiGon = repository.findByCodeWithParent("26740").orElseThrow();
        assertEquals("Phường Sài Gòn", saiGon.getName());
        assertEquals(AdministrativeAreaType.WARD, saiGon.getAreaType());
        assertEquals("79", saiGon.getParent().getCode());

        AdministrativeArea benThanh = repository.findByCodeWithParent("26743").orElseThrow();
        assertEquals("Phường Bến Thành", benThanh.getName());
        assertEquals(AdministrativeAreaType.WARD, benThanh.getAreaType());
        assertEquals("79", benThanh.getParent().getCode());

        AdministrativeArea tanDinh = repository.findByCodeWithParent("26737").orElseThrow();
        assertEquals("Phường Tân Định", tanDinh.getName());
        assertEquals(AdministrativeAreaType.WARD, tanDinh.getAreaType());
        assertEquals("79", tanDinh.getParent().getCode());

        AdministrativeArea cauOngLanh = repository.findByCodeWithParent("26758").orElseThrow();
        assertEquals("Phường Cầu Ông Lãnh", cauOngLanh.getName());
        assertEquals(AdministrativeAreaType.WARD, cauOngLanh.getAreaType());
        assertEquals("79", cauOngLanh.getParent().getCode());

        // 3. Special Zones and parent provinces under Resolution 202/2025/QH15
        // Phú Quý -> Lâm Đồng (68)
        AdministrativeArea phuQuy = repository.findByCodeWithParent("23272").orElseThrow();
        assertEquals("Đặc khu Phú Quý", phuQuy.getName());
        assertEquals(AdministrativeAreaType.SPECIAL_ZONE, phuQuy.getAreaType());
        assertEquals("68", phuQuy.getParent().getCode(), "Phú Quý must belong to Lâm Đồng (68)");
        assertEquals("Tỉnh Lâm Đồng", phuQuy.getParent().getName());

        // Côn Đảo -> TP. Hồ Chí Minh (79)
        AdministrativeArea conDao = repository.findByCodeWithParent("26732").orElseThrow();
        assertEquals("Đặc khu Côn Đảo", conDao.getName());
        assertEquals(AdministrativeAreaType.SPECIAL_ZONE, conDao.getAreaType());
        assertEquals("79", conDao.getParent().getCode(), "Côn Đảo must belong to TP. Hồ Chí Minh (79)");

        // Phú Quốc, Thổ Châu, Kiên Hải -> An Giang (91)
        AdministrativeArea phuQuoc = repository.findByCodeWithParent("31078").orElseThrow();
        assertEquals("Đặc khu Phú Quốc", phuQuoc.getName());
        assertEquals(AdministrativeAreaType.SPECIAL_ZONE, phuQuoc.getAreaType());
        assertEquals("91", phuQuoc.getParent().getCode(), "Phú Quốc must belong to An Giang (91)");

        AdministrativeArea thoChau = repository.findByCodeWithParent("31105").orElseThrow();
        assertEquals("Đặc khu Thổ Châu", thoChau.getName());
        assertEquals(AdministrativeAreaType.SPECIAL_ZONE, thoChau.getAreaType());
        assertEquals("91", thoChau.getParent().getCode(), "Thổ Châu must belong to An Giang (91)");

        AdministrativeArea kienHai = repository.findByCodeWithParent("31108").orElseThrow();
        assertEquals("Đặc khu Kiên Hải", kienHai.getName());
        assertEquals(AdministrativeAreaType.SPECIAL_ZONE, kienHai.getAreaType());
        assertEquals("91", kienHai.getParent().getCode(), "Kiên Hải must belong to An Giang (91)");

        // Remaining Special Zones
        Map<String, String> expectedSpecialZones = Map.of(
                "06994", "22", // Vân Đồn -> Quảng Ninh
                "07192", "22", // Cô Tô -> Quảng Ninh
                "11914", "31", // Cát Hải -> Hải Phòng
                "11948", "31", // Bạch Long Vĩ -> Hải Phòng
                "19742", "44", // Cồn Cỏ -> Quảng Trị
                "20333", "48", // Hoàng Sa -> Đà Nẵng
                "21548", "51", // Lý Sơn -> Quảng Ngãi
                "22736", "56"  // Trường Sa -> Khánh Hoà
        );
        for (Map.Entry<String, String> entry : expectedSpecialZones.entrySet()) {
            AdministrativeArea zone = repository.findByCodeWithParent(entry.getKey()).orElseThrow();
            assertEquals(AdministrativeAreaType.SPECIAL_ZONE, zone.getAreaType());
            assertEquals(entry.getValue(), zone.getParent().getCode(),
                    "Special zone " + zone.getName() + " must have parent " + entry.getValue());
        }

        // 4. Check 34 provinces names consistency (Tỉnh vs Thành phố trực thuộc Trung ương)
        AdministrativeArea quangNinh = repository.findByCode("22").orElseThrow();
        assertEquals("Thành phố Quảng Ninh", quangNinh.getName());
        assertEquals(AdministrativeAreaType.CENTRAL_CITY, quangNinh.getAreaType());

        AdministrativeArea bacNinh = repository.findByCode("24").orElseThrow();
        assertEquals("Thành phố Bắc Ninh", bacNinh.getName());
        assertEquals(AdministrativeAreaType.CENTRAL_CITY, bacNinh.getAreaType());

        AdministrativeArea dongNai = repository.findByCode("75").orElseThrow();
        assertEquals("Thành phố Đồng Nai", dongNai.getName());
        assertEquals(AdministrativeAreaType.CENTRAL_CITY, dongNai.getAreaType());
    }

    @Test
    @DisplayName("Verify system detects direct DB tampering of a unit name without metadata change")
    void testDetectsDatabaseCorruption_WhenNameDirectlyModifiedInDbWithoutMetadataChange() throws Exception {
        migrationRunner.migrateAndImport();

        try (Connection conn = jdbcTemplate.getDataSource().getConnection()) {
            // Confirm catalog is initially up-to-date
            assertTrue(migrationRunner.isCatalogUpToDate(conn, 34, 3321), "Catalog should initially be up-to-date");

            // Tamper directly with a name in MySQL without modifying metadata table
            jdbcTemplate.update("UPDATE administrative_areas SET name = 'Phường Ba Đình Bị Sửa' WHERE code = '00004'");

            // isCatalogUpToDate MUST detect the checksum discrepancy
            boolean upToDateAfterTamper = migrationRunner.isCatalogUpToDate(conn, 34, 3321);
            assertFalse(upToDateAfterTamper, "Validator must detect direct DB name tampering even when count & metadata match");
        }

        // Re-running migration repairs the tampered record
        migrationRunner.migrateAndImport();

        try (Connection conn = jdbcTemplate.getDataSource().getConnection()) {
            AdministrativeArea restored = repository.findByCode("00004").orElseThrow();
            assertEquals("Phường Ba Đình", restored.getName(), "Runner reconciliation must restore official name");
            assertTrue(migrationRunner.isCatalogUpToDate(conn, 34, 3321), "Catalog must be up-to-date after repair");
        }
    }

    @Test
    @DisplayName("Verify system detects direct DB tampering of a parent_id without metadata change")
    void testDetectsDatabaseCorruption_WhenParentDirectlyModifiedInDbWithoutMetadataChange() throws Exception {
        migrationRunner.migrateAndImport();

        try (Connection conn = jdbcTemplate.getDataSource().getConnection()) {
            assertTrue(migrationRunner.isCatalogUpToDate(conn, 34, 3321));

            // Tamper parent_id of Phú Quý (point to TP.HCM area_id instead of Lâm Đồng)
            Long hcmAreaId = repository.findByCode("79").orElseThrow().getAreaId();
            jdbcTemplate.update("UPDATE administrative_areas SET parent_id = ? WHERE code = '23272'", hcmAreaId);

            // Validator must catch parent discrepancy
            boolean upToDate = migrationRunner.isCatalogUpToDate(conn, 34, 3321);
            assertFalse(upToDate, "Validator must detect parent mismatch");
        }

        // Repair via runner
        migrationRunner.migrateAndImport();
        AdministrativeArea restored = repository.findByCodeWithParent("23272").orElseThrow();
        assertEquals("68", restored.getParent().getCode(), "Parent must be restored to Lâm Đồng (68)");
    }

    @Test
    @DisplayName("Verify computeDatasetSha256 produces deterministic 64-char hex digest")
    void testComputeDatasetSha256_isDeterministic() throws Exception {
        String hash1 = migrationRunner.computeDatasetSha256();
        String hash2 = migrationRunner.computeDatasetSha256();

        assertNotNull(hash1);
        assertEquals(64, hash1.length(), "SHA-256 hex string must be 64 characters");
        assertEquals(hash1, hash2, "Repeated hash calculation must be deterministic");
    }

    @Test
    @DisplayName("Verify isCatalogUpToDate returns false when SHA-256 fingerprint does not match")
    void testBypassCondition_requiresMatchingSha256Fingerprint() throws Exception {
        migrationRunner.migrateAndImport();

        try (Connection conn = jdbcTemplate.getDataSource().getConnection()) {
            // Tamper metadata hash
            jdbcTemplate.update("UPDATE administrative_catalog_metadata SET meta_value = 'TAMPERED_HASH' WHERE meta_key = 'DATASET_SHA256'");

            boolean upToDate = migrationRunner.isCatalogUpToDate(conn, 34, 3321);
            assertFalse(upToDate, "Runner must NOT bypass when dataset fingerprint does not match");

            // Restore correct hash via re-import
            migrationRunner.migrateAndImport();
            assertTrue(migrationRunner.isCatalogUpToDate(conn, 34, 3321), "Runner must bypass when fingerprint matches");
        }
    }

    @Test
    @DisplayName("Verify validation rejects province with parentCode")
    void testValidateSourceData_RejectsProvinceWithParent() {
        ProvinceSourceDto p1 = new ProvinceSourceDto();
        p1.code = "01";
        p1.name = "Hà Nội";
        p1.areaType = "CENTRAL_CITY";
        p1.parentCode = "99"; // PROVINCE CANNOT HAVE PARENT

        CommuneSourceDto c1 = new CommuneSourceDto();
        c1.code = "00004";
        c1.name = "Phường Ba Đình";
        c1.areaType = "WARD";
        c1.parentCode = "01";

        IllegalStateException thrown = assertThrows(IllegalStateException.class, () -> {
            migrationRunner.validateSourceData(List.of(p1), List.of(c1));
        });
        assertTrue(thrown.getMessage().contains("Province 01 cannot have parentCode"));
    }

    @Test
    @DisplayName("Verify validation rejects commune without parentCode")
    void testValidateSourceData_RejectsCommuneWithoutParent() {
        ProvinceSourceDto p1 = new ProvinceSourceDto();
        p1.code = "01";
        p1.name = "Hà Nội";
        p1.areaType = "CENTRAL_CITY";

        CommuneSourceDto c1 = new CommuneSourceDto();
        c1.code = "00004";
        c1.name = "Phường Ba Đình";
        c1.areaType = "WARD";
        c1.parentCode = null; // COMMUNE MUST HAVE PARENT

        IllegalStateException thrown = assertThrows(IllegalStateException.class, () -> {
            migrationRunner.validateSourceData(List.of(p1), List.of(c1));
        });
        assertTrue(thrown.getMessage().contains("is orphan (missing parentCode)"));
    }

    @Test
    @DisplayName("Verify repeated import executions are completely idempotent")
    void testMigrationRunner_IsIdempotentOnRepeatedExecutions() throws Exception {
        // 1. Initial import
        migrationRunner.migrateAndImport();
        long initialTotal = repository.count();
        Long hcmAreaId = repository.findByCode("79").orElseThrow().getAreaId();

        // 2. Re-run migration simulating multiple server restarts
        assertDoesNotThrow(() -> migrationRunner.migrateAndImport(),
                "Re-running migration must not throw exceptions");

        // 3. Verify counts and internal IDs remain exactly preserved
        long postTotal = repository.count();
        assertEquals(initialTotal, postTotal, "Total record count must not change on re-import");

        Long postHcmAreaId = repository.findByCode("79").orElseThrow().getAreaId();
        assertEquals(hcmAreaId, postHcmAreaId, "Internal area_id must remain stable on re-import");
    }

    @Test
    @DisplayName("Verify validation rejects duplicate province codes")
    void testValidateSourceData_RejectsDuplicateProvinceCode() {
        ProvinceSourceDto p1 = new ProvinceSourceDto();
        p1.code = "01";
        p1.name = "Hà Nội";
        p1.areaType = "CENTRAL_CITY";

        ProvinceSourceDto p2 = new ProvinceSourceDto();
        p2.code = "01"; // DUPLICATE CODE
        p2.name = "Hà Nội 2";
        p2.areaType = "CENTRAL_CITY";

        CommuneSourceDto c1 = new CommuneSourceDto();
        c1.code = "00004";
        c1.name = "Ba Đình";
        c1.areaType = "WARD";
        c1.parentCode = "01";

        IllegalStateException thrown = assertThrows(IllegalStateException.class, () -> {
            migrationRunner.validateSourceData(List.of(p1, p2), List.of(c1));
        });
        assertTrue(thrown.getMessage().contains("Duplicate province code"),
                "Exception message must specify duplicate province code");
    }

    @Test
    @DisplayName("Verify validation rejects commune referencing non-existent parent province")
    void testValidateSourceData_RejectsMissingParent() {
        ProvinceSourceDto p1 = new ProvinceSourceDto();
        p1.code = "01";
        p1.name = "Hà Nội";
        p1.areaType = "CENTRAL_CITY";

        CommuneSourceDto c1 = new CommuneSourceDto();
        c1.code = "00004";
        c1.name = "Ba Đình";
        c1.areaType = "WARD";
        c1.parentCode = "99"; // NON-EXISTENT PARENT

        IllegalStateException thrown = assertThrows(IllegalStateException.class, () -> {
            migrationRunner.validateSourceData(List.of(p1), List.of(c1));
        });
        assertTrue(thrown.getMessage().contains("references non-existent parent province"),
                "Exception message must report missing parent");
    }

    @Test
    @DisplayName("Verify validation rejects invalid administrative area type")
    void testValidateSourceData_RejectsInvalidAreaType() {
        ProvinceSourceDto p1 = new ProvinceSourceDto();
        p1.code = "01";
        p1.name = "Hà Nội";
        p1.areaType = "INVALID_TYPE";

        CommuneSourceDto c1 = new CommuneSourceDto();
        c1.code = "00004";
        c1.name = "Ba Đình";
        c1.areaType = "WARD";
        c1.parentCode = "01";

        IllegalStateException thrown = assertThrows(IllegalStateException.class, () -> {
            migrationRunner.validateSourceData(List.of(p1), List.of(c1));
        });
        assertTrue(thrown.getMessage().contains("Invalid province areaType"),
                "Exception message must report invalid areaType");
    }

    @Test
    @DisplayName("Verify MySQL advisory lock acquisition and release behavior")
    void testAdvisoryLockAcquisitionAndRelease() throws Exception {
        try (Connection conn = jdbcTemplate.getDataSource().getConnection()) {
            boolean acquired = migrationRunner.acquireAdvisoryLock(conn);
            assertTrue(acquired, "Must successfully acquire advisory lock");

            // Release lock
            assertDoesNotThrow(() -> migrationRunner.releaseAdvisoryLock(conn));
        }
    }

    @Test
    @DisplayName("Verify concurrency: two connections competing for advisory lock timeout and succeed sequentially")
    void testAdvisoryLock_TwoConnections_SecondConnectionBlocksOrTimesOut() throws Exception {
        try (Connection conn1 = jdbcTemplate.getDataSource().getConnection();
             Connection conn2 = jdbcTemplate.getDataSource().getConnection()) {

            try {
                // Conn1 acquires lock
                boolean acquired1 = migrationRunner.acquireAdvisoryLock(conn1);
                assertTrue(acquired1, "Connection 1 must acquire advisory lock");

                // Conn2 attempts to acquire same lock with short timeout (1s) -> should fail (return 0)
                try (java.sql.PreparedStatement ps = conn2.prepareStatement("SELECT GET_LOCK('" + AdministrativeAreaMigrationRunner.MIGRATION_LOCK + "', 1)")) {
                    try (java.sql.ResultSet rs = ps.executeQuery()) {
                        assertTrue(rs.next());
                        int lockResult = rs.getInt(1);
                        assertEquals(0, lockResult, "Connection 2 must time out while Connection 1 holds lock");
                    }
                }

                // Conn1 releases lock
                migrationRunner.releaseAdvisoryLock(conn1);

                // Conn2 attempts again -> should succeed
                boolean acquired2 = migrationRunner.acquireAdvisoryLock(conn2);
                assertTrue(acquired2, "Connection 2 must acquire lock after Connection 1 releases it");
                migrationRunner.releaseAdvisoryLock(conn2);
            } finally {
                migrationRunner.releaseAdvisoryLock(conn1);
                migrationRunner.releaseAdvisoryLock(conn2);
            }
        }
    }

    @Test
    @DisplayName("Simulate Section 7.1 DB corruption: UPDATE province 24 name to 'Thành phố Bắc Ninh Sửa' and verify detection & restoration")
    void testDatabaseCorruption_TamperProvinceNameAndVerifyRejectionAndRestoration() throws Exception {
        migrationRunner.migrateAndImport();

        try (Connection conn = jdbcTemplate.getDataSource().getConnection()) {
            assertTrue(migrationRunner.isCatalogUpToDate(conn, 34, 3321));

            // Section 7.1 simulation: Directly tamper province 24 in database
            jdbcTemplate.update("UPDATE administrative_areas SET name = 'Thành phố Bắc Ninh Sửa' WHERE code = '24'");

            // Catalog check must immediately detect the discrepancy
            boolean upToDate = migrationRunner.isCatalogUpToDate(conn, 34, 3321);
            assertFalse(upToDate, "Runner must detect discrepancy on tampered province name");
        }

        // Re-run migrationRunner.migrateAndImport() to restore official data
        migrationRunner.migrateAndImport();

        try (Connection conn = jdbcTemplate.getDataSource().getConnection()) {
            AdministrativeArea restored = repository.findByCode("24").orElseThrow();
            assertEquals("Thành phố Bắc Ninh", restored.getName(), "Name must be restored to official 'Thành phố Bắc Ninh'");
            assertTrue(migrationRunner.isCatalogUpToDate(conn, 34, 3321), "Catalog must be up to date after restoration");
        }
    }

    @Test
    @DisplayName("Verify concurrency: two independent runner instances executing concurrently across threads")
    void testTwoIndependentRunners_ConcurrentExecution_OneAcquiresAndOtherWaitsOrBypasses() throws Exception {
        AdministrativeAreaMigrationRunner runner1 = new AdministrativeAreaMigrationRunner(
                jdbcTemplate.getDataSource(), objectMapper, migrationRunner.getValidator());
        AdministrativeAreaMigrationRunner runner2 = new AdministrativeAreaMigrationRunner(
                jdbcTemplate.getDataSource(), objectMapper, migrationRunner.getValidator());

        java.util.concurrent.ExecutorService executor = java.util.concurrent.Executors.newFixedThreadPool(2);
        java.util.concurrent.CountDownLatch readyLatch = new java.util.concurrent.CountDownLatch(2);
        java.util.concurrent.CountDownLatch startLatch = new java.util.concurrent.CountDownLatch(1);

        java.util.concurrent.Future<?> f1 = executor.submit(() -> {
            readyLatch.countDown();
            try {
                startLatch.await();
                runner1.migrateAndImport();
            } catch (Exception e) {
                throw new RuntimeException("Runner 1 failed", e);
            }
        });

        java.util.concurrent.Future<?> f2 = executor.submit(() -> {
            readyLatch.countDown();
            try {
                startLatch.await();
                runner2.migrateAndImport();
            } catch (Exception e) {
                throw new RuntimeException("Runner 2 failed", e);
            }
        });

        readyLatch.await(5, java.util.concurrent.TimeUnit.SECONDS);
        startLatch.countDown(); // fire simultaneously

        assertDoesNotThrow(() -> {
            f1.get(60, java.util.concurrent.TimeUnit.SECONDS);
            f2.get(60, java.util.concurrent.TimeUnit.SECONDS);
        }, "Both concurrent runners must complete cleanly without throwing exceptions");

        executor.shutdown();

        // Verify database is completely intact after concurrent runs
        try (Connection conn = jdbcTemplate.getDataSource().getConnection()) {
            assertTrue(migrationRunner.isCatalogUpToDate(conn, 34, 3321),
                    "Catalog must be fully up-to-date after concurrent runners finish");
        }
    }
}
