import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/messaging/data/models/share_batch_models.dart';
import 'package:mobile/features/social/data/models/post_model.dart';
import 'package:mobile/features/social/presentation/widgets/post_card_widget.dart';

void main() {
  group('Post Share Count & UI Tests', () {
    test('1. PostModel parses shareCount accurately from backend JSON', () {
      final json = {
        'postId': 123,
        'content': 'Test post content',
        'author': {
          'userId': 1,
          'handle': 'tester',
          'fullName': 'Test User',
        },
        'mediaUrls': <String>[],
        'mediaAssetIds': <int>[],
        'visibility': 'PUBLIC',
        'status': 'ACTIVE',
        'likeCount': 10,
        'commentCount': 4,
        'shareCount': 7,
        'createdAt': '2026-11-21T10:00:00.000',
      };

      final post = PostModel.fromJson(json);

      expect(post.postId, 123);
      expect(post.likeCount, 10);
      expect(post.commentCount, 4);
      expect(post.shareCount, 7);
    });

    test('2. PostModel safely defaults shareCount to 0 when null or missing', () {
      final json = {
        'postId': 124,
        'content': 'Post with null shareCount',
        'author': {
          'userId': 1,
          'handle': 'tester',
        },
        'mediaUrls': <String>[],
        'mediaAssetIds': <int>[],
        'shareCount': null,
        'createdAt': '2026-11-21T10:00:00.000',
      };

      final post = PostModel.fromJson(json);

      expect(post.shareCount, 0);
    });

    test('3. PostModel copyWith preserves and updates shareCount', () {
      final post = PostModel(
        postId: 1,
        content: 'Content',
        author: const PostAuthorModel(userId: 1, handle: 'user'),
        mediaUrls: const [],
        mediaAssetIds: const [],
        createdAt: DateTime.now(),
        shareCount: 2,
      );

      final updated = post.copyWith(shareCount: 5);
      expect(updated.shareCount, 5);
      expect(post.shareCount, 2);
    });

    test('4. ShareBatchRequest includes shareBatchId in JSON serialization', () {
      const request = ShareBatchRequest(
        targetType: 'POST',
        targetId: 300,
        recipientUserIds: [2, 3],
        note: 'Check this out!',
        shareBatchId: 'batch-test-123',
      );

      final json = request.toJson();
      expect(json['targetType'], 'POST');
      expect(json['targetId'], 300);
      expect(json['recipientUserIds'], [2, 3]);
      expect(json['note'], 'Check this out!');
      expect(json['shareBatchId'], 'batch-test-123');
    });

    testWidgets('5. PostCardWidget displays "Chia sẻ" when shareCount is 0', (tester) async {
      final post = PostModel(
        postId: 1,
        content: 'Post with 0 shares',
        author: const PostAuthorModel(userId: 1, handle: 'user', fullName: 'User One'),
        mediaUrls: const [],
        mediaAssetIds: const [],
        createdAt: DateTime.now(),
        likeCount: 1,
        commentCount: 2,
        shareCount: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostCardWidget(
              post: post,
            ),
          ),
        ),
      );

      // Verify like and comment counts
      expect(find.text('1'), findsOneWidget); // like count
      expect(find.text('2'), findsOneWidget); // comment count

      // Verify share button displays 'Chia sẻ' and NOT '0' when shareCount is 0
      expect(find.text('Chia sẻ'), findsOneWidget);
      expect(find.text('0'), findsNothing);

      // Verify right-curved share icon (flipped Icons.reply)
      expect(find.byIcon(Icons.reply), findsOneWidget);
    });

    testWidgets('6. PostCardWidget displays share count when > 0 and calls onShare', (tester) async {
      bool shareTapped = false;

      final post = PostModel(
        postId: 2,
        content: 'Post with 5 shares',
        author: const PostAuthorModel(userId: 1, handle: 'user', fullName: 'User One'),
        mediaUrls: const [],
        mediaAssetIds: const [],
        createdAt: DateTime.now(),
        likeCount: 3,
        commentCount: 1,
        shareCount: 5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostCardWidget(
              post: post,
              onShare: () {
                shareTapped = true;
              },
            ),
          ),
        ),
      );

      // Verify share count displays '5'
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Chia sẻ'), findsNothing);

      // Tap the share button
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();

      expect(shareTapped, isTrue);
    });
  });
}
