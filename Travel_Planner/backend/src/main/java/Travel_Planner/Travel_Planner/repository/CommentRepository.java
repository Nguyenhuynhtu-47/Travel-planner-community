package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Comment;
import Travel_Planner.Travel_Planner.model.enums.CommentStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CommentRepository extends JpaRepository<Comment, Integer> {

    List<Comment> findByItinerary_ItineraryIdOrderByCreatedAtDesc(Integer itineraryId);

    List<Comment> findByItinerary_ItineraryIdAndStatusOrderByCreatedAtDesc(Integer itineraryId, CommentStatus status);

    long countByItinerary_ItineraryId(Integer itineraryId);

    long countByItinerary_ItineraryIdAndStatus(Integer itineraryId, CommentStatus status);
}
