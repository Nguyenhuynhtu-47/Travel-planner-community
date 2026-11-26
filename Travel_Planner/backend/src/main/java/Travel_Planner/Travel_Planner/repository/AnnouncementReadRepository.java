package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.AnnouncementRead;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDateTime;
import java.util.List;

public interface AnnouncementReadRepository extends JpaRepository<AnnouncementRead, AnnouncementRead.Id> {
    @Query("select r from AnnouncementRead r where r.user.userId = :userId and r.announcement.announcementId in :ids")
    List<AnnouncementRead> findForUserAndAnnouncements(@Param("userId") Integer userId, @Param("ids") List<Long> ids);

    @Query("select count(a) from SystemAnnouncement a where a.status = Travel_Planner.Travel_Planner.model.enums.AnnouncementStatus.PUBLISHED and (a.expiresAt is null or a.expiresAt > :now) and not exists (select r from AnnouncementRead r where r.announcement = a and r.user.userId = :userId)")
    long countUnreadActive(@Param("userId") Integer userId, @Param("now") LocalDateTime now);

    @Modifying
    @Query(value = "insert into announcement_reads (announcement_id,user_id,read_at) values (:announcementId,:userId,:readAt) on duplicate key update read_at=read_at", nativeQuery = true)
    int insertIfAbsent(@Param("announcementId") Long announcementId, @Param("userId") Integer userId, @Param("readAt") LocalDateTime readAt);
}
