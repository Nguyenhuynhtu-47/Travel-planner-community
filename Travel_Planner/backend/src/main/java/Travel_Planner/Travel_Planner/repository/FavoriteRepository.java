package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Favorite;
import Travel_Planner.Travel_Planner.model.Itinerary;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface FavoriteRepository extends JpaRepository<Favorite, Integer> {

    Optional<Favorite> findByUser_UserIdAndItinerary_ItineraryId(Integer userId, Integer itineraryId);

    boolean existsByUser_UserIdAndItinerary_ItineraryId(Integer userId, Integer itineraryId);

    List<Favorite> findByUser_UserIdOrderByCreatedAtDesc(Integer userId);

    long countByItinerary_ItineraryId(Integer itineraryId);

    @Query(value = "SELECT f.itinerary FROM Favorite f " +
            "WHERE f.user.userId = :userId " +
            "AND f.itinerary.status = Travel_Planner.Travel_Planner.model.enums.ItineraryStatus.ACTIVE " +
            "AND f.itinerary.visibility = Travel_Planner.Travel_Planner.model.enums.Visibility.PUBLIC " +
            "AND f.itinerary.user.status = Travel_Planner.Travel_Planner.model.enums.UserStatus.ACTIVE " +
            "ORDER BY f.createdAt DESC",
            countQuery = "SELECT count(f) FROM Favorite f " +
            "WHERE f.user.userId = :userId " +
            "AND f.itinerary.status = Travel_Planner.Travel_Planner.model.enums.ItineraryStatus.ACTIVE " +
            "AND f.itinerary.visibility = Travel_Planner.Travel_Planner.model.enums.Visibility.PUBLIC " +
            "AND f.itinerary.user.status = Travel_Planner.Travel_Planner.model.enums.UserStatus.ACTIVE")
    Page<Itinerary> findActivePublicFavoritedItineraries(@Param("userId") Integer userId, Pageable pageable);
}
