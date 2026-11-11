package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.CreatePlaceRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdatePlaceRequest;
import Travel_Planner.Travel_Planner.dto.response.AdministrativeAreaSummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceDetailResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceProviderMappingResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.AdministrativeArea;
import Travel_Planner.Travel_Planner.model.Place;
import Travel_Planner.Travel_Planner.model.PlaceProviderMapping;
import Travel_Planner.Travel_Planner.model.enums.PlaceCategory;
import Travel_Planner.Travel_Planner.model.enums.PlaceStatus;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaTrustClassification;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaType;
import Travel_Planner.Travel_Planner.repository.AdministrativeAreaRepository;
import Travel_Planner.Travel_Planner.repository.PlaceProviderMappingRepository;
import Travel_Planner.Travel_Planner.repository.PlaceRepository;
import Travel_Planner.Travel_Planner.resolver.impl.AdministrativeAreaResolverImpl;
import Travel_Planner.Travel_Planner.service.PlaceNormalizationService;
import Travel_Planner.Travel_Planner.service.PlaceService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@Transactional
public class PlaceServiceImpl implements PlaceService {

    private final PlaceRepository placeRepository;
    private final PlaceProviderMappingRepository mappingRepository;
    private final PlaceNormalizationService normalizationService;
    private final AdministrativeAreaRepository administrativeAreaRepository;

    public PlaceServiceImpl(PlaceRepository placeRepository,
                            PlaceProviderMappingRepository mappingRepository,
                            PlaceNormalizationService normalizationService) {
        this(placeRepository, mappingRepository, normalizationService, null);
    }

    @org.springframework.beans.factory.annotation.Autowired
    public PlaceServiceImpl(PlaceRepository placeRepository,
                            PlaceProviderMappingRepository mappingRepository,
                            PlaceNormalizationService normalizationService,
                            AdministrativeAreaRepository administrativeAreaRepository) {
        this.placeRepository = placeRepository;
        this.mappingRepository = mappingRepository;
        this.normalizationService = normalizationService;
        this.administrativeAreaRepository = administrativeAreaRepository;
    }

    @Override
    @Transactional(readOnly = true)
    public Page<PlaceResponse> searchPlaces(String keyword,
                                           PlaceCategory category,
                                           String administrativeAreaCode,
                                           Long administrativeAreaId,
                                           Double lat,
                                           Double lon,
                                           Double radiusKm,
                                           Pageable pageable) {
        String trimmedKw = (keyword != null && !keyword.isBlank()) ? keyword.trim() : null;
        String normKw = trimmedKw != null ? normalizationService.normalizeText(trimmedKw) : null;

        Long resolvedAreaId = administrativeAreaId;
        Boolean isProvince = null;

        if (administrativeAreaCode != null && !administrativeAreaCode.isBlank() && administrativeAreaRepository != null) {
            String cleanCode = administrativeAreaCode.trim();
            // Quarantine invariant: return empty page for quarantined areas
            if (AdministrativeAreaResolverImpl.QUARANTINED_BAC_NINH_CODES.contains(cleanCode)) {
                return Page.empty(pageable);
            }
            Optional<AdministrativeArea> areaOpt = administrativeAreaRepository.findByCode(cleanCode);
            if (areaOpt.isEmpty()) {
                return Page.empty(pageable);
            }
            AdministrativeArea area = areaOpt.get();
            if (area.getTrustClassification() == AdministrativeAreaTrustClassification.UNVERIFIED_AND_QUARANTINED) {
                return Page.empty(pageable);
            }
            resolvedAreaId = area.getAreaId();
            isProvince = (area.getAreaType() == AdministrativeAreaType.PROVINCE || area.getAreaType() == AdministrativeAreaType.CENTRAL_CITY);
        } else if (resolvedAreaId != null && administrativeAreaRepository != null) {
            Optional<AdministrativeArea> areaOpt = administrativeAreaRepository.findById(resolvedAreaId);
            if (areaOpt.isPresent()) {
                AdministrativeArea area = areaOpt.get();
                if (area.getTrustClassification() == AdministrativeAreaTrustClassification.UNVERIFIED_AND_QUARANTINED) {
                    return Page.empty(pageable);
                }
                isProvince = (area.getAreaType() == AdministrativeAreaType.PROVINCE || area.getAreaType() == AdministrativeAreaType.CENTRAL_CITY);
            }
        }

        if (radiusKm != null) {
            if (radiusKm <= 0.0 || radiusKm > 500.0) {
                throw new BadRequestException("Bán kính tìm kiếm (radiusKm) phải lớn hơn 0 và không vượt quá 500 km");
            }
            if (lat == null || lon == null) {
                throw new BadRequestException("Tọa độ latitude và longitude phải được cung cấp cùng với radiusKm");
            }
            validateCoordinates(BigDecimal.valueOf(lat), BigDecimal.valueOf(lon));
            return searchByRadiusWithAdminArea(trimmedKw, normKw, category, resolvedAreaId, isProvince, lat, lon, radiusKm, pageable);
        } else if (lat != null && lon != null) {
            validateCoordinates(BigDecimal.valueOf(lat), BigDecimal.valueOf(lon));
        }

        Page<Place> page;
        if (resolvedAreaId != null) {
            page = placeRepository.searchPlacesWithAdminArea(trimmedKw, normKw, category, resolvedAreaId, isProvince, pageable);
        } else {
            page = placeRepository.searchPlaces(trimmedKw, normKw, category, PlaceStatus.ACTIVE, pageable);
        }
        return page != null ? page.map(this::toResponse) : Page.empty(pageable);
    }

