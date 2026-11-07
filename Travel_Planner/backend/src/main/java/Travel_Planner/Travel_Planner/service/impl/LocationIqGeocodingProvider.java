package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.config.MapProperties;
import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;
import Travel_Planner.Travel_Planner.exception.AppException;
import Travel_Planner.Travel_Planner.exception.RateLimitExceededException;
import Travel_Planner.Travel_Planner.service.GeocodingProvider;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.util.UriComponentsBuilder;
import tools.jackson.databind.JsonNode;

import java.net.URI;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

@Component
public class LocationIqGeocodingProvider implements GeocodingProvider {

    private static final Logger logger = LoggerFactory.getLogger(LocationIqGeocodingProvider.class);
    private static final String PROVIDER_NAME = "LOCATION_IQ";

    private final RestClient restClient;
    private final MapProperties mapProperties;

    @Autowired
    public LocationIqGeocodingProvider(RestClient.Builder restClientBuilder, MapProperties mapProperties) {
        this.mapProperties = mapProperties;
        int timeoutMs = mapProperties.getGeocoding().getTimeoutMs();
        if (timeoutMs <= 0) {
            timeoutMs = 3000;
        }

        SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
        requestFactory.setConnectTimeout(Duration.ofMillis(timeoutMs));
        requestFactory.setReadTimeout(Duration.ofMillis(timeoutMs));

        this.restClient = restClientBuilder
                .requestFactory(requestFactory)
                .build();
    }

    public LocationIqGeocodingProvider(RestClient restClient, MapProperties mapProperties) {
        this.restClient = restClient;
        this.mapProperties = mapProperties;
    }

    @Override
    public String getProviderName() {
        return PROVIDER_NAME;
    }

    @Override
    public boolean isConfigured() {
        String apiKey = mapProperties.getGeocoding().getApiKey();
        return apiKey != null && !apiKey.trim().isEmpty();
    }

