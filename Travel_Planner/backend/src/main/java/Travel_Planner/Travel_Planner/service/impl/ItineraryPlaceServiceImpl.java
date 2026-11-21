package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.SavePlaceToItineraryRequest;
import Travel_Planner.Travel_Planner.dto.response.AdministrativeAreaSummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.ItineraryPlaceResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ConflictException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.Activity;
import Travel_Planner.Travel_Planner.model.AdministrativeArea;
import Travel_Planner.Travel_Planner.model.Itinerary;
import Travel_Planner.Travel_Planner.model.ItineraryPlace;
import Travel_Planner.Travel_Planner.model.Place;
import Travel_Planner.Travel_Planner.model.enums.PlaceStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;
import Travel_Planner.Travel_Planner.repository.ActivityRepository;
import Travel_Planner.Travel_Planner.repository.ItineraryPlaceRepository;
import Travel_Planner.Travel_Planner.repository.ItineraryRepository;
import Travel_Planner.Travel_Planner.repository.PlaceRepository;
import Travel_Planner.Travel_Planner.service.ItineraryPlaceService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@Transactional
public class ItineraryPlaceServiceImpl implements ItineraryPlaceService {

    private final ItineraryRepository itineraryRepository;
    private final PlaceRepository placeRepository;
    private final ItineraryPlaceRepository itineraryPlaceRepository;
    private final ActivityRepository activityRepository;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private Travel_Planner.Travel_Planner.repository.UserRepository userRepository;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private Travel_Planner.Travel_Planner.service.ItineraryAccessGrantService accessGrantService;

    public ItineraryPlaceServiceImpl(
            ItineraryRepository itineraryRepository,
            PlaceRepository placeRepository,
            ItineraryPlaceRepository itineraryPlaceRepository,
            ActivityRepository activityRepository
    ) {
        this.itineraryRepository = itineraryRepository;
        this.placeRepository = placeRepository;
        this.itineraryPlaceRepository = itineraryPlaceRepository;
        this.activityRepository = activityRepository;
    }

