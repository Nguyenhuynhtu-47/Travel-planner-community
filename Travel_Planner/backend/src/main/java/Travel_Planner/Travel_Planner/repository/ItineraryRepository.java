package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Itinerary;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Repository;

@Repository
public interface ItineraryRepository extends JpaRepository<Itinerary, Integer>, JpaSpecificationExecutor<Itinerary> {

    @Override
    @NonNull
    @EntityGraph(attributePaths = {"user"})
    Page<Itinerary> findAll(Specification<Itinerary> spec, @NonNull Pageable pageable);

    @EntityGraph(attributePaths = {"user"})
    @Query("select i from Itinerary i where i.itineraryId = :id")
    Optional<Itinerary> findByIdWithUser(@Param("id") Integer id);

    Optional<Itinerary> findByTitleAndUser_UserId(String title, Integer userId);

    boolean existsByTitleAndUser_UserId(String title, Integer userId);

    List<Itinerary> findByUser_UserId(Integer userId);

    @Modifying
    @Query("update Itinerary i set i.commentCount = i.commentCount + 1 where i.itineraryId = :itineraryId")
    int incrementCommentCount(@Param("itineraryId") Integer itineraryId);

    @Modifying
    @Query("update Itinerary i set i.ratingCount = i.ratingCount + 1 where i.itineraryId = :itineraryId")
    int incrementRatingCount(@Param("itineraryId") Integer itineraryId);

    @Modifying
    @Query("update Itinerary i set i.ratingCount = i.ratingCount - 1 where i.itineraryId = :itineraryId and i.ratingCount > 0")
    int decrementRatingCount(@Param("itineraryId") Integer itineraryId);

    @Modifying
    @Query("update Itinerary i set i.favoriteCount = i.favoriteCount + 1 where i.itineraryId = :itineraryId")
    int incrementFavoriteCount(@Param("itineraryId") Integer itineraryId);

    @Modifying
    @Query("update Itinerary i set i.favoriteCount = i.favoriteCount - 1 where i.itineraryId = :itineraryId and i.favoriteCount > 0")
    int decrementFavoriteCount(@Param("itineraryId") Integer itineraryId);
}
