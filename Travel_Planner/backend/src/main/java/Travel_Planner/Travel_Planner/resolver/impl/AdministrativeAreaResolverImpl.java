package Travel_Planner.Travel_Planner.resolver.impl;

import Travel_Planner.Travel_Planner.dto.response.AdministrativeAreaSummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceResolutionResultResponse;
import Travel_Planner.Travel_Planner.model.AdministrativeArea;
import Travel_Planner.Travel_Planner.model.Place;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaStatus;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaTrustClassification;
import Travel_Planner.Travel_Planner.model.enums.ConfidenceClassification;
import Travel_Planner.Travel_Planner.repository.AdministrativeAreaRepository;
import Travel_Planner.Travel_Planner.resolver.AdministrativeAreaResolver;
import Travel_Planner.Travel_Planner.service.impl.LocationRankingServiceImpl;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.util.*;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * Implementation of AdministrativeAreaResolver.
 * 
 * Enforces:
 * 1. Exact verified administrative code matching.
 * 2. Structured address decomposition & canonical province/commune resolution.
 * 3. Absolute quarantine exclusion for the 12 unverified Bắc Ninh records (NQ 388/NQ-UBTVQH16).
 * 4. Coordinate boundary validation across Vietnam territory [8.0-24.0 Lat, 102.0-110.0 Lon].
 * 5. Explanatory confidence assignment (HIGH_CONFIDENCE, MEDIUM_CONFIDENCE, AMBIGUOUS, UNVERIFIED, NO_MATCH).
 */
@Component
public class AdministrativeAreaResolverImpl implements AdministrativeAreaResolver {

    private static final Logger log = LoggerFactory.getLogger(AdministrativeAreaResolverImpl.class);

    public static final Set<String> QUARANTINED_BAC_NINH_CODES = Set.of(
            "07294", "07375", "07399", "07444", "07840", "09193",
            "09292", "09313", "09319", "09454", "09475", "09496"
    );

    private static final Pattern PREFIX_PATTERN = Pattern.compile(
            "^(phường|xã|thị trấn|đặc khu|tp\\.|thành phố|tỉnh|quận|huyện|thị xã)\\s+",
            Pattern.CASE_INSENSITIVE | Pattern.UNICODE_CASE
    );

    private static final Map<String, String> PROVINCE_ALIASES = new LinkedHashMap<>();

    static {
        // Direct province name variations & diacritic mappings (sorted by length descending within logical groups)
        PROVINCE_ALIASES.put("thành phố hồ chí minh", "79");
        PROVINCE_ALIASES.put("thanh pho ho chi minh", "79");
        PROVINCE_ALIASES.put("thừa thiên huế", "46");
        PROVINCE_ALIASES.put("thua thien hue", "46");
        PROVINCE_ALIASES.put("bà rịa vũng tàu", "79");
        PROVINCE_ALIASES.put("ba ria vung tau", "79");
        PROVINCE_ALIASES.put("tp. hồ chí minh", "79");
        PROVINCE_ALIASES.put("tp. ho chi minh", "79");
        PROVINCE_ALIASES.put("hồ chí minh", "79");
        PROVINCE_ALIASES.put("ho chi minh", "79");
        PROVINCE_ALIASES.put("quảng ninh", "22");
        PROVINCE_ALIASES.put("quang ninh", "22");
        PROVINCE_ALIASES.put("bắc ninh", "24");
        PROVINCE_ALIASES.put("bac ninh", "24");
        PROVINCE_ALIASES.put("hải phòng", "31");
        PROVINCE_ALIASES.put("hai phong", "31");
        PROVINCE_ALIASES.put("lào cai", "15");
        PROVINCE_ALIASES.put("lao cai", "15");
        PROVINCE_ALIASES.put("ninh bình", "37");
        PROVINCE_ALIASES.put("ninh binh", "37");
        PROVINCE_ALIASES.put("quảng nam", "48");
        PROVINCE_ALIASES.put("quang nam", "48");
        PROVINCE_ALIASES.put("đà nẵng", "48");
        PROVINCE_ALIASES.put("da nang", "48");
        PROVINCE_ALIASES.put("lâm đồng", "68");
        PROVINCE_ALIASES.put("lam dong", "68");
        PROVINCE_ALIASES.put("bình thuận", "68");
        PROVINCE_ALIASES.put("binh thuan", "68");
        PROVINCE_ALIASES.put("đồng nai", "75");
        PROVINCE_ALIASES.put("dong nai", "75");
        PROVINCE_ALIASES.put("quảng trị", "44");
        PROVINCE_ALIASES.put("quang tri", "44");
        PROVINCE_ALIASES.put("quảng bình", "44");
        PROVINCE_ALIASES.put("quang binh", "44");
        PROVINCE_ALIASES.put("an giang", "91");
        PROVINCE_ALIASES.put("kiên giang", "91");
        PROVINCE_ALIASES.put("kien giang", "91");
        PROVINCE_ALIASES.put("phú quốc", "91");
        PROVINCE_ALIASES.put("phu quoc", "91");
        PROVINCE_ALIASES.put("cần thơ", "92");
        PROVINCE_ALIASES.put("can tho", "92");
        PROVINCE_ALIASES.put("sài gòn", "79");
        PROVINCE_ALIASES.put("sai gon", "79");
        PROVINCE_ALIASES.put("hà nội", "01");
        PROVINCE_ALIASES.put("ha noi", "01");
        PROVINCE_ALIASES.put("sa pa", "15");
        PROVINCE_ALIASES.put("hoa lư", "37");
        PROVINCE_ALIASES.put("hội an", "48");
        PROVINCE_ALIASES.put("đà lạt", "68");
        PROVINCE_ALIASES.put("da lat", "68");
        PROVINCE_ALIASES.put("huế", "46");
        PROVINCE_ALIASES.put("hue", "46");
    }

