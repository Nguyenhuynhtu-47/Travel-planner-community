import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/messaging/data/messaging_realtime_client.dart';
import 'package:mobile/features/messaging/data/messaging_date_time.dart';
import 'package:mobile/features/messaging/data/messaging_repository.dart';
import 'package:mobile/features/messaging/data/models/chat_event.dart';
import 'package:mobile/features/messaging/data/models/chat_message.dart';
import 'package:mobile/features/messaging/data/models/conversation_summary.dart';
import 'package:mobile/features/explore/data/models/page_result.dart';
import 'package:mobile/features/messaging/presentation/screens/chat_screen.dart';
import 'package:mobile/features/profile/data/models/public_user_summary.dart';

class _AuthenticatedNotifier extends AuthNotifier {
  String? avatar;

  _AuthenticatedNotifier({this.avatar});

  @override
  bool get isAuthenticated => true;

  @override
  String? get token => 'test-token';

  @override
  Map<String, dynamic>? get currentUser => {
    'userId': 1,
    'fullName': 'Người dùng hiện tại',
    'avatar': ?avatar,
  };
}

class _ConnectedRealtimeClient extends MessagingRealtimeClient {
  @override
  Stream<ChatEvent> get events => const Stream<ChatEvent>.empty();

  @override
  Stream<RealtimeStatus> get statuses => const Stream<RealtimeStatus>.empty();

  @override
  RealtimeStatus get currentStatus => RealtimeStatus.connected;

  @override
  void connect(String token, String accountKey) {}

  @override
  Future<void> dispose() async {}
}

class _ChatRepository extends MessagingRepository {
  final List<ChatMessage> messagesToReturn;
  final Set<int> blockedUserIds;
  int blockCalls = 0;
  int unblockCalls = 0;
  int sendCalls = 0;
  int markReadCalls = 0;
  int acceptCalls = 0;
  bool recipientVisibleOnSend = true;
  String conversationStatusOnSend = 'ACCEPTED';

  _ChatRepository(this.messagesToReturn, {Set<int>? blockedUserIds})
    : blockedUserIds = blockedUserIds ?? {};

  @override
  Future<MessagePage> messages(
    int conversationId,
    String token, {
    int? beforeSequence,
    int? afterSequence,
    int size = 30,
  }) async => MessagePage(
    content: messagesToReturn,
    hasMore: false,
    lastSequence: messagesToReturn.isEmpty
        ? 0
        : messagesToReturn.last.sequenceNumber,
    peerReadSequence: 0,
  );

  @override
  Future<void> markRead(int conversationId, int sequence, String token) async {
    markReadCalls++;
  }

  @override
  Future<ConversationSummary> acceptMessageRequest(
    int conversationId,
    String token,
  ) async {
    acceptCalls++;
    return ConversationSummary(
      conversationId: conversationId,
      peer: const PublicUserSummary(userId: 2, handle: 'traveler'),
      lastMessageSequence: messagesToReturn.length,
      unreadCount: 0,
      canSendMessage: true,
      status: 'ACCEPTED',
    );
  }

  @override
  Future<ChatMessage> send(
    int conversationId,
    String clientMessageId,
    String content,
    String token,
  ) async {
    sendCalls++;
    return ChatMessage(
      messageId: sendCalls,
      conversationId: conversationId,
      sequenceNumber: sendCalls,
      senderUserId: 1,
      senderName: 'Người dùng hiện tại',
      clientMessageId: clientMessageId,
      content: content,
      createdAt: DateTime.now(),
      recipientVisible: recipientVisibleOnSend,
      conversationStatus: conversationStatusOnSend,
    );
  }

  @override
  Future<ConversationSummary> openDirect(int recipientId, String token) async =>
      _conversation();

  @override
  Future<void> block(int userId, String token) async {
    blockCalls++;
    blockedUserIds.add(userId);
  }

  @override
  Future<void> unblock(int userId, String token) async {
    unblockCalls++;
    blockedUserIds.remove(userId);
  }