    @Override
    public List<LocationSearchResultResponse> search(String query, int limit, Double latitude, Double longitude) {
        if (!isConfigured()) {
            logger.debug("LocationIQ API key is not configured. Returning empty search results for query: {}", query);
            return Collections.emptyList();
        }

        String apiKey = mapProperties.getGeocoding().getApiKey().trim();
        String baseUrl = mapProperties.getGeocoding().getBaseUrl();
        if (baseUrl == null || baseUrl.isBlank()) {
            baseUrl = "https://us1.locationiq.com/v1";
        }

        String lang = getPreferredLanguage();

        // 1. Primary Query: Forward Geocoding (/search) for semantic and entity search
        List<LocationSearchResultResponse> results = new ArrayList<>();
        Set<String> seenPlaceIds = new HashSet<>();
        Set<String> seenCoordKeys = new HashSet<>();

        boolean isSpecificOrRegional = isLocalityOrRegionalQuery(query);

        UriComponentsBuilder searchUriBuilder = UriComponentsBuilder.fromUriString(baseUrl)
                .path("/search")
                .queryParam("key", apiKey)
                .queryParam("q", query)
                .queryParam("limit", limit)
                .queryParam("countrycodes", "vn")
                .queryParam("format", "json")
                .queryParam("accept-language", lang)
                .queryParam("addressdetails", 1)
                .queryParam("normalizecity", 1)
                .queryParam("dedupe", 1);

        // Bias viewbox if coordinates provided and query is not a specific region
        if (latitude != null && longitude != null && !isSpecificOrRegional) {
            double delta = 0.15;
            double minLon = Math.max(-180.0, longitude - delta);
            double maxLon = Math.min(180.0, longitude + delta);
            double minLat = Math.max(-90.0, latitude - delta);
            double maxLat = Math.min(90.0, latitude + delta);
            String viewbox = String.format(Locale.ROOT, "%.5f,%.5f,%.5f,%.5f", minLon, minLat, maxLon, maxLat);
            searchUriBuilder.queryParam("viewbox", viewbox);
            searchUriBuilder.queryParam("bounded", 0);
        }

        URI searchUri = searchUriBuilder.build().encode().toUri();
        executeSearchQuery(searchUri, query, results, seenPlaceIds, seenCoordKeys);

        // 2. Supplemental Query: If /search returned 0 results, OR if all /search results are generic literal matches
        // (e.g. query "bánh mì" returned only bare nodes named "bánh mì" or "Banh mi (2026)" without actual bakeries/shops),
        // query /autocomplete to discover actual named venues (e.g. "Bánh Mì Huynh Hoa", "Bánh Mì Tuấn Mập").
        boolean hasOnlyLiteralGenericNames = !results.isEmpty() && results.stream()
                .allMatch(r -> {
                    if (r.getName() == null) return true;
                    String stripped = r.getName().replaceAll("\\s*\\([^)]*\\)", "").trim();
                    return stripped.equalsIgnoreCase(query.trim());
                });

        if (results.isEmpty() || hasOnlyLiteralGenericNames) {
            UriComponentsBuilder autoUriBuilder = UriComponentsBuilder.fromUriString(baseUrl)
                    .path("/autocomplete")
                    .queryParam("key", apiKey)
                    .queryParam("q", query)
                    .queryParam("limit", limit)
                    .queryParam("countrycodes", "vn")
                    .queryParam("format", "json")
                    // LocationIQ Autocomplete only accepts one supported 2-letter language code;
                    // Vietnamese is not currently supported by this endpoint.
                    .queryParam("accept-language", "en");

            if (latitude != null && longitude != null) {
                autoUriBuilder.queryParam("lat", latitude);
                autoUriBuilder.queryParam("lon", longitude);
                if (!isSpecificOrRegional) {
                    double delta = 0.15;
                    double minLon = Math.max(-180.0, longitude - delta);
                    double maxLon = Math.min(180.0, longitude + delta);
                    double minLat = Math.max(-90.0, latitude - delta);
                    double maxLat = Math.min(90.0, latitude + delta);
                    String viewbox = String.format(Locale.ROOT, "%.5f,%.5f,%.5f,%.5f", minLon, minLat, maxLon, maxLat);
                    autoUriBuilder.queryParam("viewbox", viewbox);
                    autoUriBuilder.queryParam("bounded", 0);
                }
            }

            URI autoUri = autoUriBuilder.build().encode().toUri();
            try {
                JsonNode autoResponse = restClient.get()
                        .uri(autoUri)
                        .retrieve()
                        .body(JsonNode.class);

                if (autoResponse != null && autoResponse.isArray()) {
                    for (JsonNode item : autoResponse) {
                        LocationSearchResultResponse parsed = parseLocationItem(item);
                        if (parsed != null) {
                            String coordKey = String.format(Locale.ROOT, "%s:%.3f:%.3f",
                                    parsed.getName().toLowerCase(Locale.ROOT).trim(),
                                    parsed.getLatitude(),
                                    parsed.getLongitude());
                            if (seenPlaceIds.add(parsed.getPlaceId()) && seenCoordKeys.add(coordKey)) {
                                results.add(parsed);
                            }
                        }
                    }
                }
            } catch (Exception ex) {
                logger.debug("LocationIQ autocomplete supplemental query skipped: {}", ex.getMessage());
            }
        }

        return results;
    }

