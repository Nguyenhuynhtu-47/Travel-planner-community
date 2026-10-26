package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Itinerary;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Repository;

@Repository
public interface ItineraryRepository extends JpaRepository<Itinerary, Integer>, JpaSpecificationExecutor<Itinerary> {

    @Override
    @NonNull
    @EntityGraph(attributePaths = {"user"})
    Page<Itinerary> findAll(Specification<Itinerary> spec, @NonNull Pageable pageable);

    Optional<Itinerary> findByTitleAndUser_UserId(String title, Integer userId);

    boolean existsByTitleAndUser_UserId(String title, Integer userId);
}

