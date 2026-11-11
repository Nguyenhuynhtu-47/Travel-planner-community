package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.AdministrativeAreaResponse;
import Travel_Planner.Travel_Planner.dto.response.AdministrativeAreaSearchResultResponse;

import java.util.List;

public interface AdministrativeAreaService {

    /**
     * Retrieve all official province-level units (Provinces and Centrally-run Cities).
     */
    List<AdministrativeAreaResponse> getProvinces();

    /**
     * Retrieve direct child units (communes, wards, special zones) of a parent province.
     *
     * @param parentCode official 2-digit code of the parent province
     * @return list of direct child commune-level units
     */
    List<AdministrativeAreaResponse> getChildren(String parentCode);

    /**
     * Search administrative areas by name with parent context disambiguation.
     *
     * @param query raw search string (supports unaccented and partial matching)
     * @param limit maximum number of results (1 to 50)
     * @return list of matching administrative areas with parent province context
     */
    List<AdministrativeAreaSearchResultResponse> searchAreas(String query, int limit);

    /**
     * Look up an administrative area by its official code.
     *
     * @param code official administrative code
     * @return administrative area detail
     */
    AdministrativeAreaResponse getByCode(String code);

    /**
     * Invalidate in-memory caches.
     */
    void clearCache();
}