    private final AdministrativeAreaRepository areaRepository;

    public AdministrativeAreaResolverImpl(AdministrativeAreaRepository areaRepository) {
        this.areaRepository = areaRepository;
    }

    @Override
    public PlaceResolutionResultResponse resolve(Place place) {
        if (place == null) {
            return PlaceResolutionResultResponse.builder()
                    .confidence(ConfidenceClassification.NO_MATCH)
                    .matchMethod("NULL_PLACE")
                    .explanation("Place entity is null")
                    .eligibleForAutoLink(false)
                    .candidateAreas(Collections.emptyList())
                    .warnings(Collections.emptyList())
                    .build();
        }

        Double lat = place.getLatitude() != null ? place.getLatitude().doubleValue() : null;
        Double lon = place.getLongitude() != null ? place.getLongitude().doubleValue() : null;
        boolean currentlyLinked = place.getAdministrativeArea() != null;

        PlaceResolutionResultResponse result = resolve(
                place.getPlaceId(),
                place.getName(),
                place.getAddress(),
                lat,
                lon,
                null
        );
        result.setCurrentlyLinked(currentlyLinked);
        return result;
    }

    @Override
    public PlaceResolutionResultResponse resolve(
            Long placeId,
            String name,
            String address,
            Double latitude,
            Double longitude,
            String candidateCode
    ) {
        List<String> warnings = new ArrayList<>();

        // 1. Validate spatial coordinates if present
        if (latitude != null && longitude != null) {
            if (latitude < 8.0 || latitude > 24.0 || longitude < 102.0 || longitude > 110.0) {
                warnings.add("Tọa độ [" + latitude + ", " + longitude + "] nằm ngoài khung lãnh thổ Việt Nam");
            }
        }

        // 2. Priority 1: Candidate administrative code (if provided)
        if (candidateCode != null && !candidateCode.isBlank()) {
            String trimmedCode = candidateCode.trim();
            if (QUARANTINED_BAC_NINH_CODES.contains(trimmedCode)) {
                log.warn("[QUARANTINE_GUARD] Candidate code {} is quarantined under NQ 388/NQ-UBTVQH16. Link rejected for placeId={}",
                        trimmedCode, placeId);
                return PlaceResolutionResultResponse.builder()
                        .placeId(placeId)
                        .placeName(name)
                        .placeAddress(address)
                        .resolvedArea(null)
                        .confidence(ConfidenceClassification.UNVERIFIED)
                        .matchMethod("QUARANTINED_CODE_REJECTED")
                        .explanation("Mã đơn vị hành chính " + trimmedCode + " thuộc danh mục cách ly Bắc Ninh (NQ 388/NQ-UBTVQH16 thiếu phụ lục gốc)")
                        .eligibleForAutoLink(false)
                        .candidateAreas(Collections.emptyList())
                        .warnings(List.of("Mã đơn vị hành chính đang bị cách ly pháp lý"))
                        .build();
            }

            Optional<AdministrativeArea> areaOpt = areaRepository.findByCodeWithParent(trimmedCode);
            if (areaOpt.isPresent()) {
                AdministrativeArea area = areaOpt.get();
                if (area.getTrustClassification() == AdministrativeAreaTrustClassification.UNVERIFIED_AND_QUARANTINED) {
                    log.warn("[QUARANTINE_GUARD] Code {} is marked UNVERIFIED_AND_QUARANTINED. Link rejected for placeId={}",
                            trimmedCode, placeId);
                    return PlaceResolutionResultResponse.builder()
                            .placeId(placeId)
                            .placeName(name)
                            .placeAddress(address)
                            .resolvedArea(null)
                            .confidence(ConfidenceClassification.UNVERIFIED)
                            .matchMethod("QUARANTINED_AREA_REJECTED")
                            .explanation("Đơn vị hành chính " + trimmedCode + " bị cách ly trong CSDL")
                            .eligibleForAutoLink(false)
                            .candidateAreas(Collections.emptyList())
                            .warnings(List.of("Đơn vị hành chính bị cách ly"))
                            .build();
                }

                ConfidenceClassification conf = (area.getTrustClassification() == AdministrativeAreaTrustClassification.VERIFIED_AND_TRUSTED)
                        ? ConfidenceClassification.HIGH_CONFIDENCE
                        : ConfidenceClassification.MEDIUM_CONFIDENCE;

                return PlaceResolutionResultResponse.builder()
                        .placeId(placeId)
                        .placeName(name)
                        .placeAddress(address)
                        .resolvedArea(toSummary(area))
                        .confidence(conf)
                        .matchMethod("EXACT_CODE_MATCH")
                        .explanation("Khớp chính xác mã đơn vị hành chính " + trimmedCode + " (" + area.getName() + ")")
                        .eligibleForAutoLink(true)
                        .candidateAreas(List.of(toSummary(area)))
                        .warnings(warnings)
                        .build();
            } else {
                warnings.add("Không tìm thấy đơn vị hành chính với mã: " + trimmedCode);
            }
        }

        // 3. Priority 2: Structured Address Decomposition
        if ((address == null || address.isBlank()) && (name == null || name.isBlank())) {
            return PlaceResolutionResultResponse.builder()
                    .placeId(placeId)
                    .placeName(name)
                    .placeAddress(address)
                    .resolvedArea(null)
                    .confidence(ConfidenceClassification.NO_MATCH)
                    .matchMethod("NO_DATA")
                    .explanation("Không có thông tin địa chỉ hoặc tên địa điểm để phân giải")
                    .eligibleForAutoLink(false)
                    .candidateAreas(Collections.emptyList())
                    .warnings(warnings)
                    .build();
        }

        String rawText = ((address != null ? address : "") + " " + (name != null ? name : "")).trim();
        String normText = LocationRankingServiceImpl.normalizeText(rawText);

        // Detect province: prioritize address text first, fall back to place name
        String targetProvinceCode = detectProvince(address, name);

        // Check if matching quarantined Bắc Ninh by name
        if ("24".equals(targetProvinceCode)) {
            for (String qCode : QUARANTINED_BAC_NINH_CODES) {
                Optional<AdministrativeArea> qAreaOpt = areaRepository.findByCode(qCode);
                if (qAreaOpt.isPresent()) {
                    String qClean = cleanUnitPrefix(qAreaOpt.get().getName()).toLowerCase(Locale.ROOT);
                    if (rawText.toLowerCase(Locale.ROOT).contains(qClean) || normText.contains(LocationRankingServiceImpl.normalizeText(qClean))) {
                        log.warn("[QUARANTINE_GUARD] Place text matches quarantined Bắc Ninh area {} ({}). Link rejected for placeId={}",
                                qCode, qAreaOpt.get().getName(), placeId);
                        return PlaceResolutionResultResponse.builder()
                                .placeId(placeId)
                                .placeName(name)
                                .placeAddress(address)
                                .resolvedArea(null)
                                .confidence(ConfidenceClassification.UNVERIFIED)
                                .matchMethod("QUARANTINED_BAC_NINH_MATCH")
                                .explanation("Địa điểm thuộc đơn vị hành chính cách ly: " + qAreaOpt.get().getName() + " (" + qCode + ")")
                                .eligibleForAutoLink(false)
                                .candidateAreas(Collections.emptyList())
                                .warnings(List.of("Đơn vị hành chính thuộc danh mục cách ly Bắc Ninh"))
                                .build();
                    }
                }
            }
        }

        // If province is detected, search communes within province
        if (targetProvinceCode != null) {
            final String finalProvinceCode = targetProvinceCode;
            List<AdministrativeArea> provinceCommunes = areaRepository.findByParent_CodeAndStatusOrderByCodeAsc(
                    finalProvinceCode,
                    AdministrativeAreaStatus.ACTIVE
            );

            List<AdministrativeArea> matchedCommunes = new ArrayList<>();
            for (AdministrativeArea c : provinceCommunes) {
                String cleanName = cleanUnitPrefix(c.getName()).toLowerCase(Locale.ROOT);
                String normClean = LocationRankingServiceImpl.normalizeText(cleanName);

                if (rawText.toLowerCase(Locale.ROOT).contains(cleanName) || normText.contains(normClean)) {
                    matchedCommunes.add(c);
                }
            }

            // Disambiguation Rule 1: Province Homonym elimination
            // If one matched commune is named identically to the province (e.g. "Phường Lào Cai" in "Tỉnh Lào Cai")
            // and another matched commune represents a specific local division (e.g. "Phường Sa Pa"),
            // discard the province-homonymous commune.
            if (matchedCommunes.size() > 1) {
                Optional<AdministrativeArea> provAreaOpt = areaRepository.findByCode(finalProvinceCode);
                if (provAreaOpt.isPresent()) {
                    String provCleanNorm = LocationRankingServiceImpl.normalizeText(cleanUnitPrefix(provAreaOpt.get().getName()));
                    boolean hasNonProvincialCommune = matchedCommunes.stream()
                            .anyMatch(c -> !LocationRankingServiceImpl.normalizeText(cleanUnitPrefix(c.getName())).equals(provCleanNorm));
                    if (hasNonProvincialCommune) {
                        matchedCommunes = matchedCommunes.stream()
                                .filter(c -> !LocationRankingServiceImpl.normalizeText(cleanUnitPrefix(c.getName())).equals(provCleanNorm))
                                .collect(Collectors.toList());
                    }
                }
            }

            // Disambiguate matched communes
            if (matchedCommunes.size() == 1) {
                AdministrativeArea commune = matchedCommunes.get(0);
                if (QUARANTINED_BAC_NINH_CODES.contains(commune.getCode())) {
                    return PlaceResolutionResultResponse.builder()
                            .placeId(placeId)
                            .placeName(name)
                            .placeAddress(address)
                            .resolvedArea(null)
                            .confidence(ConfidenceClassification.UNVERIFIED)
                            .matchMethod("QUARANTINED_COMMUNE_REJECTED")
                            .explanation("Đơn vị hành chính " + commune.getCode() + " bị cách ly theo NQ 388")
                            .eligibleForAutoLink(false)
                            .candidateAreas(Collections.emptyList())
                            .warnings(List.of("Đơn vị hành chính bị cách ly"))
                            .build();
                }

                ConfidenceClassification conf = (commune.getTrustClassification() == AdministrativeAreaTrustClassification.VERIFIED_AND_TRUSTED)
                        ? ConfidenceClassification.HIGH_CONFIDENCE
                        : ConfidenceClassification.MEDIUM_CONFIDENCE;

                return PlaceResolutionResultResponse.builder()
                        .placeId(placeId)
                        .placeName(name)
                        .placeAddress(address)
                        .resolvedArea(toSummary(commune))
                        .confidence(conf)
                        .matchMethod("STRUCTURED_COMMUNE_MATCH")
                        .explanation("Khớp chính xác cấp xã/phường: " + commune.getName() + " (" + commune.getCode() + ")")
                        .eligibleForAutoLink(true)
                        .candidateAreas(List.of(toSummary(commune)))
                        .warnings(warnings)
                        .build();
            } else if (matchedCommunes.size() > 1) {
                // Find longest/most specific match
                matchedCommunes.sort((a, b) -> Integer.compare(b.getName().length(), a.getName().length()));
                AdministrativeArea best = matchedCommunes.get(0);
                AdministrativeArea second = matchedCommunes.get(1);

                // If best is compound name and contains second (e.g. "Văn Miếu - Quốc Tử Giám" vs "Đống Đa")
                if (best.getName().length() > second.getName().length() + 3) {
                    ConfidenceClassification conf = (best.getTrustClassification() == AdministrativeAreaTrustClassification.VERIFIED_AND_TRUSTED)
                            ? ConfidenceClassification.HIGH_CONFIDENCE
                            : ConfidenceClassification.MEDIUM_CONFIDENCE;

                    return PlaceResolutionResultResponse.builder()
                            .placeId(placeId)
                            .placeName(name)
                            .placeAddress(address)
                            .resolvedArea(toSummary(best))
                            .confidence(conf)
                            .matchMethod("SPECIFIC_COMMUNE_MATCH")
                            .explanation("Khớp đơn vị đặc thù nhất: " + best.getName() + " (" + best.getCode() + ")")
                            .eligibleForAutoLink(true)
                            .candidateAreas(matchedCommunes.stream().map(this::toSummary).collect(Collectors.toList()))
                            .warnings(warnings)
                            .build();
                } else {
                    return PlaceResolutionResultResponse.builder()
                            .placeId(placeId)
                            .placeName(name)
                            .placeAddress(address)
                            .resolvedArea(null)
                            .confidence(ConfidenceClassification.AMBIGUOUS)
                            .matchMethod("AMBIGUOUS_MULTI_COMMUNES")
                            .explanation("Tìm thấy nhiều xã/phường ứng viên có độ ưu tiên tương đương: " +
                                    matchedCommunes.stream().map(AdministrativeArea::getName).collect(Collectors.joining(", ")))
                            .eligibleForAutoLink(false)
                            .candidateAreas(matchedCommunes.stream().map(this::toSummary).collect(Collectors.toList()))
                            .warnings(warnings)
                            .build();
                }
            } else {
                // 0 communes matched within province -> Fallback to province-level unit
                Optional<AdministrativeArea> provAreaOpt = areaRepository.findByCodeWithParent(finalProvinceCode);
                if (provAreaOpt.isPresent()) {
                    AdministrativeArea prov = provAreaOpt.get();
                    return PlaceResolutionResultResponse.builder()
                            .placeId(placeId)
                            .placeName(name)
                            .placeAddress(address)
                            .resolvedArea(toSummary(prov))
                            .confidence(ConfidenceClassification.MEDIUM_CONFIDENCE)
                            .matchMethod("PROVINCE_LEVEL_FALLBACK")
                            .explanation("Địa chỉ xác định rõ tỉnh/thành phố: " + prov.getName() + " (" + prov.getCode() + "), không có đơn vị cấp xã độc nhất")
                            .eligibleForAutoLink(true)
                            .candidateAreas(List.of(toSummary(prov)))
                            .warnings(warnings)
                            .build();
                }
            }
        }

        // If no province detected, return NO_MATCH
        return PlaceResolutionResultResponse.builder()
                .placeId(placeId)
                .placeName(name)
                .placeAddress(address)
                .resolvedArea(null)
                .confidence(ConfidenceClassification.NO_MATCH)
                .matchMethod("NO_PROVINCE_OR_COMMUNE_MATCH")
                .explanation("Không tìm thấy đơn vị hành chính phù hợp từ dữ liệu địa chỉ và tọa độ")
                .eligibleForAutoLink(false)
                .candidateAreas(Collections.emptyList())
                .warnings(warnings)
                .build();
    }