    private Page<PlaceResponse> searchByRadiusWithAdminArea(String keyword,
                                                           String normKeyword,
                                                           PlaceCategory category,
                                                           Long areaId,
                                                           Boolean isProvince,
                                                           double lat,
                                                           double lon,
                                                           double radiusKm,
                                                           Pageable pageable) {
        double cosLat = Math.cos(Math.toRadians(lat));
        double dLat = radiusKm / 111.0;
        double dLon = Math.abs(cosLat) > 1e-6 ? (radiusKm / (111.0 * cosLat)) : 180.0;

        BigDecimal minLat = BigDecimal.valueOf(Math.max(-90.0, lat - dLat));
        BigDecimal maxLat = BigDecimal.valueOf(Math.min(90.0, lat + dLat));
        BigDecimal minLon = BigDecimal.valueOf(Math.max(-180.0, lon - dLon));
        BigDecimal maxLon = BigDecimal.valueOf(Math.min(180.0, lon + dLon));

        List<Place> candidates = placeRepository.findInBoundingBox(minLat, maxLat, minLon, maxLon);

        List<PlaceResponse> matched = new ArrayList<>();
        for (Place p : candidates) {
            if (category != null && p.getCategory() != category) {
                continue;
            }
            if (areaId != null) {
                if (p.getAdministrativeArea() == null) {
                    continue;
                }
                if (Boolean.TRUE.equals(isProvince)) {
                    boolean matchProv = areaId.equals(p.getAdministrativeArea().getAreaId())
                            || (p.getAdministrativeArea().getParent() != null && areaId.equals(p.getAdministrativeArea().getParent().getAreaId()));
                    if (!matchProv) continue;
                } else {
                    if (!areaId.equals(p.getAdministrativeArea().getAreaId())) {
                        continue;
                    }
                }
            }
            if (keyword != null && !keyword.isBlank()) {
                boolean matches = p.getName().toLowerCase(Locale.ROOT).contains(keyword.toLowerCase(Locale.ROOT))
                        || p.getNormalizedName().contains(normKeyword)
                        || p.getAddress().toLowerCase(Locale.ROOT).contains(keyword.toLowerCase(Locale.ROOT));
                if (!matches) continue;
            }

            double distMeters = normalizationService.haversineDistanceMeters(
                    lat, lon, p.getLatitude().doubleValue(), p.getLongitude().doubleValue());
            double distKm = distMeters / 1000.0;
            if (distKm <= radiusKm) {
                PlaceResponse resp = toResponse(p);
                resp.setDistanceKm(BigDecimal.valueOf(distKm).setScale(2, RoundingMode.HALF_UP).doubleValue());
                matched.add(resp);
            }
        }

        // Sort by distance ascending
        matched.sort(Comparator.comparingDouble(r -> r.getDistanceKm() != null ? r.getDistanceKm() : Double.MAX_VALUE));

        // Paginate in memory
        int start = (int) pageable.getOffset();
        int end = Math.min((start + pageable.getPageSize()), matched.size());
        List<PlaceResponse> sublist = (start <= matched.size()) ? matched.subList(start, end) : Collections.emptyList();

        return new PageImpl<>(sublist, pageable, matched.size());
    }

