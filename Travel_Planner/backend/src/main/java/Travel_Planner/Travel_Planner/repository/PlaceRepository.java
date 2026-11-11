package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Place;
import Travel_Planner.Travel_Planner.model.enums.PlaceCategory;
import Travel_Planner.Travel_Planner.model.enums.PlaceStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

@Repository
public interface PlaceRepository extends JpaRepository<Place, Long> {

    Optional<Place> findByPlaceIdAndStatus(Long placeId, PlaceStatus status);

    Optional<Place> findByName(String name);

    List<Place> findAllByName(String name);

    Optional<Place> findByNameAndAddress(String name, String address);

    boolean existsByName(String name);

    Page<Place> findByStatus(PlaceStatus status, Pageable pageable);

    @Query("SELECT p FROM Place p WHERE (:status IS NULL OR p.status = :status) " +
           "AND (:category IS NULL OR p.category = :category) " +
           "AND (:keyword IS NULL OR :keyword = '' OR " +
           "     LOWER(p.name) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
           "     LOWER(p.normalizedName) LIKE LOWER(CONCAT('%', :normKeyword, '%')) OR " +
           "     LOWER(p.address) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    Page<Place> searchPlaces(@Param("keyword") String keyword,
                             @Param("normKeyword") String normKeyword,
                             @Param("category") PlaceCategory category,
                             @Param("status") PlaceStatus status,
                             Pageable pageable);

    @Query("SELECT p FROM Place p WHERE p.status = 'ACTIVE' " +
           "AND p.latitude BETWEEN :minLat AND :maxLat " +
           "AND p.longitude BETWEEN :minLon AND :maxLon")
    List<Place> findInBoundingBox(@Param("minLat") BigDecimal minLat,
                                 @Param("maxLat") BigDecimal maxLat,
                                 @Param("minLon") BigDecimal minLon,
                                 @Param("maxLon") BigDecimal maxLon);

    boolean existsByNameIgnoreCaseAndAddressIgnoreCase(String name, String address);
}

