import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/profile/data/profile_repository.dart';
import 'package:mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:mobile/features/social/data/community_post_repository.dart';
import 'package:mobile/features/social/data/models/post_comment_model.dart';
import 'package:mobile/features/social/data/models/post_model.dart';
import 'package:mobile/features/social/presentation/screens/create_post_screen.dart';
import 'package:mobile/features/social/presentation/widgets/fullscreen_image_viewer.dart';
import 'package:mobile/features/social/presentation/widgets/post_comments_sheet.dart';

final Uint8List _transparentPng = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  Duration? connectionTimeout = const Duration(seconds: 15);

  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _MockHttpClientRequest();
  }
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return _MockHttpClientResponse();
  }
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => _transparentPng.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_transparentPng).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  bool get isAuthenticated => true;
  @override
  String? get token => 'test-valid-jwt-token';
  @override
  Map<String, dynamic>? get currentUser => {
    'userId': 1,
    'username': 'john_traveler',
    'fullName': 'John Traveler',
  };
}

class _MockProfileRepo extends ProfileRepository {
  @override
  Future<Map<String, dynamic>> getProfile(String token) async {
    return {
      'userId': 1,
      'fullName': 'John Traveler',
      'handle': 'john_traveler',
      'email': 'john@example.com',
      'role': 'USER',
      'status': 'ACTIVE',
      'createdAt': '2025-01-01T00:00:00',
    };
  }
}

class _MockCommunityPostRepo extends CommunityPostRepository {
  List<PostCommentModel> commentsToReturn = [];
  int? lastParentCommentId;
  String? lastCommentContent;
  int addCommentCallCount = 0;

  bool updatePostCalled = false;
  String? lastUpdatedContent;
  List<int>? lastUpdatedAssetIds;
  int? lastUpdatedItineraryId;
  bool? lastDetachItinerary;

  List<PostModel> myPostsToReturn = [];
  int getMyPostsCallCount = 0;

  @override
  Future<PostCommentPage> getComments(
    int postId, {
    int page = 0,
    int size = 20,
    String? token,
  }) async {
    return PostCommentPage(
      comments: List.from(commentsToReturn),
      pageNumber: page,
      totalPages: 1,
      last: true,
    );
  }