    @Override
    @Transactional(readOnly = true)
    public PlaceDetailResponse getPublicPlaceById(Long id) {
        Place place = placeRepository.findByPlaceIdAndStatus(id, PlaceStatus.ACTIVE)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy địa điểm công khai với ID: " + id));
        return toDetailResponse(place);
    }

    @Override
    @Transactional(readOnly = true)
    public Page<PlaceResponse> getAdminPlaces(String keyword,
                                             PlaceCategory category,
                                             PlaceStatus status,
                                             Pageable pageable) {
        String trimmedKw = (keyword != null && !keyword.isBlank()) ? keyword.trim() : null;
        String normKw = trimmedKw != null ? normalizationService.normalizeText(trimmedKw) : null;
        Page<Place> page = placeRepository.searchPlaces(trimmedKw, normKw, category, status, pageable);
        return page.map(this::toResponse);
    }

    @Override
    @Transactional(readOnly = true)
    public PlaceDetailResponse getAdminPlaceById(Long id) {
        Place place = placeRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy địa điểm với ID: " + id));
        return toDetailResponse(place);
    }

    @Override
    public PlaceDetailResponse createPlace(CreatePlaceRequest request) {
        validateCoordinates(request.getLatitude(), request.getLongitude());

        String normName = normalizationService.normalizeText(request.getName());
        String normAddress = normalizationService.normalizeAddress(request.getAddress());

        // Check if provider mapping already exists
        if (request.getProvider() != null && request.getProviderPlaceId() != null) {
            String prov = request.getProvider().trim();
            String provId = request.getProviderPlaceId().trim();
            if (mappingRepository.existsByProviderAndProviderPlaceId(prov, provId)) {
                throw new BadRequestException("Địa điểm từ nhà cung cấp '" + prov + "' với ID '" + provId + "' đã tồn tại trong catalog");
            }
        }

        // Check deduplication signals with nearby places (within 300m)
        double radiusMeters = 300.0;
        double dLat = (radiusMeters / 1000.0) / 111.0;
        double dLon = (radiusMeters / 1000.0) / (111.0 * Math.cos(Math.toRadians(request.getLatitude().doubleValue())));

        BigDecimal minLat = request.getLatitude().subtract(BigDecimal.valueOf(dLat));
        BigDecimal maxLat = request.getLatitude().add(BigDecimal.valueOf(dLat));
        BigDecimal minLon = request.getLongitude().subtract(BigDecimal.valueOf(dLon));
        BigDecimal maxLon = request.getLongitude().add(BigDecimal.valueOf(dLon));

        List<Place> nearby = placeRepository.findInBoundingBox(minLat, maxLat, minLon, maxLon);
        for (Place existing : nearby) {
            double confidence = normalizationService.calculateMatchConfidence(
                    existing, request.getName(), normAddress, request.getLatitude(), request.getLongitude(), request.getCategory()
            );
            if (confidence >= 0.85) {
                throw new BadRequestException("Địa điểm này trùng khớp với địa điểm đã có trong catalog: '" +
                        existing.getName() + "' (ID: " + existing.getPlaceId() + ", độ tin cậy: " + (int)(confidence * 100) + "%)");
            }
        }

        Place place = Place.builder()
                .name(request.getName().trim())
                .normalizedName(normName)
                .address(normAddress)
                .description(request.getDescription())
                .imageUrl(request.getImageUrl())
                .latitude(request.getLatitude())
                .longitude(request.getLongitude())
                .category(request.getCategory())
                .status(PlaceStatus.ACTIVE)
                .build();

        if (request.getProvider() != null && request.getProviderPlaceId() != null) {
            PlaceProviderMapping mapping = PlaceProviderMapping.builder()
                    .provider(request.getProvider().trim())
                    .providerPlaceId(request.getProviderPlaceId().trim())
                    .providerType(request.getProviderType())
                    .metadataJson(request.getMetadataJson())
                    .lastSyncedAt(LocalDateTime.now())
                    .build();
            place.addProviderMapping(mapping);
        }

        Place saved = placeRepository.save(place);
        return toDetailResponse(saved);
    }