    @Override
    public List<LocationSearchResultResponse> searchInArea(String query, int limit, Double latitude, Double longitude, List<Double> boundingBox, Integer radiusMeters) {
        if (!isConfigured()) {
            return Collections.emptyList();
        }

        String apiKey = mapProperties.getGeocoding().getApiKey().trim();
        String baseUrl = mapProperties.getGeocoding().getBaseUrl();
        if (baseUrl == null || baseUrl.isBlank()) {
            baseUrl = "https://us1.locationiq.com/v1";
        }
        String lang = getPreferredLanguage();

        String viewbox = null;
        double areaMinLat = -90.0, areaMaxLat = 90.0, areaMinLon = -180.0, areaMaxLon = 180.0;
        if (boundingBox != null && boundingBox.size() == 4) {
            areaMinLat = Math.min(boundingBox.get(0), boundingBox.get(1));
            areaMaxLat = Math.max(boundingBox.get(0), boundingBox.get(1));
            areaMinLon = Math.min(boundingBox.get(2), boundingBox.get(3));
            areaMaxLon = Math.max(boundingBox.get(2), boundingBox.get(3));
            viewbox = String.format(Locale.ROOT, "%.5f,%.5f,%.5f,%.5f", areaMinLon, areaMinLat, areaMaxLon, areaMaxLat);
        } else if (latitude != null && longitude != null) {
            int rad = (radiusMeters != null && radiusMeters > 0) ? radiusMeters : 10000;
            double deltaLat = rad / 111000.0;
            double deltaLon = rad / (111000.0 * Math.cos(Math.toRadians(latitude)));
            areaMinLat = latitude - deltaLat;
            areaMaxLat = latitude + deltaLat;
            areaMinLon = longitude - deltaLon;
            areaMaxLon = longitude + deltaLon;
            viewbox = String.format(Locale.ROOT, "%.5f,%.5f,%.5f,%.5f", areaMinLon, areaMinLat, areaMaxLon, areaMaxLat);
        }

        List<LocationSearchResultResponse> results = new ArrayList<>();
        Set<String> seenPlaceIds = new HashSet<>();
        Set<String> seenCoordKeys = new HashSet<>();

        if (viewbox != null) {
            // 1. Forward Geocoding (/search) strictly bounded inside area (bounded=1)
            UriComponentsBuilder searchUriBuilder = UriComponentsBuilder.fromUriString(baseUrl)
                    .path("/search")
                    .queryParam("key", apiKey)
                    .queryParam("q", query)
                    .queryParam("limit", limit)
                    .queryParam("countrycodes", "vn")
                    .queryParam("format", "json")
                    .queryParam("accept-language", lang)
                    .queryParam("addressdetails", 1)
                    .queryParam("normalizecity", 1)
                    .queryParam("dedupe", 1)
                    .queryParam("viewbox", viewbox)
                    .queryParam("bounded", 1);
            executeSearchQuery(searchUriBuilder.build().encode().toUri(), query, results, seenPlaceIds, seenCoordKeys);

            // 2. Autocomplete (/autocomplete) strictly bounded inside area (bounded=1)
            executeAutocompleteInViewbox(baseUrl, apiKey, lang, query, limit, viewbox, results, seenPlaceIds, seenCoordKeys);

            // 3. Root keyword search if results are sparse (< 2) and query contains multiple words
            if (results.size() < 2 && query.contains(" ")) {
                String rootWord = query.split("\\s+")[0].trim();
                if (rootWord.length() >= 3) {
                    executeAutocompleteInViewbox(baseUrl, apiKey, lang, rootWord, limit, viewbox, results, seenPlaceIds, seenCoordKeys);
                    UriComponentsBuilder rootSearchBuilder = UriComponentsBuilder.fromUriString(baseUrl)
                            .path("/search")
                            .queryParam("key", apiKey)
                            .queryParam("q", rootWord)
                            .queryParam("limit", limit)
                            .queryParam("countrycodes", "vn")
                            .queryParam("format", "json")
                            .queryParam("accept-language", lang)
                            .queryParam("addressdetails", 1)
                            .queryParam("normalizecity", 1)
                            .queryParam("dedupe", 1)
                            .queryParam("viewbox", viewbox)
                            .queryParam("bounded", 1);
                    executeSearchQuery(rootSearchBuilder.build().encode().toUri(), rootWord, results, seenPlaceIds, seenCoordKeys);
                }
            }
        }

        // Strict coordinate containment check: never allow places outside the target bounding box
        final double finalMinLat = areaMinLat - 0.02; // ~2.2km tolerance
        final double finalMaxLat = areaMaxLat + 0.02;
        final double finalMinLon = areaMinLon - 0.02;
        final double finalMaxLon = areaMaxLon + 0.02;

        results.removeIf(item -> item == null
                || item.getLatitude() == null || item.getLongitude() == null
                || item.getLatitude() < finalMinLat || item.getLatitude() > finalMaxLat
                || item.getLongitude() < finalMinLon || item.getLongitude() > finalMaxLon);

        return results;
    }