    private String cleanUnitPrefix(String name) {
        if (name == null) return "";
        return PREFIX_PATTERN.matcher(name.trim()).replaceFirst("").trim();
    }

    private String detectProvince(String address, String name) {
        String rawAddress = (address != null ? address : "").trim();
        String normAddress = LocationRankingServiceImpl.normalizeText(rawAddress);

        // 1. Detect from address first (addresses explicitly contain the administrative hierarchy)
        String fromAddress = matchProvinceFromText(rawAddress, normAddress);
        if (fromAddress != null) {
            return fromAddress;
        }

        // 2. Fall back to name if address did not match
        String rawName = (name != null ? name : "").trim();
        String normName = LocationRankingServiceImpl.normalizeText(rawName);
        return matchProvinceFromText(rawName, normName);
    }

    private String matchProvinceFromText(String raw, String norm) {
        if (raw.isBlank() && norm.isBlank()) return null;
        String lowerRaw = raw.toLowerCase(Locale.ROOT);

        for (Map.Entry<String, String> entry : PROVINCE_ALIASES.entrySet()) {
            String key = entry.getKey();
            if (key.length() <= 4) {
                // Short keys (e.g. "huế", "hue"): require word boundary and ensure not preceded by "nguyễn" / "lê"
                Pattern shortWordPattern = Pattern.compile("(?:^|[^\\p{L}])" + Pattern.quote(key) + "(?:[^\\p{L}]|$)", Pattern.CASE_INSENSITIVE | Pattern.UNICODE_CASE);
                if (shortWordPattern.matcher(lowerRaw).find() || shortWordPattern.matcher(norm).find()) {
                    // Check if it's "nguyễn huệ" or "lê huệ" in raw text
                    if (lowerRaw.contains("nguyễn " + key) || norm.contains("nguyen " + key) || lowerRaw.contains("lê " + key)) {
                        continue;
                    }
                    return entry.getValue();
                }
            } else {
                if (lowerRaw.contains(key) || norm.contains(key)) {
                    return entry.getValue();
                }
            }
        }
        return null;
    }

    private AdministrativeAreaSummaryResponse toSummary(AdministrativeArea area) {
        if (area == null) return null;
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