    @Override
    public PlaceDetailResponse updatePlace(Long id, UpdatePlaceRequest request) {
        validateCoordinates(request.getLatitude(), request.getLongitude());

        Place place = placeRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy địa điểm với ID: " + id));

        place.setName(request.getName().trim());
        place.setNormalizedName(normalizationService.normalizeText(request.getName()));
        place.setAddress(normalizationService.normalizeAddress(request.getAddress()));
        place.setDescription(request.getDescription());
        place.setImageUrl(request.getImageUrl());
        place.setLatitude(request.getLatitude());
        place.setLongitude(request.getLongitude());
        place.setCategory(request.getCategory());
        place.setStatus(request.getStatus());

        Place saved = placeRepository.save(place);
        return toDetailResponse(saved);
    }

    @Override
    public void deletePlace(Long id) {
        Place place = placeRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy địa điểm với ID: " + id));
        // Soft delete: sets status to HIDDEN
        place.setStatus(PlaceStatus.HIDDEN);
        placeRepository.save(place);
    }

    @Override
    public PlaceDetailResponse resolveOrPersistPlace(String provider,
                                                     String providerPlaceId,
                                                     String name,
                                                     String address,
                                                     BigDecimal latitude,
                                                     BigDecimal longitude,
                                                     String rawCategory,
                                                     String rawType,
                                                     String metadataJson) {
        validateCoordinates(latitude, longitude);
        String prov = (provider != null && !provider.isBlank()) ? provider.trim() : "MANUAL";
        String provId = (providerPlaceId != null && !providerPlaceId.isBlank()) ? providerPlaceId.trim() : UUID.randomUUID().toString();

        // 1. Direct provider mapping match
        Optional<PlaceProviderMapping> existingMapping = mappingRepository.findByProviderAndProviderPlaceId(prov, provId);
        if (existingMapping.isPresent()) {
            Place place = existingMapping.get().getPlace();
            existingMapping.get().setLastSyncedAt(LocalDateTime.now());
            mappingRepository.save(existingMapping.get());
            return toDetailResponse(place);
        }

        // 2. Spatial and multi-signal deduplication against nearby places (within 300m)
        PlaceCategory category = normalizationService.mapProviderCategory(rawCategory, rawType);
        String normAddress = normalizationService.normalizeAddress(address);

        double radiusMeters = 300.0;
        double latVal = latitude.doubleValue();
        double cosLat = Math.cos(Math.toRadians(latVal));
        double dLat = (radiusMeters / 1000.0) / 111.0;
        double dLon = Math.abs(cosLat) > 1e-6 ? ((radiusMeters / 1000.0) / (111.0 * cosLat)) : 180.0;

        BigDecimal minLat = BigDecimal.valueOf(Math.max(-90.0, latVal - dLat));
        BigDecimal maxLat = BigDecimal.valueOf(Math.min(90.0, latVal + dLat));
        BigDecimal minLon = BigDecimal.valueOf(Math.max(-180.0, longitude.doubleValue() - dLon));
        BigDecimal maxLon = BigDecimal.valueOf(Math.min(180.0, longitude.doubleValue() + dLon));

        List<Place> nearby = placeRepository.findInBoundingBox(minLat, maxLat, minLon, maxLon);
        Place bestMatch = null;
        double highestConfidence = 0.0;

        for (Place candidate : nearby) {
            double confidence = normalizationService.calculateMatchConfidence(
                    candidate, name, normAddress, latitude, longitude, category
            );
            if (confidence >= 0.85 && confidence > highestConfidence) {
                highestConfidence = confidence;
                bestMatch = candidate;
            }
        }

        if (bestMatch != null) {
            // Attach new provider mapping to existing matched Place
            PlaceProviderMapping newMapping = PlaceProviderMapping.builder()
                    .place(bestMatch)
                    .provider(prov)
                    .providerPlaceId(provId)
                    .providerType(rawType)
                    .metadataJson(metadataJson)
                    .lastSyncedAt(LocalDateTime.now())
                    .build();
            mappingRepository.save(newMapping);
            bestMatch.getProviderMappings().add(newMapping);
            return toDetailResponse(bestMatch);
        }

        // 3. No match found: create new canonical Place
        Place newPlace = Place.builder()
                .name(name.trim())
                .normalizedName(normalizationService.normalizeText(name))
                .address(normAddress)
                .latitude(latitude)
                .longitude(longitude)
                .category(category)
                .status(PlaceStatus.ACTIVE)
                .build();

        PlaceProviderMapping mapping = PlaceProviderMapping.builder()
                .provider(prov)
                .providerPlaceId(provId)
                .providerType(rawType)
                .metadataJson(metadataJson)
                .lastSyncedAt(LocalDateTime.now())
                .build();
        newPlace.addProviderMapping(mapping);

        Place saved = placeRepository.save(newPlace);
        return toDetailResponse(saved);
    }

