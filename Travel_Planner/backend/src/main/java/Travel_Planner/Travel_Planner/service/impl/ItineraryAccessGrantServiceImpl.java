package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.Itinerary;
import Travel_Planner.Travel_Planner.model.ItineraryAccessGrant;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.GrantStatus;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.repository.ItineraryAccessGrantRepository;
import Travel_Planner.Travel_Planner.repository.ItineraryRepository;
import Travel_Planner.Travel_Planner.service.ItineraryAccessGrantService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
public class ItineraryAccessGrantServiceImpl implements ItineraryAccessGrantService {

    private final ItineraryAccessGrantRepository grantRepository;
    private final ItineraryRepository itineraryRepository;

    public ItineraryAccessGrantServiceImpl(ItineraryAccessGrantRepository grantRepository,
                                           ItineraryRepository itineraryRepository) {
        this.grantRepository = grantRepository;
        this.itineraryRepository = itineraryRepository;
    }

    @Override
    @Transactional
    public ItineraryAccessGrant grantAccess(Itinerary itinerary, User grantee, User grantedBy) {
        if (itinerary == null || itinerary.getStatus() == ItineraryStatus.DELETED) {
            throw new BadRequestException("Lịch trình không tồn tại hoặc đã bị xóa");
        }
        if (grantee == null || grantedBy == null) {
            throw new BadRequestException("Thông tin người dùng không hợp lệ");
        }
        if (grantee.getUserId().equals(grantedBy.getUserId())) {
            throw new BadRequestException("Không thể cấp quyền cho chính mình");
        }

        return grantRepository.findByItinerary_ItineraryIdAndGrantee_UserId(itinerary.getItineraryId(), grantee.getUserId())
                .map(existing -> {
                    if (existing.getStatus() != GrantStatus.ACTIVE) {
                        existing.setStatus(GrantStatus.ACTIVE);
                        existing.setRevokedAt(null);
                        return grantRepository.save(existing);
                    }
                    return existing;
                })
                .orElseGet(() -> grantRepository.save(ItineraryAccessGrant.builder()
                        .itinerary(itinerary)
                        .grantee(grantee)
                        .grantedBy(grantedBy)
                        .status(GrantStatus.ACTIVE)
                        .createdAt(LocalDateTime.now())
                        .build()));
    }

    @Override
    @Transactional
    public void revokeAccess(Integer itineraryId, Integer granteeUserId, String currentUsername) {
        if (itineraryId == null || granteeUserId == null) {
            throw new BadRequestException("Tham số không hợp lệ");
        }
        Itinerary itinerary = itineraryRepository.findById(itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa"));

        if (itinerary.getUser() == null || currentUsername == null
                || !itinerary.getUser().getUsername().equals(currentUsername)) {
            throw new ForbiddenException("Chỉ chủ sở hữu mới có quyền thu hồi chia sẻ");
        }

        grantRepository.findByItinerary_ItineraryIdAndGrantee_UserId(itineraryId, granteeUserId)
                .ifPresent(grant -> {
                    if (grant.getStatus() == GrantStatus.ACTIVE) {
                        grant.setStatus(GrantStatus.REVOKED);
                        grant.setRevokedAt(LocalDateTime.now());
                        grantRepository.save(grant);
                    }
                });
    }

    @Override
    @Transactional(readOnly = true)
    public boolean hasActiveGrant(Integer itineraryId, Integer granteeUserId) {
        if (itineraryId == null || granteeUserId == null) {
            return false;
        }
        return grantRepository.existsByItinerary_ItineraryIdAndGrantee_UserIdAndStatus(itineraryId, granteeUserId, GrantStatus.ACTIVE);
    }
}
