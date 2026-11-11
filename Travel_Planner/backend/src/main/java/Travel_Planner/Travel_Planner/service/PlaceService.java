package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.CreatePlaceRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdatePlaceRequest;
import Travel_Planner.Travel_Planner.dto.response.PlaceDetailResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceResponse;
import Travel_Planner.Travel_Planner.model.enums.PlaceCategory;
import Travel_Planner.Travel_Planner.model.enums.PlaceStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;

public interface PlaceService {

    Page<PlaceResponse> searchPlaces(String keyword,
                                    PlaceCategory category,
                                    Double lat,
                                    Double lon,
                                    Double radiusKm,
                                    Pageable pageable);

    PlaceDetailResponse getPublicPlaceById(Long id);

    Page<PlaceResponse> getAdminPlaces(String keyword,
                                      PlaceCategory category,
                                      PlaceStatus status,
                                      Pageable pageable);

    PlaceDetailResponse getAdminPlaceById(Long id);

    PlaceDetailResponse createPlace(CreatePlaceRequest request);

    PlaceDetailResponse updatePlace(Long id, UpdatePlaceRequest request);

    void deletePlace(Long id);

    PlaceDetailResponse resolveOrPersistPlace(String provider,
                                             String providerPlaceId,
                                             String name,
                                             String address,
                                             BigDecimal latitude,
                                             BigDecimal longitude,
                                             String rawCategory,
                                             String rawType,
                                             String metadataJson);
}

