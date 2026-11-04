package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.CreateDestinationRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdateDestinationRequest;
import Travel_Planner.Travel_Planner.dto.response.DestinationResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.Destination;
import Travel_Planner.Travel_Planner.model.enums.DestinationStatus;
import Travel_Planner.Travel_Planner.repository.DestinationRepository;
import Travel_Planner.Travel_Planner.service.DestinationService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.stream.Collectors;

@Service
@Transactional
public class DestinationServiceImpl implements DestinationService {

    private final DestinationRepository destinationRepository;

    public DestinationServiceImpl(DestinationRepository destinationRepository) {
        this.destinationRepository = destinationRepository;
    }

    @Override
    @Transactional(readOnly = true)
    public List<DestinationResponse> getPublicDestinations(String keyword) {
        List<Destination> destinations;
        if (keyword != null && !keyword.trim().isEmpty()) {
            destinations = destinationRepository.findByNameContainingIgnoreCaseAndStatus(
                    keyword.trim(), DestinationStatus.ACTIVE);
        } else {
            destinations = destinationRepository.findByStatus(DestinationStatus.ACTIVE);
        }
        return destinations.stream().map(this::toResponse).collect(Collectors.toList());
    }

    @Override
    @Transactional(readOnly = true)
    public DestinationResponse getPublicDestinationById(Integer id) {
        return destinationRepository.findById(id)
                .filter(d -> d.getStatus() == DestinationStatus.ACTIVE)
                .map(this::toResponse)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy điểm đến với ID: " + id));
    }

    @Override
    @Transactional(readOnly = true)
    public List<DestinationResponse> getAdminDestinations(String keyword, DestinationStatus status) {
        List<Destination> destinations;
        boolean hasKeyword = keyword != null && !keyword.trim().isEmpty();

        if (status != null) {
            if (hasKeyword) {
                destinations = destinationRepository.findByNameContainingIgnoreCaseAndStatus(keyword.trim(), status);
            } else {
                destinations = destinationRepository.findByStatus(status);
            }
        } else {
            if (hasKeyword) {
                destinations = destinationRepository.findByNameContainingIgnoreCase(keyword.trim());
            } else {
                destinations = destinationRepository.findAll();
            }
        }
        return destinations.stream().map(this::toResponse).collect(Collectors.toList());
    }

    @Override
    @Transactional(readOnly = true)
    public DestinationResponse getAdminDestinationById(Integer id) {
        return destinationRepository.findById(id)
                .map(this::toResponse)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy điểm đến với ID: " + id));
    }

    @Override
    public DestinationResponse createDestination(CreateDestinationRequest request) {
        String trimmedName = request.getName().trim();
        if (destinationRepository.existsByName(trimmedName)) {
            throw new BadRequestException("Điểm đến với tên '" + trimmedName + "' đã tồn tại");
        }

        validateCoordinates(request.getLatitude(), request.getLongitude());

        Destination destination = Destination.builder()
                .name(trimmedName)
                .address(request.getAddress().trim())
                .description(request.getDescription())
                .imageUrl(request.getImageUrl())
                .latitude(normalizeCoordinate(request.getLatitude()))
                .longitude(normalizeCoordinate(request.getLongitude()))
                .status(request.getStatus() != null ? request.getStatus() : DestinationStatus.ACTIVE)
                .build();

        Destination saved = destinationRepository.save(destination);
        return toResponse(saved);
    }

    @Override
    public DestinationResponse updateDestination(Integer id, UpdateDestinationRequest request) {
        Destination destination = destinationRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy điểm đến với ID: " + id));

        String trimmedName = request.getName().trim();
        destinationRepository.findByName(trimmedName)
                .filter(existing -> !existing.getDestinationId().equals(id))
                .ifPresent(existing -> {
                    throw new BadRequestException("Điểm đến với tên '" + trimmedName + "' đã tồn tại");
                });

        validateCoordinates(request.getLatitude(), request.getLongitude());

        destination.setName(trimmedName);
        destination.setAddress(request.getAddress().trim());
        destination.setDescription(request.getDescription());
        destination.setImageUrl(request.getImageUrl());
        destination.setLatitude(normalizeCoordinate(request.getLatitude()));
        destination.setLongitude(normalizeCoordinate(request.getLongitude()));
        if (request.getStatus() != null) {
            destination.setStatus(request.getStatus());
        }

        Destination saved = destinationRepository.save(destination);
        return toResponse(saved);
    }

    @Override
    public void deleteDestination(Integer id) {
        Destination destination = destinationRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy điểm đến với ID: " + id));

        // Soft-delete to preserve foreign key integrity with existing user activity itineraries
        destination.setStatus(DestinationStatus.HIDDEN);
        destinationRepository.save(destination);
    }

    private void validateCoordinates(BigDecimal lat, BigDecimal lon) {
        if ((lat != null && lon == null) || (lat == null && lon != null)) {
            throw new BadRequestException("Tọa độ phải bao gồm cả vĩ độ (latitude) và kinh độ (longitude)");
        }
        if (lat != null) {
            if (lat.compareTo(BigDecimal.valueOf(-90.0)) < 0 || lat.compareTo(BigDecimal.valueOf(90.0)) > 0) {
                throw new BadRequestException("Vĩ độ (latitude) phải nằm trong khoảng từ -90.0 đến 90.0");
            }
        }
        if (lon != null) {
            if (lon.compareTo(BigDecimal.valueOf(-180.0)) < 0 || lon.compareTo(BigDecimal.valueOf(180.0)) > 0) {
                throw new BadRequestException("Kinh độ (longitude) phải nằm trong khoảng từ -180.0 đến 180.0");
            }
        }
    }

    private BigDecimal normalizeCoordinate(BigDecimal coord) {
        if (coord == null) {
            return null;
        }
        // Normalizes to 7 decimal places matching MySQL column definition
        return coord.setScale(7, RoundingMode.HALF_UP);
    }

    private DestinationResponse toResponse(Destination destination) {
        return DestinationResponse.builder()
                .destinationId(destination.getDestinationId())
                .name(destination.getName())
                .address(destination.getAddress())
                .description(destination.getDescription())
                .imageUrl(destination.getImageUrl())
                .latitude(destination.getLatitude())
                .longitude(destination.getLongitude())
                .status(destination.getStatus())
                .build();
    }
}