    private void executeAutocompleteInViewbox(String baseUrl, String apiKey, String lang, String query, int limit,
                                              String viewbox, List<LocationSearchResultResponse> results,
                                              Set<String> seenPlaceIds, Set<String> seenCoordKeys) {
        UriComponentsBuilder autoBuilder = UriComponentsBuilder.fromUriString(baseUrl)
                .path("/autocomplete")
                .queryParam("key", apiKey)
                .queryParam("q", query)
                .queryParam("limit", limit)
                .queryParam("countrycodes", "vn")
                .queryParam("format", "json")
                // Keep Autocomplete valid; /search continues to use the configured language.
                .queryParam("accept-language", "en")
                .queryParam("viewbox", viewbox)
                .queryParam("bounded", 1);
        try {
            JsonNode autoResponse = restClient.get()
                    .uri(autoBuilder.build().encode().toUri())
                    .retrieve()
                    .body(JsonNode.class);

            if (autoResponse != null && autoResponse.isArray()) {
                for (JsonNode item : autoResponse) {
                    LocationSearchResultResponse parsed = parseLocationItem(item);
                    if (parsed != null) {
                        String coordKey = String.format(Locale.ROOT, "%s:%.3f:%.3f",
                                parsed.getName().toLowerCase(Locale.ROOT).trim(),
                                parsed.getLatitude(),
                                parsed.getLongitude());
                        if (seenPlaceIds.add(parsed.getPlaceId()) && seenCoordKeys.add(coordKey)) {
                            results.add(parsed);
                        }
                    }
                }
            }
        } catch (Exception ex) {
            logger.debug("LocationIQ autocomplete viewbox search skipped: {}", ex.getMessage());
        }
    }

    private void executeSearchQuery(URI searchUri, String query, List<LocationSearchResultResponse> results,
                                    Set<String> seenPlaceIds, Set<String> seenCoordKeys) {
        try {
            JsonNode response = restClient.get()
                    .uri(searchUri)
                    .retrieve()
                    .body(JsonNode.class);

            if (response != null && response.isArray()) {
                for (JsonNode item : response) {
                    LocationSearchResultResponse parsed = parseLocationItem(item);
                    if (parsed != null) {
                        String coordKey = String.format(Locale.ROOT, "%s:%.3f:%.3f",
                                parsed.getName().toLowerCase(Locale.ROOT).trim(),
                                parsed.getLatitude(),
                                parsed.getLongitude());
                        if (seenPlaceIds.add(parsed.getPlaceId()) && seenCoordKeys.add(coordKey)) {
                            results.add(parsed);
                        }
                    }
                }
            }
        } catch (RestClientResponseException ex) {
            if (ex.getStatusCode() == HttpStatus.TOO_MANY_REQUESTS) {
                logger.warn("LocationIQ upstream rate limit exceeded (HTTP 429) for search: {}", query);
                throw new RateLimitExceededException("Dịch vụ tìm kiếm vị trí tạm thời đạt giới hạn lượt gọi. Vui lòng thử lại sau.");
            }
            if (ex.getStatusCode().is5xxServerError()) {
                logger.warn("LocationIQ upstream server error HTTP {}: {}", ex.getStatusCode().value(), ex.getStatusText());
                throw new AppException("Dịch vụ định vị gặp sự cố máy chủ. Vui lòng thử lại sau.", HttpStatus.BAD_GATEWAY);
            }
            logger.debug("LocationIQ /search returned HTTP {} for query: {}", ex.getStatusCode().value(), query);
        } catch (ResourceAccessException ex) {
            logger.warn("LocationIQ search timeout or connection error for query: {}", query);
            throw new AppException("Dịch vụ tìm kiếm vị trí không phản hồi kịp thời (timeout). Vui lòng thử lại sau.", HttpStatus.GATEWAY_TIMEOUT);
        }
    }