  @override
  Future<PostCommentModel> addComment(
    int postId, {
    required String content,
    int? parentCommentId,
    required String token,
  }) async {
    addCommentCallCount++;
    lastCommentContent = content;
    lastParentCommentId = parentCommentId;
    return PostCommentModel(
      commentId: 990 + addCommentCallCount,
      postId: postId,
      content: content,
      parentCommentId: parentCommentId,
      rootCommentId: parentCommentId,
      replyToUser: parentCommentId != null
          ? const PostAuthorModel(
              userId: 2,
              handle: 'alice',
              fullName: 'Alice Walker',
            )
          : null,
      author: const PostAuthorModel(
        userId: 1,
        handle: 'john_traveler',
        fullName: 'John Traveler',
      ),
      isOwner: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<PostModel> updatePost(
    int postId, {
    String? content,
    String? visibility,
    List<int>? mediaAssetIds,
    int? itineraryId,
    bool? detachItinerary,
    required String token,
  }) async {
    updatePostCalled = true;
    lastUpdatedContent = content;
    lastUpdatedAssetIds = mediaAssetIds;
    lastUpdatedItineraryId = itineraryId;
    lastDetachItinerary = detachItinerary;
    return PostModel(
      postId: postId,
      content: content ?? '',
      author: const PostAuthorModel(
        userId: 1,
        handle: 'john_traveler',
        fullName: 'John Traveler',
      ),
      mediaUrls: const [],
      mediaAssetIds: mediaAssetIds ?? const [],
      visibility: visibility ?? 'PUBLIC',
      status: 'ACTIVE',
      likeCount: 0,
      commentCount: 0,
      isLikedByMe: false,
      isOwner: true,
      createdAt: DateTime.now(),
    );
  }

  int uploadImageCallCount = 0;
  List<int>? lastUploadedBytes;
  String? lastUploadedFilename;

  @override
  Future<Map<String, dynamic>> uploadImage({
    required List<int> bytes,
    required String filename,
    required String token,
  }) async {
    uploadImageCallCount++;
    lastUploadedBytes = bytes;
    lastUploadedFilename = filename;
    return {
      'mediaAssetId': 200 + uploadImageCallCount,
      'secureUrl':
          'https://res.cloudinary.com/demo/image/upload/v1/new_upload_$uploadImageCallCount.jpg',
    };
  }

  PostModel? postDetailToReturn;
  int getPostByIdCallCount = 0;

  @override
  Future<PostModel> getPostById(int postId, {String? token}) async {
    getPostByIdCallCount++;
    if (postDetailToReturn != null) {
      return postDetailToReturn!;
    }
    return PostModel(
      postId: postId,
      content: '',
      author: const PostAuthorModel(userId: 1, handle: 'john_traveler'),
      mediaUrls: const [],
      mediaAssetIds: const [],
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<PostModel>> getMyPosts({
    int page = 0,
    int size = 10,
    required String token,
  }) async {
    getMyPostsCallCount++;
    return List.from(myPostsToReturn);
  }
}

class _FakeImagePicker extends Fake implements ImagePicker {
  List<XFile> multiImagesToReturn = [];
  XFile? singleImageToReturn;
  int pickMultiImageCallCount = 0;
  int pickImageCallCount = 0;

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    pickMultiImageCallCount++;
    return multiImagesToReturn;
  }

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    pickImageCallCount++;
    return singleImageToReturn;
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  late _FakeAuthNotifier authNotifier;
  late _MockCommunityPostRepo postRepo;

  setUp(() {
    authNotifier = _FakeAuthNotifier();
    postRepo = _MockCommunityPostRepo();
  });

  Widget buildApp(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }

  group('Item 1: Hoàn thiện chỉnh sửa bài viết (Edit Post)', () {
    testWidgets(
      'hiển thị đúng dữ liệu cũ, cho phép gỡ lịch trình và gửi updatePost',
      (tester) async {
        final existingPost = PostModel(
          postId: 42,
          content: 'Khám phá Đà Nẵng 3 ngày 2 đêm',
          author: const PostAuthorModel(
            userId: 1,
            handle: 'john_traveler',
            fullName: 'John Traveler',
          ),
          mediaUrls: const [
            'https://res.cloudinary.com/demo/image/upload/v1/sample.jpg',
          ],
          mediaAssetIds: const [101],
          itinerary: const PostItineraryModel(
            itineraryId: 77,
            title: 'Lịch trình Đà Nẵng - Hội An',
            totalDays: 3,
            location: 'Đà Nẵng',
          ),
          visibility: 'PUBLIC',
          status: 'ACTIVE',
          likeCount: 5,
          commentCount: 2,
          isLikedByMe: false,
          isOwner: true,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          buildApp(
            CreatePostScreen(
              authNotifier: authNotifier,
              editingPost: existingPost,
              repository: postRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check title and save button
        expect(find.text('Chỉnh sửa bài viết'), findsOneWidget);
        expect(find.text('Lưu'), findsOneWidget);

        // Verify content pre-populated
        expect(find.text('Khám phá Đà Nẵng 3 ngày 2 đêm'), findsOneWidget);

        // Verify existing itinerary displayed
        expect(find.text('Lịch trình Đà Nẵng - Hội An'), findsOneWidget);

        // Verify action attachment buttons are available
        expect(find.text('Thêm ảnh (1/5)'), findsOneWidget);
        expect(find.text('Thay đổi lịch trình'), findsOneWidget);

        // Detach itinerary by tapping close icon on existing itinerary
        final detachBtn = find.byTooltip('Gỡ lịch trình');
        expect(detachBtn, findsOneWidget);
        await tester.tap(detachBtn);
        await tester.pumpAndSettle();

        // Itinerary removed from UI
        expect(find.text('Lịch trình Đà Nẵng - Hội An'), findsNothing);
        expect(find.text('Đính kèm lịch trình'), findsOneWidget);

        // Tap 'Lưu' button to submit
        await tester.tap(find.text('Lưu'));
        await tester.pumpAndSettle();

        // Verify updatePost called with detachItinerary: true and original asset id preserved
        expect(postRepo.updatePostCalled, isTrue);
        expect(postRepo.lastUpdatedContent, 'Khám phá Đà Nẵng 3 ngày 2 đêm');
        expect(postRepo.lastUpdatedAssetIds, [101]);
        expect(postRepo.lastDetachItinerary, isTrue);
      },
    );

    testWidgets(
      'Edit Post: giữ ảnh cũ và thêm ảnh mới thành công, upload Cloudinary và gửi đầy đủ mediaAssetIds cũ + mới',
      (tester) async {
        final fakePicker = _FakeImagePicker();
        fakePicker.multiImagesToReturn = [
          XFile.fromData(
            _transparentPng,
            path: 'beach_photo.jpg',
            name: 'beach_photo.jpg',
          ),
        ];

        final existingPost = PostModel(
          postId: 55,
          content: 'Chuyến đi Phú Quốc tuyệt vời',
          author: const PostAuthorModel(
            userId: 1,
            handle: 'john_traveler',
            fullName: 'John Traveler',
          ),
          mediaUrls: const [
            'https://res.cloudinary.com/demo/image/upload/v1/old_beach.jpg',
          ],
          mediaAssetIds: const [101],
          visibility: 'PUBLIC',
          status: 'ACTIVE',
          likeCount: 1,
          commentCount: 0,
          isLikedByMe: false,
          isOwner: true,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          buildApp(
            CreatePostScreen(
              authNotifier: authNotifier,
              editingPost: existingPost,
              repository: postRepo,
              imagePicker: fakePicker,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify initial state: 1 photo displayed, counter shows 1/5
        expect(find.text('Thêm ảnh (1/5)'), findsOneWidget);
        expect(
          find.text('Thêm ảnh'),
          findsOneWidget,
        ); // Inline add button in thumbnail strip

        // Tap the inline 'Thêm ảnh' card in the thumbnail strip
        await tester.tap(find.text('Thêm ảnh'));
        await tester.pumpAndSettle();

        // Verify picker and upload were invoked
        expect(fakePicker.pickMultiImageCallCount, 1);
        expect(postRepo.uploadImageCallCount, 1);
        expect(postRepo.lastUploadedFilename, 'beach_photo.jpg');

        // UI is updated: now shows 2 photos
        expect(find.text('Thêm ảnh (2/5)'), findsOneWidget);

        // Tap 'Lưu' button
        await tester.tap(find.text('Lưu'));
        await tester.pumpAndSettle();

        // Verify updatePost received BOTH old asset ID (101) and new asset ID (201) in exact order
        expect(postRepo.updatePostCalled, isTrue);
        expect(postRepo.lastUpdatedAssetIds, [101, 201]);
        expect(postRepo.lastUpdatedContent, 'Chuyến đi Phú Quốc tuyệt vời');
      },
    );

    testWidgets(
      'Edit Post: tự động phục hồi mediaAssetIds qua getPostById khi dữ liệu cũ bị thiếu',
      (tester) async {
        final fakePicker = _FakeImagePicker();
        fakePicker.multiImagesToReturn = [
          XFile.fromData(_transparentPng, name: 'extra.jpg'),
        ];

        // Existing post with photo URL but empty mediaAssetIds (legacy / partial data)
        final legacyPost = PostModel(
          postId: 60,
          content: 'Bài viết dữ liệu cũ',
          author: const PostAuthorModel(
            userId: 1,
            handle: 'john_traveler',
            fullName: 'John Traveler',
          ),
          mediaUrls: const [
            'https://res.cloudinary.com/demo/image/upload/v1/legacy.jpg',
          ],
          mediaAssetIds: const [], // Missing
          visibility: 'PUBLIC',
          status: 'ACTIVE',
          likeCount: 0,
          commentCount: 0,
          isLikedByMe: false,
          isOwner: true,
          createdAt: DateTime.now(),
        );

        // Backend getPostById has full asset details
        postRepo.postDetailToReturn = PostModel(
          postId: 60,
          content: 'Bài viết dữ liệu cũ',
          author: const PostAuthorModel(
            userId: 1,
            handle: 'john_traveler',
            fullName: 'John Traveler',
          ),
          mediaUrls: const [
            'https://res.cloudinary.com/demo/image/upload/v1/legacy.jpg',
          ],
          mediaAssetIds: const [789],
          visibility: 'PUBLIC',
          status: 'ACTIVE',
          likeCount: 0,
          commentCount: 0,
          isLikedByMe: false,
          isOwner: true,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          buildApp(
            CreatePostScreen(
              authNotifier: authNotifier,
              editingPost: legacyPost,
              repository: postRepo,
              imagePicker: fakePicker,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verified getPostById was fetched to resolve missing mediaAssetIds
        expect(postRepo.getPostByIdCallCount, greaterThanOrEqualTo(1));

        // Add another photo
        await tester.tap(find.text('Thêm ảnh (1/5)'));
        await tester.pumpAndSettle();

        expect(postRepo.uploadImageCallCount, 1);
        expect(find.text('Thêm ảnh (2/5)'), findsOneWidget);

        // Save post
        await tester.tap(find.text('Lưu'));
        await tester.pumpAndSettle();

        // Asset IDs contain recovered ID 789 and newly uploaded ID 201
        expect(postRepo.updatePostCalled, isTrue);
        expect(postRepo.lastUpdatedAssetIds, [789, 201]);
      },
    );

    testWidgets('Edit Post: cho phép thay thế (replace) và xóa (remove) ảnh', (
      tester,
    ) async {
      final fakePicker = _FakeImagePicker();
      fakePicker.singleImageToReturn = XFile.fromData(
        _transparentPng,
        path: 'replaced.jpg',
        name: 'replaced.jpg',
      );

      final existingPost = PostModel(
        postId: 70,
        content: 'Hai bức ảnh',
        author: const PostAuthorModel(
          userId: 1,
          handle: 'john_traveler',
          fullName: 'John Traveler',
        ),
        mediaUrls: const [
          'https://res.cloudinary.com/demo/image/upload/v1/img1.jpg',
          'https://res.cloudinary.com/demo/image/upload/v1/img2.jpg',
        ],
        mediaAssetIds: const [101, 102],
        visibility: 'PUBLIC',
        status: 'ACTIVE',
        likeCount: 0,
        commentCount: 0,
        isLikedByMe: false,
        isOwner: true,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        buildApp(
          CreatePostScreen(
            authNotifier: authNotifier,
            editingPost: existingPost,
            repository: postRepo,
            imagePicker: fakePicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thêm ảnh (2/5)'), findsOneWidget);

      // Replace first image (tap swap icon)
      final swapIcons = find.byIcon(Icons.swap_horiz);
      expect(swapIcons, findsNWidgets(2));
      await tester.tap(swapIcons.first);
      await tester.pumpAndSettle();

      expect(fakePicker.pickImageCallCount, 1);
      expect(postRepo.uploadImageCallCount, 1);
      expect(postRepo.lastUploadedFilename, 'replaced.jpg');

      // Remove second image (tap close icon on second image)
      final closeIcons = find.byIcon(Icons.close);
      expect(closeIcons, findsNWidgets(2));
      await tester.tap(closeIcons.last);
      await tester.pumpAndSettle();

      // Now only 1 photo remains
      expect(find.text('Thêm ảnh (1/5)'), findsOneWidget);

      // Save
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(postRepo.updatePostCalled, isTrue);
      // Asset IDs should only contain replaced asset ID 201 (asset 101 replaced by 201, asset 102 removed)
      expect(postRepo.lastUpdatedAssetIds, [201]);
    });
  });

  group(
    'Item 2: Xem ảnh toàn màn hình như Facebook (FullscreenImageViewer)',
    () {
      testWidgets('hiển thị nền tối, số trang, hỗ trợ swipe và nút đóng', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const FullscreenImageViewer(
              imageUrls: [
                'https://example.com/photo1.jpg',
                'https://example.com/photo2.jpg',
              ],
              initialIndex: 0,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Counter indicator
        expect(find.text('1 / 2'), findsOneWidget);

        // InteractiveViewer present
        expect(find.byType(InteractiveViewer), findsOneWidget);

        // Close button present
        final closeBtn = find.byIcon(Icons.close);
        expect(closeBtn, findsOneWidget);

        // Swipe to next image
        await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Counter indicator updated
        expect(find.text('2 / 2'), findsOneWidget);
      });
    },
  );

  group('Item 3: Trả lời bình luận bài viết (Reply to Post Comments)', () {
    testWidgets(
      'hiển thị reply lồng nhau, ngữ cảnh đang trả lời và gửi parentCommentId',
      (tester) async {
        final now = DateTime.now();
        postRepo.commentsToReturn = [
          PostCommentModel(
            commentId: 101,
            postId: 10,
            content: 'Bài viết rất hay!',
            author: const PostAuthorModel(
              userId: 2,
              handle: 'alice',
              fullName: 'Alice Walker',
            ),
            isOwner: false,
            createdAt: now.subtract(const Duration(minutes: 5)),
          ),
          PostCommentModel(
            commentId: 102,
            postId: 10,
            content: 'Cảm ơn bạn nhiều!',
            parentCommentId: 101,
            rootCommentId: 101,
            replyToUser: const PostAuthorModel(
              userId: 2,
              handle: 'alice',
              fullName: 'Alice Walker',
            ),
            author: const PostAuthorModel(
              userId: 1,
              handle: 'john_traveler',
              fullName: 'John Traveler',
            ),
            isOwner: true,
            createdAt: now.subtract(const Duration(minutes: 2)),
          ),
        ];

        await tester.pumpWidget(
          buildApp(
            PostCommentsSheet(
              postId: 10,
              token: authNotifier.token,
              repository: postRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify root comment and nested reply context
        expect(find.text('Bài viết rất hay!'), findsOneWidget);
        expect(find.text('Cảm ơn bạn nhiều!'), findsOneWidget);
        expect(find.text('Trả lời @Alice Walker'), findsOneWidget);

        // Tap "Trả lời" on root comment
        final replyButtons = find.text('Trả lời');
        expect(replyButtons, findsNWidgets(2));
        await tester.tap(replyButtons.first);
        await tester.pumpAndSettle();

        // Reply preview banner appears
        expect(find.text('Đang trả lời @Alice Walker'), findsOneWidget);

        // Enter reply text and submit
        await tester.enterText(find.byType(TextField), 'Chuẩn bị đi tiếp nào!');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();

        // Verify API was called with parentCommentId = 101
        expect(postRepo.addCommentCallCount, 1);
        expect(postRepo.lastCommentContent, 'Chuẩn bị đi tiếp nào!');
        expect(postRepo.lastParentCommentId, 101);

        // Reply banner disappears after submit
        expect(find.text('Đang trả lời @Alice Walker'), findsNothing);
      },
    );
  });

  group(
    'Item 4: Thay tab Thông tin tài khoản bằng Bài viết của tôi trong Profile',
    () {
      testWidgets(
        'chuyển tab Bài viết, tải danh sách bài viết của tôi và hiển thị đúng',
        (tester) async {
          postRepo.myPostsToReturn = [
            PostModel(
              postId: 55,
              content: 'Kỷ niệm chuyến đi Phú Quốc tuyệt vời!',
              author: const PostAuthorModel(
                userId: 1,
                handle: 'john_traveler',
                fullName: 'John Traveler',
              ),
              mediaUrls: const [],
              mediaAssetIds: const [],
              visibility: 'PUBLIC',
              status: 'ACTIVE',
              likeCount: 3,
              commentCount: 1,
              isLikedByMe: false,
              isOwner: true,
              createdAt: DateTime.now(),
            ),
          ];

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: ProfileScreen(
                authNotifier: authNotifier,
                repository: _MockProfileRepo(),
                postRepository: postRepo,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Tab bar must have "Bài viết", and NOT "Thông tin tài khoản"
          final postsTab = find.widgetWithText(InkWell, 'Bài viết');
          expect(postsTab, findsOneWidget);
          expect(find.text('Thông tin tài khoản'), findsNothing);

          // Switch to "Bài viết" tab
          await tester.tap(postsTab);
          await tester.pumpAndSettle();

          // Verify post content from my posts
          expect(
            find.text('Kỷ niệm chuyến đi Phú Quốc tuyệt vời!'),
            findsOneWidget,
          );
        },
      );
    },
  );
}
