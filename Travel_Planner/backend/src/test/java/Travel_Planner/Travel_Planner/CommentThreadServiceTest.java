package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.CreateCommentRequest;
import Travel_Planner.Travel_Planner.dto.response.CommentResponse;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.service.impl.CommentServiceImpl;
import org.junit.jupiter.api.Test;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

class CommentThreadServiceTest {
    @Test
    void replyStoresImmediateParentAndResolvedRoot() {
        CommentRepository comments = mock(CommentRepository.class);
        ItineraryRepository itineraries = mock(ItineraryRepository.class);
        ActivityRepository activities = mock(ActivityRepository.class);
        UserRepository users = mock(UserRepository.class);
        CommentServiceImpl service = new CommentServiceImpl(comments, itineraries, activities, users);

        User owner = user(1, "owner");
        User author = user(2, "author");
        Itinerary itinerary = itinerary(owner);
        Comment root = comment(100, owner, itinerary, null, null);
        Comment reply = comment(101, author, itinerary, root, root);
        when(comments.findById(101)).thenReturn(Optional.of(reply));
        when(itineraries.findByIdWithUser(10)).thenReturn(Optional.of(itinerary));
        when(itineraries.existsById(10)).thenReturn(true);
        when(users.findByUsername("author")).thenReturn(Optional.of(author));
        when(comments.save(any(Comment.class))).thenAnswer(invocation -> invocation.getArgument(0));

        CreateCommentRequest request = new CreateCommentRequest();
        request.setContent("Trả lời sâu hơn");
        CommentResponse response = service.createReply(101, request, "author");

        verify(comments).save(argThat(saved -> saved.getParentComment() == reply
                && saved.getRootComment() == root && saved.getItinerary() == itinerary
                && saved.getActivity() == null && "Trả lời sâu hơn".equals(saved.getContent())));
        assertEquals(100, response.getRootCommentId());
        assertEquals(101, response.getParentCommentId());
        verify(itineraries).incrementCommentCount(10);
    }

    @Test
    void privateItineraryCommentsAreNotReadableByActivityId() {
        CommentRepository comments = mock(CommentRepository.class);
        ItineraryRepository itineraries = mock(ItineraryRepository.class);
        ActivityRepository activities = mock(ActivityRepository.class);
        UserRepository users = mock(UserRepository.class);
        CommentServiceImpl service = new CommentServiceImpl(comments, itineraries, activities, users);
        User owner = user(1, "owner");
        Itinerary itinerary = itinerary(owner);
        itinerary.setVisibility(Visibility.PRIVATE);
        Activity activity = mock(Activity.class);
        ItineraryDay day = mock(ItineraryDay.class);
        when(activities.findById(77)).thenReturn(Optional.of(activity));
        when(activities.existsById(77)).thenReturn(true);
        when(activity.getActivityId()).thenReturn(77);
        when(activity.getItineraryDay()).thenReturn(day);
        when(day.getItinerary()).thenReturn(itinerary);
        when(itineraries.findByIdWithUser(10)).thenReturn(Optional.of(itinerary));
        when(itineraries.existsById(10)).thenReturn(true);

        assertThrows(ResourceNotFoundException.class, () -> service.getActivityComments(77, 0, 10));
        verify(comments, never()).pageActivityRoots(any(), any(), any(), any());
    }

    @Test
    void activityCommentPageIsScopedToRequestedActivity() {
        CommentRepository comments = mock(CommentRepository.class);
        ItineraryRepository itineraries = mock(ItineraryRepository.class);
        ActivityRepository activities = mock(ActivityRepository.class);
        UserRepository users = mock(UserRepository.class);
        CommentServiceImpl service = new CommentServiceImpl(comments, itineraries, activities, users);
        Itinerary itinerary = itinerary(user(1, "owner"));
        Activity activity = mock(Activity.class);
        ItineraryDay day = mock(ItineraryDay.class);
        when(activities.findById(77)).thenReturn(Optional.of(activity));
        when(activity.getActivityId()).thenReturn(77);
        when(activity.getItineraryDay()).thenReturn(day);
        when(day.getItinerary()).thenReturn(itinerary);
        when(itineraries.findByIdWithUser(10)).thenReturn(Optional.of(itinerary));
        when(comments.pageActivityRoots(eq(77), eq(CommentStatus.ACTIVE),
                eq(CommentStatus.DELETED), any(Pageable.class))).thenReturn(Page.empty());

        service.getActivityComments(77, 0, 10);

        verify(comments).pageActivityRoots(eq(77), eq(CommentStatus.ACTIVE),
                eq(CommentStatus.DELETED), any(Pageable.class));
        verify(comments, never()).pageActivityRoots(eq(78), any(), any(), any());
    }

