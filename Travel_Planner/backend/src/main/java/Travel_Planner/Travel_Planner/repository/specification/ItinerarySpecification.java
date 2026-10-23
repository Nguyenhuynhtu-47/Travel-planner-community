package Travel_Planner.Travel_Planner.repository.specification;

import Travel_Planner.Travel_Planner.model.Itinerary;
import Travel_Planner.Travel_Planner.model.Rating;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Root;
import jakarta.persistence.criteria.Subquery;
import org.springframework.data.jpa.domain.Specification;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

public class ItinerarySpecification {

    public static Specification<Itinerary> filter(
            String keyword,
            String location,
            String theme,
            BigDecimal minBudget,
            BigDecimal maxBudget,
            Integer minDays,
            Integer maxDays,
            Double minRating
    ) {
        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();

            // 1. Mandatory eligibility: Visibility must be PUBLIC
            predicates.add(cb.equal(root.get("visibility"), Visibility.PUBLIC));

            // 2. Mandatory eligibility: Status must be ACTIVE (not HIDDEN, not DELETED)
            predicates.add(cb.equal(root.get("status"), ItineraryStatus.ACTIVE));

            // 3. Mandatory eligibility: Owner user must be ACTIVE (not BANNED, not INACTIVE)
            predicates.add(cb.equal(root.get("user").get("status"), UserStatus.ACTIVE));

            // Keyword search over title, location, theme, description
            if (keyword != null && !keyword.trim().isEmpty()) {
                String pattern = "%" + escapeLike(keyword).toLowerCase() + "%";
                Predicate titleMatch = cb.like(cb.lower(root.get("title")), pattern, '\\');
                Predicate locationMatch = cb.like(cb.lower(root.get("location")), pattern, '\\');
                Predicate themeMatch = cb.like(cb.lower(root.get("theme")), pattern, '\\');
                Predicate descMatch = cb.like(cb.lower(root.get("description")), pattern, '\\');
                predicates.add(cb.or(titleMatch, locationMatch, themeMatch, descMatch));
            }

            // Location filter
            if (location != null && !location.trim().isEmpty()) {
                String locPattern = "%" + escapeLike(location).toLowerCase() + "%";
                predicates.add(cb.like(cb.lower(root.get("location")), locPattern, '\\'));
            }

            // Theme filter
            if (theme != null && !theme.trim().isEmpty()) {
                String themePattern = "%" + escapeLike(theme).toLowerCase() + "%";
                predicates.add(cb.like(cb.lower(root.get("theme")), themePattern, '\\'));
            }

            // Budget range
            if (minBudget != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("budget"), minBudget));
            }
            if (maxBudget != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("budget"), maxBudget));
            }

            // Total days range
            if (minDays != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("totalDays"), minDays));
            }
            if (maxDays != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("totalDays"), maxDays));
            }

            // Min average rating filter via subquery
            if (minRating != null) {
                Subquery<Double> subquery = query.subquery(Double.class);
                Root<Rating> ratingRoot = subquery.from(Rating.class);
                subquery.select(cb.avg(ratingRoot.get("score")));
                subquery.where(cb.equal(ratingRoot.get("itinerary"), root));
                predicates.add(cb.greaterThanOrEqualTo(cb.coalesce(subquery, 0.0), minRating));
            }

            return cb.and(predicates.toArray(new Predicate[0]));
        };
    }

    private static String escapeLike(String input) {
        if (input == null) {
            return "";
        }
        return input.trim()
                .replace("\\", "\\\\")
                .replace("%", "\\%")
                .replace("_", "\\_");
    }
}
