package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.ItineraryPlace;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ItineraryPlaceRepository extends JpaRepository<ItineraryPlace, Long> {

    Optional<ItineraryPlace> findByItinerary_ItineraryIdAndPlace_PlaceId(Integer itineraryId, Long placeId);

    boolean existsByItinerary_ItineraryIdAndPlace_PlaceId(Integer itineraryId, Long placeId);

    @Query("SELECT ip FROM ItineraryPlace ip " +
           "JOIN FETCH ip.place p " +
           "LEFT JOIN FETCH p.administrativeArea " +
           "WHERE ip.itinerary.itineraryId = :itineraryId")
    Page<ItineraryPlace> findByItineraryIdWithPlace(@Param("itineraryId") Integer itineraryId, Pageable pageable);

    @Query("SELECT ip FROM ItineraryPlace ip " +
           "JOIN FETCH ip.place p " +
           "LEFT JOIN FETCH p.administrativeArea " +
           "WHERE ip.itinerary.itineraryId = :itineraryId " +
           "ORDER BY ip.savedAt DESC")
    List<ItineraryPlace> findAllByItineraryIdWithPlace(@Param("itineraryId") Integer itineraryId);

    long countByItinerary_ItineraryId(Integer itineraryId);

    void deleteByItinerary_ItineraryIdAndPlace_PlaceId(Integer itineraryId, Long placeId);
}

