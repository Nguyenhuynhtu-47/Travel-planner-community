package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.model.AdministrativeArea;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaStatus;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaType;
import Travel_Planner.Travel_Planner.repository.AdministrativeAreaRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@Transactional
public class AdministrativeAreaRepositoryTest {

    @Autowired
    private AdministrativeAreaRepository repository;

    @Test
    @DisplayName("Verify official code unique constraint enforces no duplicate codes")
    void testOfficialCodeUniqueness() {
        AdministrativeArea a1 = AdministrativeArea.builder()
                .code("TEST_01")
                .name("Tỉnh Thử Nghiệm 1")
                .areaType(AdministrativeAreaType.PROVINCE)
                .status(AdministrativeAreaStatus.ACTIVE)
                .build();
        repository.saveAndFlush(a1);

        AdministrativeArea a2 = AdministrativeArea.builder()
                .code("TEST_01")
                .name("Tỉnh Thử Nghiệm Trùng Mã")
                .areaType(AdministrativeAreaType.PROVINCE)
                .status(AdministrativeAreaStatus.ACTIVE)
                .build();

        assertThrows(DataIntegrityViolationException.class, () -> {
            repository.saveAndFlush(a2);
        }, "Duplicate official code must violate unique constraint");
    }

    @Test
    @DisplayName("Verify entity mapping and automatic normalized_name generation")
    void testEntityMappingAndLifecycleHooks() {
        AdministrativeArea area = AdministrativeArea.builder()
                .code("TEST_HN")
                .name("Thành phố Hà Nội")
                .areaType(AdministrativeAreaType.CENTRAL_CITY)
                .status(AdministrativeAreaStatus.ACTIVE)
                .build();

        AdministrativeArea saved = repository.saveAndFlush(area);

        assertNotNull(saved.getAreaId(), "Generated area_id must not be null");
        assertEquals("thanh pho ha noi", saved.getNormalizedName(), "Lifecycle hook must normalize name");
        assertNotNull(saved.getCreatedAt(), "createdAt must be set");
        assertNotNull(saved.getUpdatedAt(), "updatedAt must be set");
        assertEquals(AdministrativeAreaType.CENTRAL_CITY, saved.getAreaType());
        assertTrue(saved.getAreaType().isProvinceLevel(), "CENTRAL_CITY must be province level");
        assertFalse(saved.getAreaType().isCommuneLevel(), "CENTRAL_CITY must not be commune level");
    }

    @Test
    @DisplayName("Verify 2-tier parent-child relationship (Province -> Commune)")
    void testParentChildRelationship() {
        // Create Province
        AdministrativeArea province = repository.saveAndFlush(AdministrativeArea.builder()
                .code("TEST_SG")
                .name("Thành phố Hồ Chí Minh")
                .areaType(AdministrativeAreaType.CENTRAL_CITY)
                .status(AdministrativeAreaStatus.ACTIVE)
                .build());

        // Create Commune referencing Province directly
        AdministrativeArea ward = AdministrativeArea.builder()
                .code("TEST_BN")
                .name("Phường Bến Nghé")
                .areaType(AdministrativeAreaType.WARD)
                .parent(province)
                .status(AdministrativeAreaStatus.ACTIVE)
                .build();

        AdministrativeArea savedWard = repository.saveAndFlush(ward);

        assertNotNull(savedWard.getParent(), "Commune must have parent");
        assertEquals("TEST_SG", savedWard.getParent().getCode(), "Parent code must match province");
        assertEquals("Thành phố Hồ Chí Minh", savedWard.getParent().getName());
        assertTrue(savedWard.getAreaType().isCommuneLevel(), "WARD must be commune level");
    }

    @Test
    @DisplayName("Verify queries by code and parent code")
    void testFindByCodeAndParentCode() {
        AdministrativeArea prov = repository.saveAndFlush(AdministrativeArea.builder()
                .code("TEST_DN")
                .name("Thành phố Đà Nẵng")
                .areaType(AdministrativeAreaType.CENTRAL_CITY)
                .status(AdministrativeAreaStatus.ACTIVE)
                .build());

        repository.saveAndFlush(AdministrativeArea.builder()
                .code("TEST_HC1")
                .name("Phường Hải Châu 1")
                .areaType(AdministrativeAreaType.WARD)
                .parent(prov)
                .status(AdministrativeAreaStatus.ACTIVE)
                .build());

        repository.saveAndFlush(AdministrativeArea.builder()
                .code("TEST_HC2")
                .name("Phường Hải Châu 2")
                .areaType(AdministrativeAreaType.WARD)
                .parent(prov)
                .status(AdministrativeAreaStatus.ACTIVE)
                .build());

        Optional<AdministrativeArea> foundProv = repository.findByCode("TEST_DN");
        assertTrue(foundProv.isPresent());
        assertEquals("Thành phố Đà Nẵng", foundProv.get().getName());

        List<AdministrativeArea> children = repository.findByParent_CodeAndStatusOrderByCodeAsc("TEST_DN", AdministrativeAreaStatus.ACTIVE);
        assertEquals(2, children.size(), "Must find exactly 2 children for parent");
        assertEquals("TEST_HC1", children.get(0).getCode());
        assertEquals("TEST_HC2", children.get(1).getCode());
    }

    @Test
    @DisplayName("Verify searchByNormalizedNameWithParent disambiguates duplicate names across provinces")
    void testSearchDisambiguation() {
        AdministrativeArea prov1 = repository.saveAndFlush(AdministrativeArea.builder()
                .code("TEST_P1")
                .name("Tỉnh An Giang")
                .areaType(AdministrativeAreaType.PROVINCE)
                .status(AdministrativeAreaStatus.ACTIVE)
                .build());

        AdministrativeArea prov2 = repository.saveAndFlush(AdministrativeArea.builder()
                .code("TEST_P2")
                .name("Tỉnh Tiền Giang")
                .areaType(AdministrativeAreaType.PROVINCE)
                .status(AdministrativeAreaStatus.ACTIVE)
                .build());

        repository.saveAndFlush(AdministrativeArea.builder()
                .code("TEST_CT1")
                .name("Xã Châu Thành")
                .areaType(AdministrativeAreaType.COMMUNE)
                .parent(prov1)
                .status(AdministrativeAreaStatus.ACTIVE)
                .build());

        repository.saveAndFlush(AdministrativeArea.builder()
                .code("TEST_CT2")
                .name("Xã Châu Thành")
                .areaType(AdministrativeAreaType.COMMUNE)
                .parent(prov2)
                .status(AdministrativeAreaStatus.ACTIVE)
                .build());

        List<AdministrativeArea> results = repository.searchByNormalizedNameWithParent(
                "chau thanh", "xa chau thanh", "xa chau thanh%", AdministrativeAreaStatus.ACTIVE, PageRequest.of(0, 10));

        assertTrue(results.size() >= 2, "Must return both Châu Thành instances");
        assertTrue(results.stream().anyMatch(r -> r.getParent() != null && "Tỉnh An Giang".equals(r.getParent().getName())));
        assertTrue(results.stream().anyMatch(r -> r.getParent() != null && "Tỉnh Tiền Giang".equals(r.getParent().getName())));
    }
}

