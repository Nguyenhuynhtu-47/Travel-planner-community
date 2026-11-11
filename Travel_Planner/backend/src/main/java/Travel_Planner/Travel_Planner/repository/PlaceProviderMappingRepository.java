package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.PlaceProviderMapping;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PlaceProviderMappingRepository extends JpaRepository<PlaceProviderMapping, Long> {

    Optional<PlaceProviderMapping> findByProviderAndProviderPlaceId(String provider, String providerPlaceId);

    List<PlaceProviderMapping> findByPlace_PlaceId(Long placeId);

    boolean existsByProviderAndProviderPlaceId(String provider, String providerPlaceId);
}

