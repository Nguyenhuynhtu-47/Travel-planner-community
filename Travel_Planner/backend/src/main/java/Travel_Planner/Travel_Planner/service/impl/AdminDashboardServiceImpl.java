package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.response.AdminDashboardAnalyticsResponse;
import Travel_Planner.Travel_Planner.dto.response.AdminDashboardSummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.AuditLogResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.AuditLogRepository;
import Travel_Planner.Travel_Planner.service.AdminDashboardService;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.temporal.WeekFields;
import java.util.*;

@Service
@Transactional(readOnly = true)
public class AdminDashboardServiceImpl implements AdminDashboardService {

    public static final int MAX_ANALYTICS_DAYS = 365;

    @PersistenceContext
    private EntityManager entityManager;

    private final AuditLogRepository auditLogRepository;

    public AdminDashboardServiceImpl(AuditLogRepository auditLogRepository) {
        this.auditLogRepository = auditLogRepository;
    }

    @Override
    public AdminDashboardSummaryResponse getSummary() {
        Object[] userCounts = singleRow("""
                SELECT COUNT(u),
                       COALESCE(SUM(CASE WHEN u.status = :active THEN 1L ELSE 0L END), 0L),
                       COALESCE(SUM(CASE WHEN u.status = :banned THEN 1L ELSE 0L END), 0L)
                FROM User u
                """, Map.of("active", UserStatus.ACTIVE, "banned", UserStatus.BANNED));

        Object[] placeCounts = singleRow("""
                SELECT COUNT(p),
                       COALESCE(SUM(CASE WHEN p.status = :active THEN 1L ELSE 0L END), 0L),
                       COALESCE(SUM(CASE WHEN p.administrativeArea IS NOT NULL THEN 1L ELSE 0L END), 0L)
                FROM Place p
                """, Map.of("active", PlaceStatus.ACTIVE));

        Object[] itineraryCounts = singleRow("""
                SELECT COUNT(i),
                       COALESCE(SUM(CASE WHEN i.visibility = :pub THEN 1L ELSE 0L END), 0L),
                       COALESCE(SUM(CASE WHEN i.visibility = :priv THEN 1L ELSE 0L END), 0L),
                       COALESCE(SUM(CASE WHEN i.status = :active THEN 1L ELSE 0L END), 0L),
                       COALESCE(SUM(CASE WHEN i.status = :hidden THEN 1L ELSE 0L END), 0L)
                FROM Itinerary i
                """, Map.of(
                "pub", Visibility.PUBLIC,
                "priv", Visibility.PRIVATE,
                "active", ItineraryStatus.ACTIVE,
                "hidden", ItineraryStatus.HIDDEN));

        Object[] postCounts = singleRow("""
                SELECT COUNT(p),
                       COALESCE(SUM(CASE WHEN p.status = :hidden THEN 1L ELSE 0L END), 0L)
                FROM Post p
                """, Map.of("hidden", PostStatus.HIDDEN));

        long pendingReports = entityManager.createQuery(
                        "SELECT COUNT(r) FROM PostReport r WHERE r.status = :pending", Long.class)
                .setParameter("pending", ReportStatus.PENDING)
                .getSingleResult();

        Object[] mediaCounts = singleRow("""
                SELECT COUNT(m),
                       COALESCE(SUM(CASE WHEN m.deadLetteredAt IS NOT NULL THEN 1L ELSE 0L END), 0L)
                FROM MediaAsset m
                """, Map.of());

        long totalPlaces = toLong(placeCounts[0]);
        long linkedPlaces = toLong(placeCounts[2]);
        double coverage = totalPlaces == 0L
                ? 0.0
                : Math.round((linkedPlaces * 10000.0) / totalPlaces) / 100.0;

        return AdminDashboardSummaryResponse.builder()
                .healthStatus("UP")
                .serverTimestamp(LocalDateTime.now().toString())
                .totalUsers(toLong(userCounts[0]))
                .activeUsers(toLong(userCounts[1]))
                .bannedUsers(toLong(userCounts[2]))
                .totalPlaces(totalPlaces)
                .activePlaces(toLong(placeCounts[1]))
                .linkedPlaces(linkedPlaces)
                .placeAreaCoveragePercentage(coverage)
                .totalItineraries(toLong(itineraryCounts[0]))
                .publicItineraries(toLong(itineraryCounts[1]))
                .privateItineraries(toLong(itineraryCounts[2]))
                .activeItineraries(toLong(itineraryCounts[3]))
                .hiddenItineraries(toLong(itineraryCounts[4]))
                .totalPosts(toLong(postCounts[0]))
                .hiddenPosts(toLong(postCounts[1]))
                .pendingReportsCount(pendingReports)
                .totalMediaAssets(toLong(mediaCounts[0]))
                .deadLetterMediaAssets(toLong(mediaCounts[1]))
                .build();
    }

