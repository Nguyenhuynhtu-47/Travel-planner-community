package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.model.Itinerary;
import Travel_Planner.Travel_Planner.model.ItineraryAccessGrant;
import Travel_Planner.Travel_Planner.model.User;

public interface ItineraryAccessGrantService {

    ItineraryAccessGrant grantAccess(Itinerary itinerary, User grantee, User grantedBy);

    void revokeAccess(Integer itineraryId, Integer granteeUserId, String currentUsername);

    boolean hasActiveGrant(Integer itineraryId, Integer granteeUserId);
}
