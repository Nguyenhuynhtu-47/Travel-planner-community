package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.ItineraryAccessGrant;
import Travel_Planner.Travel_Planner.model.enums.GrantStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ItineraryAccessGrantRepository extends JpaRepository<ItineraryAccessGrant, Long> {

    Optional<ItineraryAccessGrant> findByItinerary_ItineraryIdAndGrantee_UserId(Integer itineraryId, Integer granteeUserId);

    boolean existsByItinerary_ItineraryIdAndGrantee_UserIdAndStatus(Integer itineraryId, Integer granteeUserId, GrantStatus status);
}
