package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Rating;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface RatingRepository extends JpaRepository<Rating, Integer> {

    @Query("SELECT r.itinerary.itineraryId, AVG(r.score) FROM Rating r WHERE r.itinerary.itineraryId IN :itineraryIds GROUP BY r.itinerary.itineraryId")
    List<Object[]> findAverageRatingsByItineraryIds(@Param("itineraryIds") List<Integer> itineraryIds);

    boolean existsByUser_UserIdAndItinerary_ItineraryId(Integer userId, Integer itineraryId);
}

