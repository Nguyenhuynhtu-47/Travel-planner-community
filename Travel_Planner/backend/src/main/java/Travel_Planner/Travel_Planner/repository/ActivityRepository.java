package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Activity;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ActivityRepository extends JpaRepository<Activity, Integer> {
    @EntityGraph(attributePaths = {"destination"})
    List<Activity> findByItineraryDay_DayIdInOrderByDisplayOrderAsc(List<Integer> dayIds);

    boolean existsByItineraryDay_DayIdAndDisplayOrder(Integer dayId, Integer displayOrder);
}

