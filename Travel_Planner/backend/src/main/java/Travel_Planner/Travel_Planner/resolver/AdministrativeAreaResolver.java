package Travel_Planner.Travel_Planner.resolver;

import Travel_Planner.Travel_Planner.dto.response.PlaceResolutionResultResponse;
import Travel_Planner.Travel_Planner.model.Place;

/**
 * Resolver responsible for resolving the appropriate AdministrativeArea for a Place
 * based on administrative code, structured address matching, spatial coordinates, and trust classification.
 */
public interface AdministrativeAreaResolver {

    /**
     * Resolve administrative area for a persistent or transient Place entity.
     */
    PlaceResolutionResultResponse resolve(Place place);

    /**
     * Resolve administrative area using individual location signals.
     */
    PlaceResolutionResultResponse resolve(Long placeId, String name, String address, Double latitude, Double longitude, String candidateCode);
}

