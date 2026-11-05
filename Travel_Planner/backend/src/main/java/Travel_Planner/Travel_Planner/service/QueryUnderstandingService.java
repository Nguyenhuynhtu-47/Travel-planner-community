package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.location.ParsedLocationQuery;

/**
 * Service responsible for semantic query understanding in location search.
 * Deconstructs raw user input into keyword, category, target locality, and search intent.
 */
public interface QueryUnderstandingService {

    /**
     * Parses and classifies a search query.
     *
     * @param rawQuery user input string
     * @return structured parsed query with intent, category, and target location
     */
    ParsedLocationQuery parseQuery(String rawQuery);
}

