package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.ItineraryShare;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ItineraryShareRepository extends JpaRepository<ItineraryShare, Integer> {

    Optional<ItineraryShare> findByShareToken(String shareToken);

    boolean existsByShareToken(String shareToken);

    List<ItineraryShare> findByItinerary_ItineraryId(Integer itineraryId);
}
