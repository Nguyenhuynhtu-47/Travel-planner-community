package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.response.PublicProfileResponse;
import Travel_Planner.Travel_Planner.dto.response.RelationshipContextResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.Follow;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.model.enums.ConversationStatus;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.service.FriendshipService;
import Travel_Planner.Travel_Planner.service.SocialNotificationService;
import Travel_Planner.Travel_Planner.service.impl.PublicUserServiceImpl;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class PublicUserServiceTest {
    @Test
    void userSearchReturnsOnlyPublicFieldsAndBatchedRelationshipActions() {
        UserRepository users = mock(UserRepository.class);
        FriendshipService friendships = mock(FriendshipService.class);
        User viewer = User.builder().userId(1).username("viewer-login")
                .status(UserStatus.ACTIVE).build();
        User target = User.builder().userId(2).username("private-login")
                .handle("wanderer").fullName("Wanderer Name").avatar("avatar.png")
                .email("private@example.com").status(UserStatus.ACTIVE).build();
        when(users.findByUsername("viewer-login")).thenReturn(Optional.of(viewer));
        when(users.searchActiveUsersVisibleTo("wan%", "wan", 1, PageRequest.of(0, 20)))
                .thenReturn(new PageImpl<>(List.of(target), PageRequest.of(0, 20), 1));
        when(friendships.relationshipContexts(1, List.of(2))).thenReturn(Map.of(2,
                RelationshipContextResponse.builder().friendshipStatus("PENDING")
                        .friendshipId(42L).friendRequestDirection("sent")
                        .canMessage(false).canSendFriendRequest(false).build()));
        PublicUserServiceImpl service = new PublicUserServiceImpl(users, mock(FollowRepository.class),
                mock(ItineraryRepository.class), mock(RatingRepository.class), friendships);

        var response = service.searchUsers("  @Wan  ", 0, 20, "viewer-login");

        assertEquals(1, response.getTotalElements());
        assertEquals("wanderer", response.getContent().get(0).getHandle());
        assertEquals("Wanderer Name", response.getContent().get(0).getFullName());
        assertEquals("sent", response.getContent().get(0).getFriendRequestDirection());
        assertEquals(42L, response.getContent().get(0).getFriendshipId());
        String json = new ObjectMapper().valueToTree(response).toString();
        assertFalse(json.contains("private-login"));
        assertFalse(json.contains("private@example.com"));
        verify(friendships).relationshipContexts(1, List.of(2));
    }

    @Test
    void userSearchRequiresActiveViewerAndAtLeastTwoSearchCharacters() {
        UserRepository users = mock(UserRepository.class);
        PublicUserServiceImpl service = new PublicUserServiceImpl(users, mock(FollowRepository.class),
                mock(ItineraryRepository.class), mock(RatingRepository.class), mock(FriendshipService.class));
        assertThrows(UnauthorizedException.class, () -> service.searchUsers("ab", 0, 20, null));
        User viewer = User.builder().userId(1).username("viewer").status(UserStatus.ACTIVE).build();
        when(users.findByUsername("viewer")).thenReturn(Optional.of(viewer));
        assertThrows(BadRequestException.class, () -> service.searchUsers("a", 0, 20, "viewer"));
        verify(users, never()).searchActiveUsers(anyString(), anyString(), any());
    }

    @Test
    void publicProfileDoesNotSerializePrivateAccountFields() throws Exception {
        UserRepository users = mock(UserRepository.class);
        FollowRepository follows = mock(FollowRepository.class);
        User target = User.builder().userId(7).username("traveler").fullName("Traveler")
                .email("private@example.com").phone("123").address("Private address")
                .role(Role.ADMIN).status(UserStatus.ACTIVE).build();
        when(users.findById(7)).thenReturn(Optional.of(target));
        when(follows.countByFollowing_UserId(7)).thenReturn(4L);
        when(follows.countByFollower_UserId(7)).thenReturn(2L);
        PublicUserServiceImpl service = new PublicUserServiceImpl(users, follows,
                mock(ItineraryRepository.class), mock(RatingRepository.class));

        PublicProfileResponse response = service.getProfile(7, null);
        String json = new ObjectMapper().writeValueAsString(response);
        assertTrue(json.contains("\"isFollowing\":false"));
        assertTrue(json.contains("\"followerCount\":4"));
        assertFalse(json.contains("private@example.com"));
        assertFalse(json.contains("123"));
        assertFalse(json.contains("Private address"));
        assertFalse(json.contains("ADMIN"));
    }

    @Test
    void profileCanContinueAcceptedConversationEvenWhenNewChatsAreNotAllowed() {
        UserRepository users = mock(UserRepository.class);
        FollowRepository follows = mock(FollowRepository.class);
        FriendshipService friendships = mock(FriendshipService.class);
        ConversationRepository conversations = mock(ConversationRepository.class);
        User viewer = User.builder().userId(1).username("viewer").status(UserStatus.ACTIVE).build();
        User target = User.builder().userId(7).username("target").status(UserStatus.ACTIVE).build();
        when(users.findByUsername("viewer")).thenReturn(Optional.of(viewer));
        when(users.findById(7)).thenReturn(Optional.of(target));
        when(friendships.relationshipContext(1, 7)).thenReturn(RelationshipContextResponse.builder()
                .canMessage(false).canSendFriendRequest(false).build());
        when(conversations.findAcceptedPeerIds(1, List.of(7), ConversationStatus.ACCEPTED)).thenReturn(List.of(7));
        when(friendships.canContinueConversation(1, 7)).thenReturn(true);
        PublicUserServiceImpl service = new PublicUserServiceImpl(users, follows,
                mock(ItineraryRepository.class), mock(RatingRepository.class), friendships, conversations);

        PublicProfileResponse profile = service.getProfile(7, "viewer");

        assertFalse(profile.getCanMessage());
        assertTrue(profile.getCanContinueConversation());
    }

    @Test
    void userCannotFollowThemself() {
        UserRepository users = mock(UserRepository.class);
        User actor = User.builder().userId(3).username("same").status(UserStatus.ACTIVE).build();
        when(users.findByUsername("same")).thenReturn(Optional.of(actor));
        PublicUserServiceImpl service = new PublicUserServiceImpl(users, mock(FollowRepository.class),
                mock(ItineraryRepository.class), mock(RatingRepository.class));
        assertThrows(BadRequestException.class, () -> service.follow(3, "same"));
        verify(users, never()).findByUserIdForUpdate(any());
    }

    @Test
    void repeatedFollowDoesNotCreateDuplicateRelation() {
        UserRepository users = mock(UserRepository.class);
        FollowRepository follows = mock(FollowRepository.class);
        User actor = User.builder().userId(3).username("actor").status(UserStatus.ACTIVE).build();
        User target = User.builder().userId(7).username("target").status(UserStatus.ACTIVE).build();
        when(users.findByUsername("actor")).thenReturn(Optional.of(actor));
        when(users.findByUserIdForUpdate(7)).thenReturn(Optional.of(target));
        when(follows.existsByFollower_UserIdAndFollowing_UserId(3, 7)).thenReturn(true);
        PublicUserServiceImpl service = new PublicUserServiceImpl(users, follows,
                mock(ItineraryRepository.class), mock(RatingRepository.class));

        service.follow(7, "actor");

        verify(follows, never()).save(any(Follow.class));
    }

    @Test
    void firstFollowPublishesOnceAndRepeatedFollowDoesNotPublishAgain() {
        UserRepository users = mock(UserRepository.class);
        FollowRepository follows = mock(FollowRepository.class);
        SocialNotificationService socialNotifications = mock(SocialNotificationService.class);
        User actor = User.builder().userId(3).username("actor").status(UserStatus.ACTIVE).build();
        User target = User.builder().userId(7).username("target").status(UserStatus.ACTIVE).build();
        when(users.findByUsername("actor")).thenReturn(Optional.of(actor));
        when(users.findByUserIdForUpdate(7)).thenReturn(Optional.of(target));
        when(follows.existsByFollower_UserIdAndFollowing_UserId(3, 7)).thenReturn(false, true);
        when(follows.save(any(Follow.class))).thenAnswer(invocation -> invocation.getArgument(0));
        PublicUserServiceImpl service = new PublicUserServiceImpl(users, follows,
                mock(ItineraryRepository.class), mock(RatingRepository.class), mock(FriendshipService.class),
                mock(ConversationRepository.class), socialNotifications);

        service.follow(7, "actor");
        service.follow(7, "actor");

        verify(follows, times(1)).save(any(Follow.class));
        verify(socialNotifications, times(1)).followed(any(Follow.class));
    }

    @Test
    void notificationFailureIsNotMistakenForDuplicateFollow() {
        UserRepository users = mock(UserRepository.class);
        FollowRepository follows = mock(FollowRepository.class);
        SocialNotificationService socialNotifications = mock(SocialNotificationService.class);
        User actor = User.builder().userId(3).username("actor").status(UserStatus.ACTIVE).build();
        User target = User.builder().userId(7).username("target").status(UserStatus.ACTIVE).build();
        when(users.findByUsername("actor")).thenReturn(Optional.of(actor));
        when(users.findByUserIdForUpdate(7)).thenReturn(Optional.of(target));
        when(follows.existsByFollower_UserIdAndFollowing_UserId(3, 7)).thenReturn(false);
        when(follows.save(any(Follow.class))).thenAnswer(invocation -> invocation.getArgument(0));
        doThrow(new org.springframework.dao.DataIntegrityViolationException("notification write failed"))
                .when(socialNotifications).followed(any(Follow.class));
        PublicUserServiceImpl service = new PublicUserServiceImpl(users, follows,
                mock(ItineraryRepository.class), mock(RatingRepository.class), mock(FriendshipService.class),
                mock(ConversationRepository.class), socialNotifications);

        assertThrows(org.springframework.dao.DataIntegrityViolationException.class,
                () -> service.follow(7, "actor"));
        verify(follows).save(any(Follow.class));
    }
}