    private boolean isLocalityOrRegionalQuery(String query) {
        if (query == null) return false;
        String lower = query.toLowerCase(Locale.ROOT);
        if (lower.contains("ở ") || lower.contains("o ") || lower.contains("tại ") || lower.contains("tai ")
                || lower.contains("gần ") || lower.contains("gan ") || lower.contains(",")) {
            return true;
        }
        // If query does not contain service words and is short, it's a specific city or landmark
        boolean hasService = lower.contains("quán") || lower.contains("quan") || lower.contains("cà phê")
                || lower.contains("ca phe") || lower.contains("nhà hàng") || lower.contains("nha hang")
                || lower.contains("khách sạn") || lower.contains("khach san") || lower.contains("tiệm bánh")
                || lower.contains("tiem banh") || lower.contains("nhà thuốc") || lower.contains("nha thuoc")
                || lower.contains("siêu thị") || lower.contains("sieu thi")
                || lower.contains("bánh mì") || lower.contains("banh mi")
                || lower.contains("cơm") || lower.contains("com")
                || lower.contains("phở") || lower.contains("pho")
                || lower.contains("bún") || lower.contains("bun")
                || lower.contains("lẩu") || lower.contains("lau")
                || lower.contains("nem") || lower.contains("hủ tiếu") || lower.contains("hu tieu")
                || lower.contains("trà sữa") || lower.contains("tra sua")
                || lower.contains("coffee") || lower.contains("cafe") || lower.contains("bakery");
        return !hasService && lower.split("\\s+").length <= 4;
    }

    @Override
    public List<LocationSearchResultResponse> searchNearby(double latitude, double longitude, String category,
                                                            int radiusMeters, int limit) {
        if (!isConfigured() || !mapProperties.getGeocoding().isNearbyEnabled()) {
            throw new AppException("Tìm địa điểm quanh đây hiện chưa được bật.", HttpStatus.SERVICE_UNAVAILABLE);
        }
        String tag = switch (category) {
            case "ATTRACTION" -> "tourism:*,historic:*,leisure:park";
            case "FOOD" -> "amenity:restaurant,amenity:fast_food,amenity:food_court";
            case "CAFE" -> "amenity:cafe";
            case "STAY" -> "tourism:hotel,tourism:guest_house,tourism:hostel";
            default -> "all";
        };
        String baseUrl = mapProperties.getGeocoding().getBaseUrl();
        if (baseUrl == null || baseUrl.isBlank()) baseUrl = "https://us1.locationiq.com/v1";
        URI uri = UriComponentsBuilder.fromUriString(baseUrl).path("/nearby")
                .queryParam("key", mapProperties.getGeocoding().getApiKey().trim())
                .queryParam("lat", latitude).queryParam("lon", longitude)
                .queryParam("tag", tag).queryParam("radius", radiusMeters)
                .queryParam("limit", limit).queryParam("dedupe", 1).queryParam("format", "json")
                .queryParam("accept-language", getPreferredLanguage()).build().encode().toUri();
        try {
            JsonNode response = restClient.get().uri(uri).retrieve().body(JsonNode.class);
            if (response == null || !response.isArray()) return Collections.emptyList();
            List<LocationSearchResultResponse> results = new ArrayList<>();
            for (JsonNode item : response) {
                LocationSearchResultResponse parsed = parseLocationItem(item);
                if (parsed != null) results.add(parsed);
            }
            return results;
        } catch (RestClientResponseException ex) {
            if (ex.getStatusCode() == HttpStatus.NOT_FOUND) return Collections.emptyList();
            if (ex.getStatusCode() == HttpStatus.TOO_MANY_REQUESTS) {
                throw new RateLimitExceededException("Dịch vụ gợi ý địa điểm tạm thời đạt giới hạn lượt gọi.");
            }
            throw new AppException("Dịch vụ gợi ý địa điểm tạm thời không khả dụng.", HttpStatus.BAD_GATEWAY);
        } catch (ResourceAccessException ex) {
            throw new AppException("Dịch vụ gợi ý địa điểm không phản hồi kịp thời.", HttpStatus.GATEWAY_TIMEOUT);
        }
    }