    @Override
    public ItineraryPlaceResponse savePlaceToItinerary(
            Integer itineraryId,
            SavePlaceToItineraryRequest request,
            String currentUsernameOrEmail
    ) {
        if (request == null || request.getPlaceId() == null) {
            throw new BadRequestException("ID địa điểm (placeId) không được để trống");
        }

        Itinerary itinerary = itineraryRepository.findById(itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lịch trình với ID: " + itineraryId));

        validateItineraryOwnership(itinerary, currentUsernameOrEmail);

        Place place = placeRepository.findById(request.getPlaceId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy địa điểm với ID: " + request.getPlaceId()));

        if (place.getStatus() != PlaceStatus.ACTIVE) {
            throw new BadRequestException("Địa điểm không hợp lệ hoặc đã bị ẩn");
        }

        if (itineraryPlaceRepository.existsByItinerary_ItineraryIdAndPlace_PlaceId(itineraryId, place.getPlaceId())) {
            throw new ConflictException("Địa điểm này đã được lưu trong lịch trình");
        }

        ItineraryPlace itineraryPlace = ItineraryPlace.builder()
                .itinerary(itinerary)
                .place(place)
                .savedAt(LocalDateTime.now())
                .build();

        ItineraryPlace saved = itineraryPlaceRepository.save(itineraryPlace);
        return toResponse(saved);
    }

    @Override
    @Transactional
    public Page<ItineraryPlaceResponse> getSavedPlaces(
            Integer itineraryId,
            Pageable pageable,
            String currentUsernameOrEmail
    ) {
        Itinerary itinerary = itineraryRepository.findById(itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lịch trình với ID: " + itineraryId));

        validateItineraryViewAccess(itinerary, currentUsernameOrEmail);

        Page<ItineraryPlace> page = itineraryPlaceRepository.findByItineraryIdWithPlace(itineraryId, pageable);
        if (page.isEmpty() && (pageable == null || pageable.getPageNumber() == 0)) {
            List<ItineraryPlace> backfilled = backfillPlacesFromActivities(itinerary);
            if (!backfilled.isEmpty()) {
                page = itineraryPlaceRepository.findByItineraryIdWithPlace(itineraryId, pageable);
            }
        }
        return page.map(this::toResponse);
    }

    @Override
    @Transactional
    public List<ItineraryPlaceResponse> getAllSavedPlaces(
            Integer itineraryId,
            String currentUsernameOrEmail
    ) {
        Itinerary itinerary = itineraryRepository.findById(itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lịch trình với ID: " + itineraryId));

        validateItineraryViewAccess(itinerary, currentUsernameOrEmail);

        List<ItineraryPlace> list = itineraryPlaceRepository.findAllByItineraryIdWithPlace(itineraryId);
        if (list.isEmpty()) {
            list = backfillPlacesFromActivities(itinerary);
        }
        return list.stream().map(this::toResponse).collect(Collectors.toList());
    }

    private List<ItineraryPlace> backfillPlacesFromActivities(Itinerary itinerary) {
        if (activityRepository == null || itinerary == null) {
            return Collections.emptyList();
        }
        List<Activity> activities = activityRepository.findByItineraryDay_Itinerary_ItineraryIdOrderByDisplayOrderAsc(itinerary.getItineraryId());
        Set<Long> seenPlaceIds = new HashSet<>();
        List<ItineraryPlace> createdList = new ArrayList<>();
        for (Activity act : activities) {
            Place p = act.getPlace();
            if (p != null && seenPlaceIds.add(p.getPlaceId())) {
                if (!itineraryPlaceRepository.existsByItinerary_ItineraryIdAndPlace_PlaceId(itinerary.getItineraryId(), p.getPlaceId())) {
                    ItineraryPlace ip = ItineraryPlace.builder()
                            .itinerary(itinerary)
                            .place(p)
                            .savedAt(LocalDateTime.now())
                            .build();
                    createdList.add(itineraryPlaceRepository.save(ip));
                }
            }
        }
        return createdList;
    }

    @Override
    public void removePlaceFromItinerary(
            Integer itineraryId,
            Long placeId,
            String currentUsernameOrEmail
    ) {
        Itinerary itinerary = itineraryRepository.findById(itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lịch trình với ID: " + itineraryId));

        validateItineraryOwnership(itinerary, currentUsernameOrEmail);

        ItineraryPlace itineraryPlace = itineraryPlaceRepository
                .findByItinerary_ItineraryIdAndPlace_PlaceId(itineraryId, placeId)
                .orElseThrow(() -> new ResourceNotFoundException("Địa điểm chưa được lưu trong lịch trình này"));

        // Only delete the ItineraryPlace association row!
        // Does NOT delete Place entity; does NOT alter any Activity or its canonical_place_id!
        itineraryPlaceRepository.delete(itineraryPlace);
    }

    @Override
    @Transactional(readOnly = true)
    public boolean isPlaceSavedInItinerary(Integer itineraryId, Long placeId) {
        if (itineraryId == null || placeId == null) {
            return false;
        }
        return itineraryPlaceRepository.existsByItinerary_ItineraryIdAndPlace_PlaceId(itineraryId, placeId);
    }

    private void validateItineraryOwnership(Itinerary itinerary, String currentUsernameOrEmail) {
        if (currentUsernameOrEmail == null || itinerary.getUser() == null) {
            throw new ForbiddenException("Bạn không có quyền chỉnh sửa địa điểm trong lịch trình này");
        }
        boolean isOwner = currentUsernameOrEmail.equalsIgnoreCase(itinerary.getUser().getUsername())
                || currentUsernameOrEmail.equalsIgnoreCase(itinerary.getUser().getEmail());
        if (!isOwner) {
            throw new ForbiddenException("Bạn không có quyền chỉnh sửa địa điểm trong lịch trình này");
        }
    }

    private void validateItineraryViewAccess(Itinerary itinerary, String currentUsernameOrEmail) {
        if (itinerary.getVisibility() == Visibility.PRIVATE) {
            if (currentUsernameOrEmail == null || itinerary.getUser() == null) {
                throw new ForbiddenException("Lịch trình này ở chế độ riêng tư");
            }
            boolean isOwner = currentUsernameOrEmail.equalsIgnoreCase(itinerary.getUser().getUsername())
                    || currentUsernameOrEmail.equalsIgnoreCase(itinerary.getUser().getEmail());
            Integer viewerUserId = (userRepository != null)
                    ? userRepository.findByUsername(currentUsernameOrEmail)
                            .or(() -> userRepository.findByEmail(currentUsernameOrEmail))
                            .map(Travel_Planner.Travel_Planner.model.User::getUserId)
                            .orElse(null)
                    : null;
            boolean hasGrant = viewerUserId != null && accessGrantService != null
                    && accessGrantService.hasActiveGrant(itinerary.getItineraryId(), viewerUserId);
            if (!isOwner && !hasGrant) {
                throw new ForbiddenException("Lịch trình này ở chế độ riêng tư");
            }
        }
    }

    private ItineraryPlaceResponse toResponse(ItineraryPlace ip) {
        return ItineraryPlaceResponse.builder()
                .id(ip.getId())
                .itineraryId(ip.getItinerary().getItineraryId())
                .place(toPlaceResponse(ip.getPlace()))
                .savedAt(ip.getSavedAt())
                .build();
    }

    private PlaceResponse toPlaceResponse(Place place) {
        if (place == null) {
            return null;
        }
        return PlaceResponse.builder()
                .placeId(place.getPlaceId())
                .name(place.getName())
                .address(place.getAddress())
                .description(place.getDescription())
                .imageUrl(place.getImageUrl())
                .latitude(place.getLatitude())
                .longitude(place.getLongitude())
                .category(place.getCategory())
                .status(place.getStatus())
                .administrativeArea(toSummaryResponse(place.getAdministrativeArea()))
                .build();
    }

    private AdministrativeAreaSummaryResponse toSummaryResponse(AdministrativeArea area) {
        if (area == null) {
            return null;
        }
        return AdministrativeAreaSummaryResponse.builder()
                .areaId(area.getAreaId())
                .code(area.getCode())
                .name(area.getName())
                .areaType(area.getAreaType())
                .parentAreaId(area.getParent() != null ? area.getParent().getAreaId() : null)
                .parentCode(area.getParent() != null ? area.getParent().getCode() : null)
                .parentName(area.getParent() != null ? area.getParent().getName() : null)
                .trustClassification(area.getTrustClassification())
                .build();
    }
}
