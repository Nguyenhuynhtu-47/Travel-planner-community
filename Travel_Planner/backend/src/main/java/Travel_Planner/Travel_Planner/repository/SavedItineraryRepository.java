package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Itinerary;
import Travel_Planner.Travel_Planner.model.SavedItinerary;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SavedItineraryRepository extends JpaRepository<SavedItinerary, Integer> {

    Optional<SavedItinerary> findByUser_UserIdAndItinerary_ItineraryId(Integer userId, Integer itineraryId);

    boolean existsByUser_UserIdAndItinerary_ItineraryId(Integer userId, Integer itineraryId);

    List<SavedItinerary> findByUser_UserIdOrderByCreatedAtDesc(Integer userId);

    long countByItinerary_ItineraryId(Integer itineraryId);

    @Query(value = "SELECT s.itinerary FROM SavedItinerary s " +
            "WHERE s.user.userId = :userId " +
            "AND s.itinerary.status = Travel_Planner.Travel_Planner.model.enums.ItineraryStatus.ACTIVE " +
            "AND s.itinerary.visibility = Travel_Planner.Travel_Planner.model.enums.Visibility.PUBLIC " +
            "AND s.itinerary.user.status = Travel_Planner.Travel_Planner.model.enums.UserStatus.ACTIVE " +
            "ORDER BY s.createdAt DESC",
            countQuery = "SELECT count(s) FROM SavedItinerary s " +
            "WHERE s.user.userId = :userId " +
            "AND s.itinerary.status = Travel_Planner.Travel_Planner.model.enums.ItineraryStatus.ACTIVE " +
            "AND s.itinerary.visibility = Travel_Planner.Travel_Planner.model.enums.Visibility.PUBLIC " +
            "AND s.itinerary.user.status = Travel_Planner.Travel_Planner.model.enums.UserStatus.ACTIVE")
    Page<Itinerary> findActivePublicSavedItineraries(@Param("userId") Integer userId, Pageable pageable);
}
