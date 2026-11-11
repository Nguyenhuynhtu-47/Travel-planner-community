package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.response.AdministrativeAreaResponse;
import Travel_Planner.Travel_Planner.dto.response.AdministrativeAreaSearchResultResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.AdministrativeArea;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaStatus;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaType;
import Travel_Planner.Travel_Planner.repository.AdministrativeAreaRepository;
import Travel_Planner.Travel_Planner.service.AdministrativeAreaService;
import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

@Service
@Transactional(readOnly = true)
public class AdministrativeAreaServiceImpl implements AdministrativeAreaService {

    private static final Logger log = LoggerFactory.getLogger(AdministrativeAreaServiceImpl.class);

    private final AdministrativeAreaRepository administrativeAreaRepository;

    private final Cache<String, List<AdministrativeAreaResponse>> provincesCache = Caffeine.newBuilder()
            .maximumSize(5)
            .expireAfterWrite(Duration.ofHours(24))
            .build();

    private final Cache<String, List<AdministrativeAreaResponse>> childrenCache = Caffeine.newBuilder()
            .maximumSize(100)
            .expireAfterWrite(Duration.ofHours(24))
            .build();

    private final Cache<String, AdministrativeAreaResponse> codeCache = Caffeine.newBuilder()
            .maximumSize(5000)
            .expireAfterWrite(Duration.ofHours(24))
            .build();

    public AdministrativeAreaServiceImpl(AdministrativeAreaRepository administrativeAreaRepository) {
        this.administrativeAreaRepository = administrativeAreaRepository;
    }

    @Override
    public List<AdministrativeAreaResponse> getProvinces() {
        return provincesCache.get("ALL_PROVINCES", key -> {
            log.debug("Provinces cache MISS. Fetching from database...");
            List<AdministrativeArea> entities = administrativeAreaRepository.findByAreaTypeInAndStatusOrderByCodeAsc(
                    List.of(AdministrativeAreaType.PROVINCE, AdministrativeAreaType.CENTRAL_CITY),
                    AdministrativeAreaStatus.ACTIVE
            );
            return entities.stream()
                    .map(AdministrativeAreaResponse::fromEntity)
                    .collect(Collectors.toList());
        });
    }

    @Override
    public List<AdministrativeAreaResponse> getChildren(String parentCode) {
        if (parentCode == null || parentCode.isBlank()) {
            throw new BadRequestException("Mã đơn vị hành chính cha không được để trống");
        }
        String cleanParentCode = parentCode.trim();

        // Verify parent exists
        if (!administrativeAreaRepository.existsByCode(cleanParentCode)) {
            throw new ResourceNotFoundException("Không tìm thấy đơn vị hành chính với mã: " + cleanParentCode);
        }

        return childrenCache.get(cleanParentCode, key -> {
            log.debug("Children cache MISS for parent code '{}'. Fetching from database...", key);
            List<AdministrativeArea> entities = administrativeAreaRepository.findNonQuarantinedChildrenByParentCode(
                    key,
                    AdministrativeAreaStatus.ACTIVE
            );
            return entities.stream()
                    .map(AdministrativeAreaResponse::fromEntity)
                    .collect(Collectors.toList());
        });
    }

    @Override
    public List<AdministrativeAreaSearchResultResponse> searchAreas(String query, int limit) {
        if (query == null || query.isBlank()) {
            return Collections.emptyList();
        }

        String trimmed = query.trim();
        if (trimmed.length() > 100) {
            throw new BadRequestException("Từ khóa tìm kiếm không được vượt quá 100 ký tự");
        }

        int effectiveLimit = Math.max(1, Math.min(50, limit));
        String normalized = LocationRankingServiceImpl.normalizeText(trimmed);
        if (normalized.isBlank()) {
            return Collections.emptyList();
        }

        List<AdministrativeArea> entities = administrativeAreaRepository.searchNonQuarantined(
                normalized,
                trimmed,
                normalized,
                normalized + "%",
                AdministrativeAreaStatus.ACTIVE,
                PageRequest.of(0, effectiveLimit)
        );

        return entities.stream()
                .map(AdministrativeAreaSearchResultResponse::fromEntity)
                .collect(Collectors.toList());
    }

    @Override
    public AdministrativeAreaResponse getByCode(String code) {
        if (code == null || code.isBlank()) {
            throw new BadRequestException("Mã đơn vị hành chính không được để trống");
        }
        String cleanCode = code.trim();

        return codeCache.get(cleanCode, key -> {
            AdministrativeArea entity = administrativeAreaRepository.findByCode(key)
                    .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn vị hành chính với mã: " + key));
            return AdministrativeAreaResponse.fromEntity(entity);
        });
    }

    @Override
    public void clearCache() {
        log.info("Invalidating administrative area in-memory caches");
        provincesCache.invalidateAll();
        childrenCache.invalidateAll();
        codeCache.invalidateAll();
    }
}
