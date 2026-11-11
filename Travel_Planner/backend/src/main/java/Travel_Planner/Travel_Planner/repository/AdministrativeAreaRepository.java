package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.AdministrativeArea;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaStatus;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaTrustClassification;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaType;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface AdministrativeAreaRepository extends JpaRepository<AdministrativeArea, Long> {

    Optional<AdministrativeArea> findByCode(String code);

    @Query("SELECT a FROM AdministrativeArea a LEFT JOIN FETCH a.parent WHERE a.code = :code")
    Optional<AdministrativeArea> findByCodeWithParent(@Param("code") String code);

    boolean existsByCode(String code);

    /**
     * Retrieve province-level administrative units (PROVINCE, CENTRAL_CITY).
     */
    List<AdministrativeArea> findByAreaTypeInAndStatusOrderByCodeAsc(
            List<AdministrativeAreaType> types,
            AdministrativeAreaStatus status
    );

    /**
     * Retrieve child units (communes/wards/special zones) by parent province code.
     */
    List<AdministrativeArea> findByParent_CodeAndStatusOrderByCodeAsc(
            String parentCode,
            AdministrativeAreaStatus status
    );

    /**
     * Retrieve non-quarantined child units by parent province code.
     * Strictly excludes UNVERIFIED_AND_QUARANTINED units (Resolution 388).
     */
    @Query("SELECT a FROM AdministrativeArea a WHERE a.parent.code = :parentCode " +
           "AND a.status = :status " +
           "AND a.trustClassification <> Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaTrustClassification.UNVERIFIED_AND_QUARANTINED " +
           "ORDER BY a.code ASC")
    List<AdministrativeArea> findNonQuarantinedChildrenByParentCode(
            @Param("parentCode") String parentCode,
            @Param("status") AdministrativeAreaStatus status
    );

    /**
     * Retrieve child units by parent internal area ID.
     */
    List<AdministrativeArea> findByParent_AreaIdAndStatusOrderByCodeAsc(
            Long parentAreaId,
            AdministrativeAreaStatus status
    );

    /**
     * Search administrative areas by normalized name with parent province information fetched.
     */
    @Query("SELECT a FROM AdministrativeArea a LEFT JOIN FETCH a.parent WHERE a.normalizedName LIKE %:keyword% AND a.status = :status ORDER BY CASE WHEN a.normalizedName = :exactNorm THEN 0 WHEN a.normalizedName LIKE :prefixNorm THEN 1 ELSE 2 END, a.code ASC")
    List<AdministrativeArea> searchByNormalizedNameWithParent(
            @Param("keyword") String keyword,
            @Param("exactNorm") String exactNorm,
            @Param("prefixNorm") String prefixNorm,
            @Param("status") AdministrativeAreaStatus status,
            Pageable pageable
    );

    /**
     * Search non-quarantined administrative areas supporting exact code, exact name, or partial match.
     * Strictly excludes UNVERIFIED_AND_QUARANTINED units.
     */
    @Query("SELECT a FROM AdministrativeArea a LEFT JOIN FETCH a.parent " +
           "WHERE (a.normalizedName LIKE %:keyword% OR a.code = :exactCode) " +
           "AND a.status = :status " +
           "AND a.trustClassification <> Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaTrustClassification.UNVERIFIED_AND_QUARANTINED " +
           "ORDER BY CASE " +
           "  WHEN a.code = :exactCode THEN 0 " +
           "  WHEN a.normalizedName = :exactNorm THEN 1 " +
           "  WHEN a.normalizedName LIKE :prefixNorm THEN 2 " +
           "  ELSE 3 END, a.code ASC")
    List<AdministrativeArea> searchNonQuarantined(
            @Param("keyword") String keyword,
            @Param("exactCode") String exactCode,
            @Param("exactNorm") String exactNorm,
            @Param("prefixNorm") String prefixNorm,
            @Param("status") AdministrativeAreaStatus status,
            Pageable pageable
    );

    long countByAreaTypeIn(List<AdministrativeAreaType> types);

    long countByAreaType(AdministrativeAreaType type);

    long countByParentIsNotNull();

    List<AdministrativeArea> findByTrustClassification(AdministrativeAreaTrustClassification trustClassification);

    List<AdministrativeArea> findByNormalizedNameAndStatus(String normalizedName, AdministrativeAreaStatus status);

    List<AdministrativeArea> findByNormalizedNameAndParent_CodeAndStatus(String normalizedName, String parentCode, AdministrativeAreaStatus status);

    Optional<AdministrativeArea> findByNormalizedName(String normalizedName);

    List<AdministrativeArea> findAllByParentIsNull();
}