    private void validateCoordinates(BigDecimal latitude, BigDecimal longitude) {
        if (latitude == null || longitude == null) {
            throw new BadRequestException("Tọa độ không được để trống");
        }
        double lat = latitude.doubleValue();
        double lon = longitude.doubleValue();
        if (lat < -90.0 || lat > 90.0) {
            throw new BadRequestException("Vĩ độ không hợp lệ: " + lat + " (phải trong khoảng [-90.0, 90.0])");
        }
        if (lon < -180.0 || lon > 180.0) {
            throw new BadRequestException("Kinh độ không hợp lệ: " + lon + " (phải trong khoảng [-180.0, 180.0])");
        }
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

    private PlaceResponse toResponse(Place place) {
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

    private PlaceDetailResponse toDetailResponse(Place place) {
        List<PlaceProviderMappingResponse> mappings = place.getProviderMappings() != null
                ? place.getProviderMappings().stream()
                .map(m -> PlaceProviderMappingResponse.builder()
                        .mappingId(m.getMappingId())
                        .provider(m.getProvider())
                        .providerPlaceId(m.getProviderPlaceId())
                        .providerType(m.getProviderType())
                        .lastSyncedAt(m.getLastSyncedAt())
                        .build())
                .collect(Collectors.toList())
                : Collections.emptyList();

        return PlaceDetailResponse.builder()
                .placeId(place.getPlaceId())
                .name(place.getName())
                .address(place.getAddress())
                .description(place.getDescription())
                .imageUrl(place.getImageUrl())
                .latitude(place.getLatitude())
                .longitude(place.getLongitude())
                .category(place.getCategory())
                .status(place.getStatus())
                .providerMappings(mappings)
                .administrativeArea(toSummaryResponse(place.getAdministrativeArea()))
                .createdAt(place.getCreatedAt())
                .updatedAt(place.getUpdatedAt())
                .build();
    }
}

