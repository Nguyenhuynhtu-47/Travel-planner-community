package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.OfflineDownload;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface OfflineDownloadRepository extends JpaRepository<OfflineDownload, Integer> {

    Optional<OfflineDownload> findByUser_UserIdAndItinerary_ItineraryId(Integer userId, Integer itineraryId);

    boolean existsByUser_UserIdAndItinerary_ItineraryId(Integer userId, Integer itineraryId);

    List<OfflineDownload> findByUser_UserIdOrderByDownloadedAtDesc(Integer userId);

    long countByItinerary_ItineraryId(Integer itineraryId);
}