  @override
  Future<PageResult<PublicUserSummary>> blockedUsers(
    String token, {
    int page = 0,
  }) async {
    final content = blockedUserIds
        .map((id) => PublicUserSummary(userId: id, handle: 'peer-$id'))
        .toList();
    return PageResult(
      content: content,
      pageNumber: page,
      pageSize: 30,
      totalElements: content.length,
      totalPages: 1,
      isLast: true,
    );
  }
}

ChatMessage _message({
  required int id,
  required int senderId,
  required String content,
  required DateTime createdAt,
  String? avatar,
}) => ChatMessage(
  messageId: id,
  conversationId: 9,
  sequenceNumber: id,
  senderUserId: senderId,
  senderName: senderId == 1 ? 'Tôi' : 'Người bạn',
  senderAvatar: avatar,
  clientMessageId: 'client-$id',
  content: content,
  createdAt: createdAt,
);

ConversationSummary _conversation({String? peerAvatar}) => ConversationSummary(
  conversationId: 9,
  peer: PublicUserSummary.fromJson({
    'userId': 2,
    'handle': 'traveler',
    'avatar': ?peerAvatar,
  }),
  lastMessage: null,
  lastMessageSequence: 0,
  unreadCount: 0,
  canSendMessage: true,
);

Future<void> _showChat(
  WidgetTester tester, {
  required List<ChatMessage> messages,
  MessagingRepository? repository,
  ConversationSummary? conversation,
  String? ownAvatar,
  String? peerAvatar,
  _AuthenticatedNotifier? authNotifier,
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: ChatScreen(
        authNotifier: authNotifier ?? _AuthenticatedNotifier(avatar: ownAvatar),
        repository: repository ?? _ChatRepository(messages),
        realtime: _ConnectedRealtimeClient(),
        conversation: conversation ?? _conversation(peerAvatar: peerAvatar),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

int _imageCountForUrl(WidgetTester tester, String url) => tester
    .widgetList<Image>(find.byType(Image))
    .where(
      (image) =>
          image.image is NetworkImage &&
          (image.image as NetworkImage).url == url,
    )
    .length;

void main() {
  testWidgets('uses the current realtime snapshot and shows avatar/time', (
    tester,
  ) async {
    final now = DateTime.now();
    final message = ChatMessage(
      messageId: 5,
      conversationId: 9,
      sequenceNumber: 1,
      senderUserId: 2,
      senderName: 'Người bạn',
      senderAvatar: null,
      clientMessageId: 'a8e731db-5a09-4809-9210-34ef60a695ba',
      content: 'Chào bạn',
      createdAt: now,
    );
    final conversation = ConversationSummary(
      conversationId: 9,
      peer: PublicUserSummary.fromJson({'userId': 2, 'handle': 'traveler'}),
      lastMessage: message,
      lastMessageSequence: 1,
      unreadCount: 1,
      canSendMessage: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          authNotifier: _AuthenticatedNotifier(),
          repository: _ChatRepository([message]),
          realtime: _ConnectedRealtimeClient(),
          conversation: conversation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chào bạn'), findsOneWidget);
    expect(find.textContaining('Realtime'), findsNothing);
    expect(find.byIcon(Icons.person_outline), findsNWidgets(2));
    expect(find.text(MessagingDateTime.format(now)), findsOneWidget);
  });

  testWidgets('shows own avatar from profile on the outgoing side', (
    tester,
  ) async {
    final now = DateTime.now();
    await _showChat(
      tester,
      ownAvatar: 'https://example.test/current-user.png',
      peerAvatar: 'https://example.test/peer.png',
      messages: [
        _message(
          id: 1,
          senderId: 1,
          content: 'Tin nhắn của tôi',
          createdAt: now,
          avatar: 'https://example.test/stale-message-avatar.png',
        ),
      ],
    );

    expect(
      _imageCountForUrl(tester, 'https://example.test/current-user.png'),
      1,
    );
    expect(find.text('Tin nhắn của tôi'), findsOneWidget);
  });

  testWidgets('falls back to the peer profile avatar for incoming messages', (
    tester,
  ) async {
    await _showChat(
      tester,
      peerAvatar: 'https://example.test/peer-profile.png',
      messages: [
        _message(
          id: 1,
          senderId: 2,
          content: 'Tin nhắn của bạn tôi',
          createdAt: DateTime.now(),
        ),
      ],
    );

    expect(
      _imageCountForUrl(tester, 'https://example.test/peer-profile.png'),
      2,
    );
  });

  testWidgets('shows one avatar for a run of consecutive own messages', (
    tester,
  ) async {
    final now = DateTime.now();
    await _showChat(
      tester,
      ownAvatar: 'https://example.test/current-user.png',
      messages: [
        _message(id: 1, senderId: 1, content: 'Tin đầu', createdAt: now),
        _message(
          id: 2,
          senderId: 1,
          content: 'Tin tiếp theo',
          createdAt: now.add(const Duration(seconds: 20)),
        ),
      ],
    );

    expect(find.text('Tin đầu'), findsOneWidget);
    expect(find.text('Tin tiếp theo'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refreshes own avatar after the profile changes', (tester) async {
    final auth = _AuthenticatedNotifier(
      avatar: 'https://example.test/old-avatar.png',
    );
    await _showChat(
      tester,
      authNotifier: auth,
      messages: [
        _message(
          id: 1,
          senderId: 1,
          content: 'Tin nhắn',
          createdAt: DateTime.now(),
        ),
      ],
    );

    auth.avatar = 'https://example.test/new-avatar.png';
    auth.notifyListeners();
    await tester.pump();

    expect(_imageCountForUrl(tester, 'https://example.test/new-avatar.png'), 1);
  });

  testWidgets('wraps long messages without overflowing a narrow screen', (
    tester,
  ) async {
    final longMessage = List.filled(60, 'Nội dung dài').join(' ');
    await _showChat(
      tester,
      ownAvatar: 'https://example.test/current-user.png',
      peerAvatar: 'https://example.test/peer.png',
      messages: [
        _message(
          id: 1,
          senderId: 2,
          content: longMessage,
          createdAt: DateTime.now(),
        ),
      ],
    );

    expect(find.text(longMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('requires confirmation before blocking and then disables send', (
    tester,
  ) async {
    final repository = _ChatRepository([
      _message(
        id: 1,
        senderId: 2,
        content: 'Lịch sử được giữ',
        createdAt: DateTime.now(),
      ),
    ]);
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          authNotifier: _AuthenticatedNotifier(),
          repository: repository,
          realtime: _ConnectedRealtimeClient(),
          conversation: _conversation(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tùy chọn cuộc trò chuyện'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chặn người dùng'));
    await tester.pumpAndSettle();
    expect(find.text('Chặn người dùng?'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(repository.blockCalls, 0);

    await tester.tap(find.byTooltip('Tùy chọn cuộc trò chuyện'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chặn người dùng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chặn').last);
    await tester.pumpAndSettle();

    expect(repository.blockCalls, 1);
    expect(
      find.text('Bạn đã chặn người dùng này. Lịch sử vẫn được giữ.'),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(find.text('Lịch sử được giữ'), findsOneWidget);
  });

  testWidgets('shows unblock action after restoring persisted block state', (
    tester,
  ) async {
    final repository = _ChatRepository(const [], blockedUserIds: {2});
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          authNotifier: _AuthenticatedNotifier(),
          repository: repository,
          realtime: _ConnectedRealtimeClient(),
          conversation: _conversation(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tùy chọn cuộc trò chuyện'));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ chặn người dùng'), findsOneWidget);
    await tester.tap(find.text('Bỏ chặn người dùng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ chặn').last);
    await tester.pumpAndSettle();

    expect(repository.unblockCalls, 1);
    expect(repository.blockedUserIds, isEmpty);
    expect(find.text('Đã bỏ chặn người dùng.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
  });

  testWidgets('friends-only stranger thread permits multiple sender messages', (
    tester,
  ) async {
    final repository = _ChatRepository(const []);
    final conversation = ConversationSummary(
      conversationId: 9,
      peer: PublicUserSummary.fromJson({'userId': 2, 'handle': 'traveler'}),
      lastMessageSequence: 0,
      unreadCount: 0,
      canSendMessage: true,
      status: 'PENDING',
      recipientPrivacyRestricted: true,
    );
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          authNotifier: _AuthenticatedNotifier(),
          repository: repository,
          realtime: _ConnectedRealtimeClient(),
          conversation: conversation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Tin nhắn bạn gửi chỉ hiển thị với bạn'),
      findsOneWidget,
    );
    for (final content in ['Tin thứ nhất', 'Tin thứ hai']) {
      await tester.enterText(find.byType(TextField), content);
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
    }

    expect(repository.sendCalls, 2);
    expect(find.text('Tin thứ nhất'), findsOneWidget);
    expect(find.text('Tin thứ hai'), findsOneWidget);
  });

  testWidgets(
    'accepted chat remains normal after unfriend and ignores new privacy policy',
    (tester) async {
      final repository = _ChatRepository(const []);
      await _showChat(tester, messages: const [], repository: repository);

      await tester.enterText(
        find.byType(TextField),
        'Tin riêng sau khi hủy kết bạn',
      );
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Tin nhắn bạn gửi chỉ hiển thị với bạn'),
        findsNothing,
      );
      expect(find.text('Tin riêng sau khi hủy kết bạn'), findsOneWidget);
      expect(find.text('Đã gửi'), findsOneWidget);
    },
  );

  testWidgets('opening pending request does not mark it read until accepted', (
    tester,
  ) async {
    final incoming = _message(
      id: 1,
      senderId: 2,
      content: 'Tin nhắn đang chờ',
      createdAt: DateTime.now(),
    );
    final pending = ConversationSummary(
      conversationId: 9,
      peer: const PublicUserSummary(userId: 2, handle: 'traveler'),
      lastMessage: incoming,
      lastMessageSequence: 1,
      unreadCount: 1,
      canSendMessage: false,
      status: 'PENDING',
      canRespondToMessageRequest: true,
    );
    final repository = _ChatRepository([incoming]);
    await _showChat(
      tester,
      messages: [incoming],
      repository: repository,
      conversation: pending,
    );

    expect(repository.markReadCalls, 0);
    expect(find.text('Chấp nhận'), findsOneWidget);
    await tester.tap(find.text('Chấp nhận'));
    await tester.pumpAndSettle();

    expect(repository.acceptCalls, 1);
    expect(repository.markReadCalls, 0);
    expect(find.text('Chấp nhận'), findsNothing);
    expect(find.text('Từ chối'), findsNothing);
    expect(find.text('Tin nhắn đang chờ'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
  });

  testWidgets(
    'restricted pending thread keeps old visible history without exposing sender notice',
    (tester) async {
      final previousMessage = _message(
        id: 2,
        senderId: 1,
        content: 'Lịch sử đã có trước đây',
        createdAt: DateTime.now(),
      );
      final restrictedThread = ConversationSummary(
        conversationId: 9,
        peer: const PublicUserSummary(userId: 2, handle: 'traveler'),
        lastMessage: previousMessage,
        lastMessageSequence: 5,
        unreadCount: 0,
        canSendMessage: false,
        status: 'PENDING',
        canRespondToMessageRequest: false,
      );
      await _showChat(
        tester,
        messages: [previousMessage],
        conversation: restrictedThread,
      );

      expect(find.text('Lịch sử đã có trước đây'), findsOneWidget);
      expect(find.textContaining('Tin nhắn của bạn đang ở mục'), findsNothing);
      expect(find.textContaining('chỉ hiển thị với bạn'), findsNothing);
    },
  );
}