    @Override
    public LocationSearchResultResponse reverseGeocode(double latitude, double longitude) {
        if (!isConfigured()) {
            logger.debug("LocationIQ API key is not configured. Returning null for reverse geocode.");
            return null;
        }

        String apiKey = mapProperties.getGeocoding().getApiKey().trim();
        String baseUrl = mapProperties.getGeocoding().getBaseUrl();
        if (baseUrl == null || baseUrl.isBlank()) {
            baseUrl = "https://us1.locationiq.com/v1";
        }

        URI uri = UriComponentsBuilder.fromUriString(baseUrl)
                .path("/reverse")
                .queryParam("key", apiKey)
                .queryParam("lat", latitude)
                .queryParam("lon", longitude)
                .queryParam("format", "json")
                .queryParam("accept-language", getPreferredLanguage())
                .build().encode().toUri();

        try {
            JsonNode response = restClient.get()
                    .uri(uri)
                    .retrieve()
                    .body(JsonNode.class);

            if (response == null || response.isMissingNode() || response.isNull()) {
                return null;
            }

            return parseLocationItem(response);

        } catch (RestClientResponseException ex) {
            // LocationIQ returns 404 when coordinates do not resolve to an address (genuine unmapped coordinate)
            if (ex.getStatusCode() == HttpStatus.NOT_FOUND) {
                logger.debug("LocationIQ returned 404 (no address at coordinates {}, {})", latitude, longitude);
                return null;
            }
            if (ex.getStatusCode() == HttpStatus.TOO_MANY_REQUESTS) {
                logger.warn("LocationIQ upstream rate limit exceeded (HTTP 429) for reverse geocode ({}, {})", latitude, longitude);
                throw new RateLimitExceededException("Dịch vụ định vị tạm thời đạt giới hạn lượt gọi. Vui lòng thử lại sau.");
            }
            if (ex.getStatusCode().is5xxServerError()) {
                logger.warn("LocationIQ upstream server error HTTP {}: {}", ex.getStatusCode().value(), ex.getStatusText());
                throw new AppException("Dịch vụ định vị gặp sự cố máy chủ. Vui lòng thử lại sau.", HttpStatus.BAD_GATEWAY);
            }
            logger.warn("LocationIQ upstream error HTTP {}: {}", ex.getStatusCode().value(), ex.getStatusText());
            return null;
        } catch (ResourceAccessException ex) {
            logger.warn("LocationIQ upstream timeout or connection error for reverse geocode ({}, {})", latitude, longitude);
            throw new AppException("Dịch vụ định vị không phản hồi kịp thời (timeout). Vui lòng thử lại sau.", HttpStatus.GATEWAY_TIMEOUT);
        } catch (AppException ex) {
            throw ex;
        } catch (Exception ex) {
            logger.warn("Unexpected error calling LocationIQ reverse geocode: {}", ex.getMessage());
            throw new AppException("Không thể xử lý yêu cầu định vị tọa độ.", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    private String getPreferredLanguage() {
        String lang = mapProperties.getGeocoding().getLanguage();
        if (lang == null || lang.isBlank()) {
            return "vi";
        }
        return lang.trim();
    }

    private LocationSearchResultResponse parseLocationItem(JsonNode node) {
        if (node == null || node.isMissingNode()) {
            return null;
        }

        String osmType = node.path("osm_type").asText(null);
        String osmId = node.path("osm_id").asText(null);
        String placeId = node.path("place_id").asText(null);

        String effectivePlaceId;
        if (osmType != null && !osmType.isBlank() && osmId != null && !osmId.isBlank()) {
            effectivePlaceId = "osm_" + osmType.trim() + "_" + osmId.trim();
        } else if (placeId != null && !placeId.isBlank()) {
            effectivePlaceId = placeId.trim();
        } else {
            effectivePlaceId = "loc_" + System.currentTimeMillis();
        }

        String displayName = node.path("display_name").asText(null);
        String displayPlace = node.path("display_place").asText(null);
        JsonNode addressNode = node.path("address");
        String nameVi = addressNode.path("name:vi").asText(null);
        String addressCity = addressNode.path("city").asText(null);
        String addressTown = addressNode.path("town").asText(null);
        String addressVillage = addressNode.path("village").asText(null);
        String addressName = addressNode.path("name").asText(null);

        String name;
        if (nameVi != null && !nameVi.isBlank()) {
            name = nameVi.trim();
        } else if (displayPlace != null && !displayPlace.isBlank()) {
            name = displayPlace.trim();
        } else if (addressCity != null && !addressCity.isBlank() && "place".equalsIgnoreCase(node.path("class").asText())) {
            name = addressCity.trim();
        } else if (addressTown != null && !addressTown.isBlank() && "place".equalsIgnoreCase(node.path("class").asText())) {
            name = addressTown.trim();
        } else if (addressVillage != null && !addressVillage.isBlank() && "place".equalsIgnoreCase(node.path("class").asText())) {
            name = addressVillage.trim();
        } else if (addressName != null && !addressName.isBlank()) {
            name = addressName.trim();
        } else if (displayName != null && !displayName.isBlank()) {
            name = displayName.split(",")[0].trim();
        } else {
            name = "Vị trí đã chọn";
        }

        String formattedAddress = displayName != null && !displayName.isBlank() ? displayName.trim() : name;

        double lat = parseCoordinate(node.path("lat"));
        double lon = parseCoordinate(node.path("lon"));
        if (!Double.isFinite(lat) || !Double.isFinite(lon)
                || lat < -90.0 || lat > 90.0 || lon < -180.0 || lon > 180.0) {
            return null;
        }

        String type = node.path("type").asText(null);
        String clazz = node.path("class").asText(null);
        String category;
        if (type != null && !type.isBlank() && !"yes".equalsIgnoreCase(type.trim())) {
            category = type.trim();
        } else if (clazz != null && !clazz.isBlank()) {
            category = clazz.trim();
        } else {
            category = "place";
        }

        Double importance = null;
        if (node.has("importance")) {
            double imp = parseCoordinate(node.path("importance"));
            if (!Double.isNaN(imp)) {
                importance = imp;
            }
        }

        List<Double> boundingBox = null;
        if (node.has("boundingbox") && node.path("boundingbox").isArray() && node.path("boundingbox").size() == 4) {
            boundingBox = new ArrayList<>(4);
            for (JsonNode b : node.path("boundingbox")) {
                double val = parseCoordinate(b);
                if (!Double.isNaN(val)) {
                    boundingBox.add(val);
                }
            }
            if (boundingBox.size() != 4) {
                boundingBox = null;
            }
        }

        return LocationSearchResultResponse.builder()
                .placeId(effectivePlaceId)
                .name(name)
                .formattedAddress(formattedAddress)
                .latitude(lat)
                .longitude(lon)
                .category(category)
                .type(type != null ? type : category)
                .importance(importance)
                .boundingBox(boundingBox)
                .provider(PROVIDER_NAME)
                .build();
    }

    private double parseCoordinate(JsonNode value) {
        if (value == null || value.isMissingNode() || value.isNull()) {
            return Double.NaN;
        }
        try {
            return Double.parseDouble(value.asText());
        } catch (NumberFormatException ex) {
            return Double.NaN;
        }
    }
}
