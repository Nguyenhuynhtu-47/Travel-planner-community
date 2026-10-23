package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Destination;
import Travel_Planner.Travel_Planner.model.enums.DestinationStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface DestinationRepository extends JpaRepository<Destination, Integer> {

    Optional<Destination> findByName(String name);

    boolean existsByName(String name);

    List<Destination> findByStatus(DestinationStatus status);
}
