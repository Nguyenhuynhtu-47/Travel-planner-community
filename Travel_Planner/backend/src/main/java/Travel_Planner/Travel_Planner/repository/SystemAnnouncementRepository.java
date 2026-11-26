package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.SystemAnnouncement;
import Travel_Planner.Travel_Planner.model.enums.AnnouncementStatus;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Page;
import org.springframework.data.jpa.repository.JpaRepository;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDateTime;
import java.util.List;

public interface SystemAnnouncementRepository extends JpaRepository<SystemAnnouncement, Long> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select a from SystemAnnouncement a where a.announcementId = :id")
    java.util.Optional<SystemAnnouncement> findByIdForUpdate(@Param("id") Long id);
    @Query("select a from SystemAnnouncement a where a.status = :status and (:query is null or lower(a.title) like lower(concat('%', :query, '%'))) order by a.createdAt desc, a.announcementId desc")
    Page<SystemAnnouncement> findAdminPage(@Param("status") AnnouncementStatus status, @Param("query") String query, Pageable pageable);

    @Query("select a from SystemAnnouncement a where a.status = Travel_Planner.Travel_Planner.model.enums.AnnouncementStatus.PUBLISHED and (a.expiresAt is null or a.expiresAt > :now) and (a.publishedAt < :at or (a.publishedAt = :at and (a.announcementId < :id or :cursorSource = 'N'))) order by a.publishedAt desc, a.announcementId desc")
    List<SystemAnnouncement> findActiveBefore(@Param("now") LocalDateTime now, @Param("at") LocalDateTime at, @Param("id") Long id, @Param("cursorSource") String cursorSource, Pageable pageable);

    @Query("select a from SystemAnnouncement a where a.status = Travel_Planner.Travel_Planner.model.enums.AnnouncementStatus.PUBLISHED and (a.expiresAt is null or a.expiresAt > :now) and not exists (select r from AnnouncementRead r where r.announcement = a and r.user.userId = :userId) and (a.publishedAt < :at or (a.publishedAt = :at and (a.announcementId < :id or :cursorSource = 'N'))) order by a.publishedAt desc, a.announcementId desc")
    List<SystemAnnouncement> findUnreadActiveBefore(@Param("userId") Integer userId, @Param("now") LocalDateTime now, @Param("at") LocalDateTime at, @Param("id") Long id, @Param("cursorSource") String cursorSource, Pageable pageable);

    @Query("select a from SystemAnnouncement a where a.status = Travel_Planner.Travel_Planner.model.enums.AnnouncementStatus.PUBLISHED and (a.expiresAt is null or a.expiresAt > :now) order by a.publishedAt desc, a.announcementId desc")
    List<SystemAnnouncement> findActive(@Param("now") LocalDateTime now, Pageable pageable);

    @Query("select a from SystemAnnouncement a where a.status = Travel_Planner.Travel_Planner.model.enums.AnnouncementStatus.PUBLISHED and (a.expiresAt is null or a.expiresAt > :now) and not exists (select r from AnnouncementRead r where r.announcement = a and r.user.userId = :userId) order by a.publishedAt desc, a.announcementId desc")
    List<SystemAnnouncement> findUnreadActive(@Param("userId") Integer userId, @Param("now") LocalDateTime now, Pageable pageable);

    @Query("select count(a) from SystemAnnouncement a where a.status = Travel_Planner.Travel_Planner.model.enums.AnnouncementStatus.PUBLISHED and (a.expiresAt is null or a.expiresAt > :now)")
    long countActive(@Param("now") LocalDateTime now);
}
