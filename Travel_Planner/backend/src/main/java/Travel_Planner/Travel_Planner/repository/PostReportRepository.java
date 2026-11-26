package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.PostReport;
import Travel_Planner.Travel_Planner.model.enums.ReportStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;
import java.util.Optional;

public interface PostReportRepository extends JpaRepository<PostReport, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from PostReport r join fetch r.reporter join fetch r.post where r.reportId = :reportId")
    Optional<PostReport> findByIdForUpdate(@Param("reportId") Long reportId);

    boolean existsByPost_PostIdAndReporter_UserId(Long postId, Integer reporterId);

    Page<PostReport> findByStatus(ReportStatus status, Pageable pageable);
}

