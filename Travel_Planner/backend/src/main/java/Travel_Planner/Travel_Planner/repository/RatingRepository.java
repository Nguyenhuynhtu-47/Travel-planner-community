package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Rating;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface RatingRepository extends JpaRepository<Rating, Integer> {

    @Query("SELECT r.itinerary.itineraryId, AVG(r.score) FROM Rating r WHERE r.itinerary.itineraryId IN :itineraryIds GROUP BY r.itinerary.itineraryId")
    List<Object[]> findAverageRatingsByItineraryIds(@Param("itineraryIds") List<Integer> itineraryIds);

    boolean existsByUser_UserIdAndItinerary_ItineraryId(Integer userId, Integer itineraryId);

    Optional<Rating> findByUser_UserIdAndItinerary_ItineraryId(Integer userId, Integer itineraryId);

    @Query("SELECT AVG(r.score) FROM Rating r WHERE r.itinerary.itineraryId = :itineraryId")
    Double findAverageRatingByItineraryId(@Param("itineraryId") Integer itineraryId);

    @Query("SELECT r.score, COUNT(r) FROM Rating r WHERE r.itinerary.itineraryId = :itineraryId GROUP BY r.score")
    List<Object[]> countStarDistributionByItineraryId(@Param("itineraryId") Integer itineraryId);

    long countByItinerary_ItineraryId(Integer itineraryId);
}