    @Test
    void activityCommentStoresBothTargetReferencesWithoutIncrementingItineraryCounter() {
        CommentRepository comments = mock(CommentRepository.class);
        ItineraryRepository itineraries = mock(ItineraryRepository.class);
        ActivityRepository activities = mock(ActivityRepository.class);
        UserRepository users = mock(UserRepository.class);
        CommentServiceImpl service = new CommentServiceImpl(comments, itineraries, activities, users);
        User owner = user(1, "owner"); User author = user(2, "author");
        Itinerary itinerary = itinerary(owner);
        Activity activity = mock(Activity.class); ItineraryDay day = mock(ItineraryDay.class);
        when(activities.findById(77)).thenReturn(Optional.of(activity));
        when(activities.existsById(77)).thenReturn(true);
        when(activity.getActivityId()).thenReturn(77); when(activity.getItineraryDay()).thenReturn(day);
        when(day.getItinerary()).thenReturn(itinerary);
        when(itineraries.findByIdWithUser(10)).thenReturn(Optional.of(itinerary));
        when(itineraries.existsById(10)).thenReturn(true);
        when(users.findByUsername("author")).thenReturn(Optional.of(author));
        when(comments.saveAndFlush(any(Comment.class))).thenAnswer(invocation -> {
            Comment saved = invocation.getArgument(0); saved.setCommentId(200); return saved;
        });
        when(comments.save(any(Comment.class))).thenAnswer(invocation -> invocation.getArgument(0));
        CreateCommentRequest request = new CreateCommentRequest(); request.setContent("Hoạt động rất vui");

        CommentResponse response = service.createActivityComment(77, request, "author");

        verify(comments).save(argThat(saved -> saved.getActivity() == activity && saved.getItinerary() == itinerary
                && saved.getParentComment() == null && saved.getRootComment() == saved));
        verify(itineraries, never()).incrementCommentCount(any());
        assertEquals("ACTIVITY", response.getTargetType());
        assertEquals(77, response.getTargetId());
    }

    @Test
    void loadingReplyPageUsesResolvedRootAndNotTheImmediateReplyId() {
        CommentRepository comments = mock(CommentRepository.class);
        ItineraryRepository itineraries = mock(ItineraryRepository.class);
        ActivityRepository activities = mock(ActivityRepository.class);
        UserRepository users = mock(UserRepository.class);
        CommentServiceImpl service = new CommentServiceImpl(comments, itineraries, activities, users);
        User owner = user(1, "owner"); Itinerary itinerary = itinerary(owner);
        Comment root = comment(100, owner, itinerary, null, null); root.setRootComment(root);
        Comment reply = comment(101, owner, itinerary, root, root);
        when(comments.findById(101)).thenReturn(Optional.of(reply));
        when(itineraries.findByIdWithUser(10)).thenReturn(Optional.of(itinerary));
        when(itineraries.existsById(10)).thenReturn(true);
        when(comments.pageThreadReplies(eq(100), eq(CommentStatus.ACTIVE), eq(CommentStatus.DELETED), any(Pageable.class)))
                .thenReturn(Page.empty());

        service.getReplies(101, 0, 10);

        verify(comments).pageThreadReplies(eq(100), eq(CommentStatus.ACTIVE), eq(CommentStatus.DELETED), any(Pageable.class));
    }

