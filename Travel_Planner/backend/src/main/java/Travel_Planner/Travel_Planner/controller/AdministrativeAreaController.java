package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.response.AdministrativeAreaResponse;
import Travel_Planner.Travel_Planner.dto.response.AdministrativeAreaSearchResultResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceResponse;
import Travel_Planner.Travel_Planner.model.enums.PlaceCategory;
import Travel_Planner.Travel_Planner.service.AdministrativeAreaService;
import Travel_Planner.Travel_Planner.service.PlaceService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/administrative-areas")
public class AdministrativeAreaController {

    private final AdministrativeAreaService administrativeAreaService;
    private final PlaceService placeService;

    public AdministrativeAreaController(AdministrativeAreaService administrativeAreaService,
                                        PlaceService placeService) {
        this.administrativeAreaService = administrativeAreaService;
        this.placeService = placeService;
    }

    /**
     * Retrieve all official province-level units (34 provinces & centrally-governed cities).
     */
    @GetMapping("/provinces")
    public ResponseEntity<List<AdministrativeAreaResponse>> getProvinces() {
        return ResponseEntity.ok(administrativeAreaService.getProvinces());
    }

    /**
     * Retrieve direct child units (communes/wards/special zones) of a province.
     *
     * @param code official code of the parent province (e.g. "01", "79", "48")
     */
    @GetMapping("/{code}/children")
    public ResponseEntity<List<AdministrativeAreaResponse>> getChildren(@PathVariable String code) {
        return ResponseEntity.ok(administrativeAreaService.getChildren(code));
    }

    /**
     * Search administrative areas by name or normalized name.
     * Includes parent province context to disambiguate duplicate commune names (e.g. "Châu Thành").
     *
     * @param query search keyword (accepts unaccented or partial matching)
     * @param limit maximum results to return (default 10, max 50)
     */
    @GetMapping("/search")
    public ResponseEntity<List<AdministrativeAreaSearchResultResponse>> search(
            @RequestParam(name = "q", required = false) String query,
            @RequestParam(name = "limit", defaultValue = "10") int limit
    ) {
        return ResponseEntity.ok(administrativeAreaService.searchAreas(query, limit));
    }

    /**
     * Look up an administrative area by its official code.
     *
     * @param code official administrative code
     */
    @GetMapping("/{code}")
    public ResponseEntity<AdministrativeAreaResponse> getByCode(@PathVariable String code) {
        return ResponseEntity.ok(administrativeAreaService.getByCode(code));
    }

    /**
     * Retrieve Places located in this administrative area (or its child communes/wards if province).
     */
    @GetMapping("/{code}/places")
    public ResponseEntity<Page<PlaceResponse>> getPlacesInArea(
            @PathVariable String code,
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) PlaceCategory category,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "name,asc") String sort
    ) {
        String[] sortParts = sort.split(",");
        String sortProp = sortParts[0];
        Sort.Direction direction = (sortParts.length > 1 && "desc".equalsIgnoreCase(sortParts[1]))
                ? Sort.Direction.DESC
                : Sort.Direction.ASC;

        Pageable pageable = PageRequest.of(Math.max(0, page), Math.min(50, Math.max(1, size)), Sort.by(direction, sortProp));
        return ResponseEntity.ok(placeService.searchPlaces(keyword, category, code, null, null, null, null, pageable));
    }
}

