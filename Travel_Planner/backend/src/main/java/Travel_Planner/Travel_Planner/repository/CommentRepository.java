package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Comment;
import Travel_Planner.Travel_Planner.model.enums.CommentStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;

@Repository
public interface CommentRepository extends JpaRepository<Comment, Integer> {

    List<Comment> findByItinerary_ItineraryIdOrderByCreatedAtDesc(Integer itineraryId);

    List<Comment> findByItinerary_ItineraryIdAndStatusOrderByCreatedAtDesc(Integer itineraryId, CommentStatus status);

    @EntityGraph(attributePaths = {"user"})
    Page<Comment> findByItinerary_ItineraryIdAndStatusOrderByCreatedAtDesc(
            Integer itineraryId, CommentStatus status, Pageable pageable);

    long countByItinerary_ItineraryId(Integer itineraryId);

    long countByItinerary_ItineraryIdAndStatus(Integer itineraryId, CommentStatus status);
}