    @Test
    void legacyRootWithoutRootIdRemainsReadableAndUsesItsOwnId() {
        CommentRepository comments = mock(CommentRepository.class);
        ItineraryRepository itineraries = mock(ItineraryRepository.class);
        ActivityRepository activities = mock(ActivityRepository.class);
        UserRepository users = mock(UserRepository.class);
        CommentServiceImpl service = new CommentServiceImpl(comments, itineraries, activities, users);
        User owner = user(1, "owner");
        Itinerary itinerary = itinerary(owner);
        Comment legacyRoot = comment(100, owner, itinerary, null, null);
        when(itineraries.findByIdWithUser(10)).thenReturn(Optional.of(itinerary));
        when(comments.pageItineraryRoots(eq(10), eq(CommentStatus.ACTIVE), eq(CommentStatus.DELETED), any(Pageable.class)))
                .thenReturn(new org.springframework.data.domain.PageImpl<>(java.util.List.of(legacyRoot)));
        when(comments.countActiveRepliesByRootIds(java.util.List.of(100), CommentStatus.ACTIVE))
                .thenReturn(java.util.List.of());

        CommentResponse response = service.getComments(10, 0, 10).getContent().getFirst();

        assertEquals(100, response.getCommentId());
        assertEquals(100, response.getRootCommentId());
        assertNull(response.getParentCommentId());
    }

    @Test
    void replyToLegacyActivityCommentWithNullItineraryPersistsBothReferences() {
        CommentRepository comments = mock(CommentRepository.class);
        ItineraryRepository itineraries = mock(ItineraryRepository.class);
        ActivityRepository activities = mock(ActivityRepository.class);
        UserRepository users = mock(UserRepository.class);
        CommentServiceImpl service = new CommentServiceImpl(comments, itineraries, activities, users);
        User owner = user(1, "owner");
        User author = user(2, "author");
        Itinerary itinerary = itinerary(owner);
        ItineraryDay day = mock(ItineraryDay.class);
        Activity activity = mock(Activity.class);
        Comment legacyActivityRoot = comment(300, owner, null, null, null);
        legacyActivityRoot.setActivity(activity);
        when(comments.findById(300)).thenReturn(Optional.of(legacyActivityRoot));
        when(activities.existsById(77)).thenReturn(true);
        when(activity.getActivityId()).thenReturn(77);
        when(activity.getItineraryDay()).thenReturn(day);
        when(day.getItinerary()).thenReturn(itinerary);
        when(itineraries.existsById(10)).thenReturn(true);
        when(itineraries.findByIdWithUser(10)).thenReturn(Optional.of(itinerary));
        when(users.findByUsername("author")).thenReturn(Optional.of(author));
        when(comments.save(any(Comment.class))).thenAnswer(invocation -> invocation.getArgument(0));
        CreateCommentRequest request = new CreateCommentRequest();
        request.setContent("Trả lời bình luận cũ");

        CommentResponse response = service.createReply(300, request, "author");

        verify(comments).save(argThat(saved -> saved.getParentComment() == legacyActivityRoot
                && saved.getRootComment() == legacyActivityRoot
                && saved.getActivity() == activity && saved.getItinerary() == itinerary));
        assertEquals(300, response.getRootCommentId());
        verify(itineraries, never()).incrementCommentCount(any());
    }

    private User user(int id, String username) {
        return User.builder().userId(id).username(username).fullName(username).role(Role.USER).status(UserStatus.ACTIVE).build();
    }
    private Itinerary itinerary(User owner) {
        Itinerary itinerary = Itinerary.builder().itineraryId(10).user(owner).visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE).commentCount(0).build();
        return itinerary;
    }
    private Comment comment(int id, User author, Itinerary itinerary, Comment parent, Comment root) {
        Comment comment = new Comment(); comment.setCommentId(id); comment.setUser(author); comment.setItinerary(itinerary);
        comment.setParentComment(parent); comment.setRootComment(root); comment.setStatus(CommentStatus.ACTIVE); comment.setContent("text");
        return comment;
    }
}
