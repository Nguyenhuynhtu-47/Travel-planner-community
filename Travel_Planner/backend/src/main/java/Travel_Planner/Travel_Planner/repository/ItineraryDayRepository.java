package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.ItineraryDay;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ItineraryDayRepository extends JpaRepository<ItineraryDay, Integer> {
    List<ItineraryDay> findByItinerary_ItineraryIdOrderByDayNumberAsc(Integer itineraryId);

    java.util.Optional<ItineraryDay> findByItinerary_ItineraryIdAndDayNumber(Integer itineraryId, Integer dayNumber);

    java.util.Optional<ItineraryDay> findByDayIdAndItinerary_ItineraryId(Integer dayId, Integer itineraryId);

    boolean existsByItinerary_ItineraryIdAndDayNumber(Integer itineraryId, Integer dayNumber);

    long countByItinerary_ItineraryId(Integer itineraryId);

    void deleteByItinerary_ItineraryId(Integer itineraryId);
}

