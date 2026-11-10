import '../../../core/network/api_client.dart';
import '../../explore/data/models/page_result.dart';
import '../../profile/data/models/public_user_summary.dart';
import 'models/chat_message.dart';
import 'models/conversation_summary.dart';
import 'models/friend_request.dart';
import 'models/messaging_settings.dart';

class MessagingRepository {
  final ApiClient _api;
  MessagingRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  Future<PageResult<ConversationSummary>> conversations(
    String token, {
    int page = 0,
  }) async => _page(
    await _api.get(
      '/api/conversations',
      token: token,
      queryParameters: {'page': page, 'size': 30},
    ),
    ConversationSummary.fromJson,
  );

  Future<ConversationSummary> openDirect(int recipientId, String token) async =>
      ConversationSummary.fromJson(
        Map<String, dynamic>.from(
          await _api.post(
            '/api/conversations/direct',
            token: token,
            body: {'recipientUserId': recipientId},
          ) as Map,
        ),
      );

  Future<MessagePage> messages(
    int conversationId,
    String token, {
    int? beforeSequence,
    int? afterSequence,
    int size = 30,
  }) async {
    final response = await _api.get(
      '/api/conversations/$conversationId/messages',
      token: token,
      queryParameters: {
        'beforeSequence': beforeSequence,
        'afterSequence': afterSequence,
        'size': size,
      },
    );
    final map = Map<String, dynamic>.from(response as Map);
    return MessagePage(
      content: (map['content'] as List? ?? const [])
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      hasMore: map['hasMore'] == true,
      nextBeforeSequence: (map['nextBeforeSequence'] as num?)?.toInt(),
      lastSequence: (map['lastSequence'] as num?)?.toInt(),
      peerReadSequence: (map['peerReadSequence'] as num?)?.toInt(),
    );
  }

  Future<ChatMessage> send(
    int conversationId,
    String clientMessageId,
    String content,
    String token,
  ) async => ChatMessage.fromJson(
    Map<String, dynamic>.from(
      await _api.post(
        '/api/conversations/$conversationId/messages',
        token: token,
        body: {'clientMessageId': clientMessageId, 'content': content},
      ) as Map,
    ),
  );

  Future<void> markRead(int conversationId, int sequence, String token) async =>
      _api.post(
        '/api/conversations/$conversationId/read',
        token: token,
        body: {'lastReadSequence': sequence},
      );

  Future<PageResult<PublicUserSummary>> friends(
    String token, {
    int page = 0,
  }) async => _page(
    await _api.get(
      '/api/users/me/friends',
      token: token,
      queryParameters: {'page': page, 'size': 30},
    ),
    (json) => PublicUserSummary.fromJson(json),
  );

  Future<PageResult<FriendRequest>> requests(
    String token,
    String direction, {
    int page = 0,
  }) async => _page(
    await _api.get(
      '/api/users/me/friend-requests',
      token: token,
      queryParameters: {'direction': direction, 'page': page, 'size': 30},
    ),
    FriendRequest.fromJson,
  );

  Future<void> sendFriendRequest(int userId, String token) async => _api.post(
    '/api/users/$userId/friend-requests',
    token: token,
    body: const {},
  );
  Future<void> acceptFriendRequest(int id, String token) async => _api.post(
    '/api/friend-requests/$id/accept',
    token: token,
    body: const {},
  );
  Future<void> declineFriendRequest(int id, String token) async => _api.post(
    '/api/friend-requests/$id/decline',
    token: token,
    body: const {},
  );
  Future<void> cancelFriendRequest(int id, String token) async =>
      _api.delete('/api/friend-requests/$id', token: token);
  Future<void> unfriend(int userId, String token) async =>
      _api.delete('/api/users/me/friends/$userId', token: token);
  Future<void> block(int userId, String token) async =>
      _api.post('/api/users/$userId/block', token: token, body: const {});
  Future<void> unblock(int userId, String token) async =>
      _api.delete('/api/users/$userId/block', token: token);

  Future<PageResult<PublicUserSummary>> blockedUsers(
    String token, {
    int page = 0,
  }) async => _page(
    await _api.get(
      '/api/users/me/blocks',
      token: token,
      queryParameters: {'page': page, 'size': 30},
    ),
    (json) => PublicUserSummary.fromJson(json),
  );

  Future<MessagingSettings> settings(String token) async =>
      MessagingSettings.fromJson(
        Map<String, dynamic>.from(
          await _api.get('/api/users/me/messaging-settings', token: token)
              as Map,
        ),
      );

  Future<MessagingSettings> updateSettings(
    MessagingSettings value,
    String token,
  ) async => MessagingSettings.fromJson(
    Map<String, dynamic>.from(
      await _api.put(
        '/api/users/me/messaging-settings',
        token: token,
        body: {'inboundPolicy': value.apiValue},
      ) as Map,
    ),
  );

  PageResult<T> _page<T>(
    dynamic value,
    T Function(Map<String, dynamic>) parse,
  ) {
    return PageResult<T>.fromJson(
      Map<String, dynamic>.from(value as Map),
      (item) => parse(Map<String, dynamic>.from(item as Map)),
    );
  }
}

class MessagePage {
  final List<ChatMessage> content;
  final bool hasMore;
  final int? nextBeforeSequence;
  final int? lastSequence;
  final int? peerReadSequence;
  const MessagePage({
    required this.content,
    required this.hasMore,
    this.nextBeforeSequence,
    this.lastSequence,
    this.peerReadSequence,
  });
}
