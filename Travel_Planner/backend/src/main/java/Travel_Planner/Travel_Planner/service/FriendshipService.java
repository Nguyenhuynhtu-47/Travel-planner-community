package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.FriendRequestResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.dto.response.PublicUserSummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.RelationshipContextResponse;
import Travel_Planner.Travel_Planner.model.enums.FriendshipStatus;
import java.util.List;
import java.util.Map;

public interface FriendshipService {
    FriendRequestResponse sendRequest(Integer targetUserId, String actorUsername);
    FriendRequestResponse accept(Long friendshipId, String actorUsername);
    FriendRequestResponse decline(Long friendshipId, String actorUsername);
    void cancel(Long friendshipId, String actorUsername);
    void unfriend(Integer targetUserId, String actorUsername);
    PageResponse<FriendRequestResponse> requests(String direction, int page, int size, String actorUsername);
    PageResponse<PublicUserSummaryResponse> friends(int page, int size, String actorUsername);
    void block(Integer targetUserId, String actorUsername);
    void unblock(Integer targetUserId, String actorUsername);
    PageResponse<PublicUserSummaryResponse> blocks(int page, int size, String actorUsername);
    RelationshipContextResponse relationshipContext(Integer viewerId, Integer targetId);
    boolean canMessage(Integer senderId, Integer recipientId);
    Map<Integer, Boolean> canMessageForPeers(Integer senderId, List<Integer> recipientIds);
}

