package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.PostReport;
import Travel_Planner.Travel_Planner.model.enums.ReportStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PostReportRepository extends JpaRepository<PostReport, Long> {

    boolean existsByPost_PostIdAndReporter_UserId(Long postId, Integer reporterId);

    Page<PostReport> findByStatus(ReportStatus status, Pageable pageable);
}