    @Override
    public AdminDashboardAnalyticsResponse getAnalytics(int days) {
        if (days < 1 || days > MAX_ANALYTICS_DAYS) {
            throw new BadRequestException("Khoảng thời gian thống kê (days) phải từ 1 đến " + MAX_ANALYTICS_DAYS + " ngày.");
        }

        LocalDate today = LocalDate.now();
        LocalDate startDay = today.minusDays(days - 1L);
        LocalDateTime startDateTime = startDay.atStartOfDay();
        LocalDateTime endDateTime = today.atTime(LocalTime.MAX);

        // 1. User registrations daily over [startDay, today]
        List<Object[]> userRows = entityManager.createQuery("""
                        SELECT FUNCTION('DATE', u.createdAt), COUNT(u)
                        FROM User u
                        WHERE u.createdAt >= :start AND u.createdAt <= :end
                        GROUP BY FUNCTION('DATE', u.createdAt)
                        ORDER BY FUNCTION('DATE', u.createdAt) ASC
                        """, Object[].class)
                .setParameter("start", startDateTime)
                .setParameter("end", endDateTime)
                .getResultList();

        Map<String, Long> userDailyMap = new LinkedHashMap<>();
        for (int i = 0; i < days; i++) {
            userDailyMap.put(startDay.plusDays(i).toString(), 0L);
        }
        for (Object[] row : userRows) {
            if (row[0] != null) {
                userDailyMap.put(row[0].toString(), toLong(row[1]));
            }
        }
        List<AdminDashboardAnalyticsResponse.TimeSeriesPoint> userRegistrationsDaily = userDailyMap.entrySet().stream()
                .map(e -> AdminDashboardAnalyticsResponse.TimeSeriesPoint.builder()
                        .label(e.getKey())
                        .count(e.getValue())
                        .build())
                .toList();

        // 2. Community posts weekly over the exact same [startDay, today] window
        List<Object[]> postRows = entityManager.createQuery("""
                        SELECT FUNCTION('DATE', p.createdAt), COUNT(p)
                        FROM Post p
                        WHERE p.createdAt >= :start AND p.createdAt <= :end
                        GROUP BY FUNCTION('DATE', p.createdAt)
                        ORDER BY FUNCTION('DATE', p.createdAt) ASC
                        """, Object[].class)
                .setParameter("start", startDateTime)
                .setParameter("end", endDateTime)
                .getResultList();

        Map<String, Long> weeklyMap = new LinkedHashMap<>();
        WeekFields weekFields = WeekFields.ISO;
        for (int i = 0; i < days; i++) {
            LocalDate d = startDay.plusDays(i);
            String weekKey = formatIsoWeek(d, weekFields);
            weeklyMap.putIfAbsent(weekKey, 0L);
        }
        for (Object[] row : postRows) {
            if (row[0] != null) {
                LocalDate d = LocalDate.parse(row[0].toString());
                String weekKey = formatIsoWeek(d, weekFields);
                weeklyMap.merge(weekKey, toLong(row[1]), Long::sum);
            }
        }
        List<AdminDashboardAnalyticsResponse.TimeSeriesPoint> communityPostsWeekly = weeklyMap.entrySet().stream()
                .map(e -> AdminDashboardAnalyticsResponse.TimeSeriesPoint.builder()
                        .label(e.getKey())
                        .count(e.getValue())
                        .build())
                .toList();

        // 3. Top 5 Places by itinerary usage
        List<Object[]> topPlaceRows = entityManager.createQuery("""
                        SELECT p.placeId, p.name, p.category, a.name, COUNT(ip)
                        FROM ItineraryPlace ip
                        JOIN ip.place p
                        LEFT JOIN p.administrativeArea a
                        GROUP BY p.placeId, p.name, p.category, a.name
                        ORDER BY COUNT(ip) DESC, p.placeId ASC
                        """, Object[].class)
                .setMaxResults(5)
                .getResultList();

        List<AdminDashboardAnalyticsResponse.TopPlaceItem> topPlaces = topPlaceRows.stream()
                .map(row -> AdminDashboardAnalyticsResponse.TopPlaceItem.builder()
                        .placeId(toLong(row[0]))
                        .name(row[1] != null ? row[1].toString() : "")
                        .category(row[2] != null ? row[2].toString() : null)
                        .areaName(row[3] != null ? row[3].toString() : null)
                        .itineraryCount(toLong(row[4]))
                        .build())
                .toList();

        // 4. Recent 8 Audit Trail entries
        List<AuditLogResponse> recentAuditLogs = auditLogRepository
                .findByOrderByCreatedAtDescLogIdDesc(PageRequest.of(0, 8))
                .getContent()
                .stream()
                .map(AuditLogResponse::fromEntity)
                .toList();

        return AdminDashboardAnalyticsResponse.builder()
                .days(days)
                .fromDate(startDay.toString())
                .toDate(today.toString())
                .userRegistrationsDaily(userRegistrationsDaily)
                .communityPostsWeekly(communityPostsWeekly)
                .topPlaces(topPlaces)
                .recentAuditLogs(recentAuditLogs)
                .build();
    }

    private String formatIsoWeek(LocalDate date, WeekFields weekFields) {
        int week = date.get(weekFields.weekOfWeekBasedYear());
        int year = date.get(weekFields.weekBasedYear());
        return String.format("%d-W%02d", year, week);
    }

    private Object[] singleRow(String jpql, Map<String, Object> params) {
        var query = entityManager.createQuery(jpql, Object[].class);
        params.forEach(query::setParameter);
        return query.getSingleResult();
    }

    private long toLong(Object val) {
        if (val == null) return 0L;
        return ((Number) val).longValue();
    }
}
