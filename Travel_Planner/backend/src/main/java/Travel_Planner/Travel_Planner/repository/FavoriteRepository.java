package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Favorite;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface FavoriteRepository extends JpaRepository<Favorite, Integer> {

    Optional<Favorite> findByUser_UserIdAndItinerary_ItineraryId(Integer userId, Integer itineraryId);

    boolean existsByUser_UserIdAndItinerary_ItineraryId(Integer userId, Integer itineraryId);

    List<Favorite> findByUser_UserIdOrderByCreatedAtDesc(Integer userId);

    long countByItinerary_ItineraryId(Integer itineraryId);
}
