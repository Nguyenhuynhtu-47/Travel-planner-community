package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.UserIdentity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserIdentityRepository extends JpaRepository<UserIdentity, Integer> {

    Optional<UserIdentity> findByProviderAndProviderSubject(String provider, String providerSubject);

    Optional<UserIdentity> findByUser_UserIdAndProvider(Integer userId, String provider);

    List<UserIdentity> findByUser_UserId(Integer userId);

    boolean existsByProviderAndProviderSubject(String provider, String providerSubject);

    void deleteByUser_UserId(Integer userId);
}
