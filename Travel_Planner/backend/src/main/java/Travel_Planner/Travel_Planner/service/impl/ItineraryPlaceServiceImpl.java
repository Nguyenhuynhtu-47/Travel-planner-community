package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.SavePlaceToItineraryRequest;
import Travel_Planner.Travel_Planner.dto.response.AdministrativeAreaSummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.ItineraryPlaceResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ConflictException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.AdministrativeArea;
import Travel_Planner.Travel_Planner.model.Itinerary;
import Travel_Planner.Travel_Planner.model.ItineraryPlace;
import Travel_Planner.Travel_Planner.model.Place;
import Travel_Planner.Travel_Planner.model.enums.PlaceStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;
import Travel_Planner.Travel_Planner.repository.ItineraryPlaceRepository;
import Travel_Planner.Travel_Planner.repository.ItineraryRepository;
import Travel_Planner.Travel_Planner.repository.PlaceRepository;
import Travel_Planner.Travel_Planner.service.ItineraryPlaceService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
@Transactional
public class ItineraryPlaceServiceImpl implements ItineraryPlaceService {

    private final ItineraryRepository itineraryRepository;
    private final PlaceRepository placeRepository;
    private final ItineraryPlaceRepository itineraryPlaceRepository;

    public ItineraryPlaceServiceImpl(
            ItineraryRepository itineraryRepository,
            PlaceRepository placeRepository,
            ItineraryPlaceRepository itineraryPlaceRepository
    ) {
        this.itineraryRepository = itineraryRepository;
        this.placeRepository = placeRepository;
        this.itineraryPlaceRepository = itineraryPlaceRepository;
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
    @Transactional(readOnly = true)
    public Page<ItineraryPlaceResponse> getSavedPlaces(
            Integer itineraryId,
            Pageable pageable,
            String currentUsernameOrEmail
    ) {
        Itinerary itinerary = itineraryRepository.findById(itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lịch trình với ID: " + itineraryId));

        validateItineraryViewAccess(itinerary, currentUsernameOrEmail);

        Page<ItineraryPlace> page = itineraryPlaceRepository.findByItineraryIdWithPlace(itineraryId, pageable);
        return page.map(this::toResponse);
    }

    @Override
    @Transactional(readOnly = true)
    public List<ItineraryPlaceResponse> getAllSavedPlaces(
            Integer itineraryId,
            String currentUsernameOrEmail
    ) {
        Itinerary itinerary = itineraryRepository.findById(itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lịch trình với ID: " + itineraryId));

        validateItineraryViewAccess(itinerary, currentUsernameOrEmail);

        List<ItineraryPlace> list = itineraryPlaceRepository.findAllByItineraryIdWithPlace(itineraryId);
        return list.stream().map(this::toResponse).collect(Collectors.toList());
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
            if (!isOwner) {
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
