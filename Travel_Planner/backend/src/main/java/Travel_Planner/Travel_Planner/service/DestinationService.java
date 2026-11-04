package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.CreateDestinationRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdateDestinationRequest;
import Travel_Planner.Travel_Planner.dto.response.DestinationResponse;
import Travel_Planner.Travel_Planner.model.enums.DestinationStatus;

import java.util.List;

public interface DestinationService {

    List<DestinationResponse> getPublicDestinations(String keyword);

    DestinationResponse getPublicDestinationById(Integer id);

    List<DestinationResponse> getAdminDestinations(String keyword, DestinationStatus status);

    DestinationResponse getAdminDestinationById(Integer id);

    DestinationResponse createDestination(CreateDestinationRequest request);

    DestinationResponse updateDestination(Integer id, UpdateDestinationRequest request);

    void deleteDestination(Integer id);
}

