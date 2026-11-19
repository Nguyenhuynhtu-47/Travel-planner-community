import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/sync/app_sync_bus.dart';
import '../../../../core/sync/auto_refresh_lifecycle_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_page_title.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/services/image_picker_service.dart';
import '../../../../shared/widgets/image_upload_preview.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../explore/data/models/itinerary_summary.dart';
import '../../../explore/presentation/widgets/itinerary_card.dart';
import '../../../itinerary/presentation/screens/itinerary_detail_screen.dart';
import '../../../itinerary/presentation/screens/my_itineraries_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../messaging/data/messaging_repository.dart';
import '../../../messaging/presentation/screens/messaging_settings_screen.dart';
import '../../data/profile_repository.dart';
import '../../data/public_profile_repository.dart';
import '../../../social/data/community_post_repository.dart';
import '../../../social/data/models/post_model.dart';
import '../../../social/presentation/screens/create_post_screen.dart';
import '../../../social/presentation/widgets/post_card_widget.dart';
import '../../../social/presentation/widgets/post_comments_sheet.dart';
import 'personal_info_screen.dart';
import 'public_profile_screen.dart';
import 'public_user_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final ProfileRepository? repository;
  final ImagePickerService? imagePickerService;
  final CommunityPostRepository? postRepository;

  const ProfileScreen({
    super.key,
    required this.authNotifier,
    this.repository,
    this.imagePickerService,
    this.postRepository,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutoRefreshLifecycleMixin<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _handleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  late final ProfileRepository _repository;
  late final ImagePickerService _imagePickerService;
  late final CommunityPostRepository _postRepository;

  Map<String, dynamic>? _profile;
  String? _observedToken;
  XFile? _selectedAvatar;
  Uint8List? _selectedAvatarBytes;
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  String? _error;
  Map<String, String>? _validationErrors;

  int _followerCount = 0;
  int _followingCount = 0;
  List<ItinerarySummary> _itineraries = [];
  int _selectedProfileTab = 0;

  List<PostModel> _myPosts = [];
  bool _loadingPosts = false;
  bool _hasMorePosts = true;
  int _postsPage = 0;
  String? _postsError;

  @override
  Set<SyncDomain> get syncDomains => {
        SyncDomain.profile,
        SyncDomain.itineraries,
        SyncDomain.posts,
      };

  @override
  Duration get syncTtl => const Duration(minutes: 3);

  @override
  Future<void> onRefreshData({bool isBackground = false}) async {
    await Future.wait([
      _loadProfile(),
      _loadMyPosts(refresh: true),
    ]);
  }

  @override
  void onSyncEvent(SyncEvent event) {
    if (!mounted) return;
    if (event.domain == SyncDomain.posts) {
      if (event.type == SyncEventType.liked ||
          event.type == SyncEventType.unliked) {
        final payload = event.payload;
        if (payload is Map && event.id is int) {
          final isLiked = payload['isLiked'] == true;
          final count =
              (payload['likeCount'] as num?)?.toInt() ?? 0;
          final index = _myPosts.indexWhere((p) => p.postId == event.id);
          if (index != -1) {
            setState(() {
              _myPosts[index] = _myPosts[index].copyWith(
                isLikedByMe: isLiked,
                likeCount: count,
              );
            });
          }
        }
        return;
      }
      if (event.type == SyncEventType.deleted && event.id is int) {
        setState(() {
          _myPosts.removeWhere((p) => p.postId == event.id);
        });
        return;
      }
      if (event.type == SyncEventType.updated && event.payload is PostModel) {
        final updated = event.payload as PostModel;
        final idx = _myPosts.indexWhere((p) => p.postId == updated.postId);
        if (idx != -1) {
          setState(() {
            _myPosts[idx] = updated;
          });
        }
        return;
      }
      if (event.type == SyncEventType.created && event.payload is PostModel) {
        final post = event.payload as PostModel;
        if (post.isOwner && !_myPosts.any((p) => p.postId == post.postId)) {
          setState(() {
            _myPosts.insert(0, post);
          });
        }
        return;
      }
    }
    if (event.domain == SyncDomain.profile) {
      _loadProfile();
      return;
    }
    refreshIfStale(isBackground: true);
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ProfileRepository();
    _imagePickerService =
        widget.imagePickerService ?? DeviceImagePickerService();
    _postRepository = widget.postRepository ?? CommunityPostRepository();
    _observedToken = widget.authNotifier.token;
    widget.authNotifier.addListener(_handleAuthChanged);
    _loadProfile();
  }

  @override
  void dispose() {
    widget.authNotifier.removeListener(_handleAuthChanged);
    _fullNameController.dispose();
    _handleController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await widget.authNotifier.logout();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _fillFields(Map<String, dynamic> p) {
    _fullNameController.text = p['fullName']?.toString() ?? '';
    _handleController.text = p['handle']?.toString() ?? '';
    _selectedAvatar = null;
    _selectedAvatarBytes = null;
    _phoneController.text = p['phone']?.toString() ?? '';
    _addressController.text = p['address']?.toString() ?? '';
    _bioController.text = p['bio']?.toString() ?? '';
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await _imagePickerService.pickImage();
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ảnh không được vượt quá 5 MB')),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _selectedAvatar = image;
          _selectedAvatarBytes = bytes;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể mở thư viện ảnh. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.authNotifier != oldWidget.authNotifier) {
      oldWidget.authNotifier.removeListener(_handleAuthChanged);
      widget.authNotifier.addListener(_handleAuthChanged);
      _observedToken = widget.authNotifier.token;
      if (widget.authNotifier.isAuthenticated &&
          widget.authNotifier.token != null) {
        _loadProfile();
      } else {
        setState(() {
          _profile = null;
          _error = null;
          _loading = false;
        });
      }
    }
  }

  void _handleAuthChanged() {
    if (!mounted) return;

    final token = widget.authNotifier.token;
    if (token == _observedToken) {
      setState(() {});
      return;
    }

    _observedToken = token;
    if (widget.authNotifier.isAuthenticated && token != null) {
      _loadProfile();
      return;
    }

    setState(() {
      _profile = null;
      _error = null;
      _loading = false;
      _editing = false;
    });
  }

  Future<void> _loadProfile() async {
    final token = widget.authNotifier.token;
    if (token == null) {
      if (mounted) {
        setState(() {
          _profile = null;
          _loading = false;
          _error = widget.authNotifier.isAuthenticated
              ? 'Không tìm thấy phiên đăng nhập. Vui lòng đăng nhập lại.'
              : null;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _repository.getProfile(token);
      if (mounted) {
        setState(() {
          _profile = profile;
          _fillFields(profile);
          _loading = false;
        });
        _loadMyPosts(refresh: true);
      }

      // Fetch public stats (followers, following, itineraries)
      final userId = (profile['userId'] as num?)?.toInt();
      if (userId != null && userId > 0) {
        try {
          final publicRepo = PublicProfileRepository();
          final pubProfile = await publicRepo.getProfile(userId, token: token);
          final itins = await publicRepo.itineraries(userId, token: token);
          if (mounted) {
            setState(() {
              _followerCount = pubProfile.followerCount;
              _followingCount = pubProfile.followingCount;
              _itineraries = itins.content;
            });
          }
        } catch (_) {
          // Keep defaults if public stats fail
        }
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _logout();
        return;
      }
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải hồ sơ. Vui lòng thử lại.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final token = widget.authNotifier.token;
    if (token == null) return;
    setState(() {
      _saving = true;
      _validationErrors = null;
    });

    try {
      String? avatarUrl = _profile?['avatar']?.toString();
      final selectedAvatar = _selectedAvatar;
      final selectedBytes = _selectedAvatarBytes;
      if (selectedAvatar != null && selectedBytes != null) {
        avatarUrl = await _repository.uploadImage(
          token,
          bytes: selectedBytes,
          filename: selectedAvatar.name,
        );
      }
      final rawHandle = _handleController.text.trim().toLowerCase();
      final cleanHandle = rawHandle.startsWith('@')
          ? rawHandle.substring(1).trim()
          : rawHandle;
      final profile = await _repository.updateProfile(token, {
        'fullName': _fullNameController.text.trim(),
        'handle': cleanHandle,
        'avatar': avatarUrl ?? '',
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'bio': _bioController.text.trim(),
      });
      await widget.authNotifier.updateCurrentUser(profile);
      AppSyncBus.emitProfileUpdated(profile);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _fillFields(profile);
        _editing = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật hồ sơ'),
          backgroundColor: AppColors.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lưu thông tin hồ sơ. Vui lòng thử lại.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openSettings() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PersonalInfoScreen(
          authNotifier: widget.authNotifier,
          repository: _repository,
          imagePickerService: _imagePickerService,
        ),
      ),
    );
    if (updated == true && mounted) {
      _loadProfile();
    }
  }

  Future<void> _openMessagingPrivacy() async {
    final token = widget.authNotifier.token;
    if (token == null || token.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MessagingSettingsScreen(
          token: token,
          repository: MessagingRepository(),
        ),
      ),
    );
  }

  void _openUsers(bool followers) {
    final userId = (_profile?['userId'] as num?)?.toInt();
    if (userId == null || userId <= 0) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicUserListScreen(
          userId: userId,
          followers: followers,
          repository: PublicProfileRepository(),
          authNotifier: widget.authNotifier,
          onUserSelected: (user) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PublicProfileScreen(
                  userId: user.userId,
                  authNotifier: widget.authNotifier,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _value(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'Chưa cập nhật';
    }
    return switch (value.toString()) {
      'USER' => 'Người dùng',
      'ADMIN' => 'Quản trị viên',
      'ACTIVE' => 'Đang hoạt động',
      'INACTIVE' => 'Đã vô hiệu hóa',
      'BANNED' => 'Đã khóa',
      _ => value.toString(),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.authNotifier.isAuthenticated) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const AppPageTitle(title: 'Hồ sơ cá nhân'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Thông báo',
              icon: const Icon(Icons.notifications_outlined, size: 24),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 0.5, color: AppColors.hairlineSoft),
          ),
        ),
        body: AppEmptyState(
          icon: Icons.account_circle_outlined,
          title: 'Chưa đăng nhập',
          message:
              'Vui lòng đăng nhập để xem và cập nhật thông tin hồ sơ của bạn.',
          actionText: 'Đăng nhập',
          onActionPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/login'),
                builder: (_) => LoginScreen(authNotifier: widget.authNotifier),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppPageTitle(title: 'Hồ sơ cá nhân'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Quyền riêng tư tin nhắn',
            icon: const Icon(Icons.forum_outlined, size: 22),
            onPressed: _openMessagingPrivacy,
          ),
          IconButton(
            tooltip: 'Thông báo',
            icon: const Icon(Icons.notifications_outlined, size: 24),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Cài đặt hồ sơ',
            icon: const Icon(Icons.settings_outlined, size: 24),
            onPressed: _openSettings,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: AppColors.hairlineSoft),
        ),
      ),
      body: _loading
          ? const Center(
              key: ValueKey('profile_loading'),
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null || _profile == null
          ? KeyedSubtree(
              key: const ValueKey('profile_error'),
              child: _errorView(),
            )
          : AnimatedSwitcher(
              duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: _editing
                  ? KeyedSubtree(
                      key: const ValueKey('profile_editor'),
                      child: _editor(),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('profile_view'),
                      child: _profileView(),
                    ),
            ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Không thể tải hồ sơ. Vui lòng thử lại.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _loadProfile,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 84,
      height: 84,
      decoration: const BoxDecoration(
        color: AppColors.surfaceStrong,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, size: 44, color: AppColors.textSecondary),
    );
  }

  Widget _statusBadge(dynamic rawStatus, String statusText) {
    final statusStr = rawStatus?.toString();
    final (bgColor, borderColor, textColor) = switch (statusStr) {
      'ACTIVE' => (
        const Color(0xFFECFDF5),
        const Color(0xFFA7F3D0),
        const Color(0xFF047857),
      ),
      'BANNED' => (
        const Color(0xFFFEF2F2),
        const Color(0xFFFECACA),
        AppColors.error,
      ),
      'INACTIVE' => (
        const Color(0xFFFFFBEB),
        const Color(0xFFFDE68A),
        const Color(0xFFB45309),
      ),
      _ => (AppColors.surfaceSoft, AppColors.border, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _statItem(String label, int count, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileView() {
    final p = _profile!;
    final avatar = p['avatar']?.toString() ?? '';
    final role = _value(p['role']);
    final status = _value(p['status']);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            // Instagram-inspired Profile Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Avatar on Left + Stats on Right
                  Row(
                    children: [
                      ClipOval(
                        child: avatar.startsWith('http')
                            ? Image.network(
                                avatar,
                                width: 76,
                                height: 76,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _defaultAvatar(),
                              )
                            : _defaultAvatar(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: _statItem(
                                'Lịch trình',
                                _itineraries.isNotEmpty
                                    ? _itineraries.length
                                    : 0,
                              ),
                            ),
                            Expanded(
                              child: _statItem(
                                'Người theo dõi',
                                _followerCount,
                                onTap: () => _openUsers(true),
                              ),
                            ),
                            Expanded(
                              child: _statItem(
                                'Đang theo dõi',
                                _followingCount,
                                onTap: () => _openUsers(false),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Display Name & Handle
                  Text(
                    _value(p['fullName']),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (p['handle'] != null && p['handle'].toString().trim().isNotEmpty)
                        ? '@${p['handle'].toString().trim().replaceFirst(RegExp(r'^@+'), '')}'
                        : 'Chưa thiết lập',
                    style: TextStyle(
                      fontSize: 13,
                      color: (p['handle'] != null && p['handle'].toString().trim().isNotEmpty)
                          ? AppColors.textSecondary
                          : AppColors.mutedSoft,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  // Bio
                  if (p['bio'] != null &&
                      p['bio'].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      p['bio'].toString().trim(),
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Role & Status Badges
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          role,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      _statusBadge(p['status'], status),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Action: Edit Profile
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        // Allow inline editing or open settings
                        setState(() => _editing = true);
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(38),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: AppColors.surface,
                      ),
                      child: const Text(
                        'Chỉnh sửa hồ sơ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tabs: Lịch trình & Thông tin tài khoản
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.hairlineSoft, width: 0.5),
                  bottom: BorderSide(color: AppColors.hairlineSoft, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedProfileTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _selectedProfileTab == 0
                                  ? AppColors.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 18,
                              color: _selectedProfileTab == 0
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Lịch trình',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: _selectedProfileTab == 0
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedProfileTab = 1);
                        if (_myPosts.isEmpty && !_loadingPosts) {
                          _loadMyPosts();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _selectedProfileTab == 1
                                  ? AppColors.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.article_outlined,
                              size: 18,
                              color: _selectedProfileTab == 1
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Bài viết',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: _selectedProfileTab == 1
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content: Stack with Opacity preserves state and accessibility of both tabs
            Expanded(
              child: Stack(
                children: [
                  // Tab 1: Itineraries
                  Opacity(
                    opacity: _selectedProfileTab == 0 ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: _selectedProfileTab != 0,
                      child: _buildItinerariesTab(),
                    ),
                  ),

                  // Tab 2: My Posts
                  Opacity(
                    opacity: _selectedProfileTab == 1 ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: _selectedProfileTab != 1,
                      child: _buildMyPostsTab(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadMyPosts({bool refresh = false}) async {
    final token = widget.authNotifier.token;
    if (token == null) return;
    if (refresh) {
      _postsPage = 0;
      _hasMorePosts = true;
    }
    if (!_hasMorePosts || (_loadingPosts && !refresh)) return;

    setState(() {
      _loadingPosts = true;
      _postsError = null;
    });

    try {
      final posts = await _postRepository.getMyPosts(
        page: _postsPage,
        size: 10,
        token: token,
      );
      if (mounted) {
        setState(() {
          if (refresh) {
            _myPosts = posts;
          } else {
            _myPosts.addAll(posts);
          }
          _postsPage++;
          _hasMorePosts = posts.length >= 10;
          _loadingPosts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _postsError = 'Không thể tải danh sách bài viết';
          _loadingPosts = false;
        });
      }
    }
  }

  Future<void> _likeMyPost(PostModel post) async {
    final token = widget.authNotifier.token;
    if (token == null) return;

    final newIsLiked = !post.isLikedByMe;
    final newCount = post.likeCount + (newIsLiked ? 1 : -1);
    final updated = post.copyWith(
      isLikedByMe: newIsLiked,
      likeCount: newCount < 0 ? 0 : newCount,
    );

    setState(() {
      final index = _myPosts.indexWhere((p) => p.postId == post.postId);
      if (index != -1) _myPosts[index] = updated;
    });

    try {
      if (newIsLiked) {
        await _postRepository.likePost(post.postId, token: token);
      } else {
        await _postRepository.unlikePost(post.postId, token: token);
      }
      AppSyncBus.emitPostLiked(post.postId, newIsLiked, newCount < 0 ? 0 : newCount);
    } catch (_) {
      if (mounted) {
        setState(() {
          final index = _myPosts.indexWhere((p) => p.postId == post.postId);
          if (index != -1) _myPosts[index] = post;
        });
      }
    }
  }

  void _openPostComments(PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PostCommentsSheet(
        postId: post.postId,
        token: widget.authNotifier.token,
        repository: _postRepository,
        onCommentCountChanged: (delta) {
          setState(() {
            final idx = _myPosts.indexWhere((p) => p.postId == post.postId);
            if (idx != -1) {
              final newCount = (_myPosts[idx].commentCount + delta) < 0
                  ? 0
                  : _myPosts[idx].commentCount + delta;
              _myPosts[idx] = _myPosts[idx].copyWith(commentCount: newCount);
            }
          });
        },
      ),
    );
  }

  Future<void> _openEditMyPost(PostModel post) async {
    final updated = await Navigator.of(context).push<PostModel>(
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(
          authNotifier: widget.authNotifier,
          editingPost: post,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        final index = _myPosts.indexWhere((p) => p.postId == updated.postId);
        if (index != -1) {
          _myPosts[index] = updated;
        }
      });
    }
  }

  Future<void> _deleteMyPost(PostModel post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa bài viết này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final token = widget.authNotifier.token;
    if (token == null) return;

    try {
      await _postRepository.deletePost(post.postId, token: token);
      if (mounted) {
        setState(() {
          _myPosts.removeWhere((p) => p.postId == post.postId);
        });
        AppSyncBus.emitPostDeleted(post.postId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa bài viết thành công')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể xóa bài viết')),
        );
      }
    }
  }

  Widget _buildMyPostsTab() {
    if (_loadingPosts && _myPosts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_postsError != null && _myPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_postsError!, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _loadMyPosts(refresh: true),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_myPosts.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.article_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Chưa có bài viết nào',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Chia sẻ trải nghiệm và câu chuyện du lịch của bạn với cộng đồng!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () async {
                  final newPost = await Navigator.of(context).push<PostModel>(
                    MaterialPageRoute(
                      builder: (_) => CreatePostScreen(
                        authNotifier: widget.authNotifier,
                      ),
                    ),
                  );
                  if (newPost != null) {
                    _loadMyPosts(refresh: true);
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tạo bài viết mới'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadMyPosts(refresh: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200 &&
              !_loadingPosts &&
              _hasMorePosts) {
            _loadMyPosts();
          }
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: _myPosts.length + (_hasMorePosts ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index >= _myPosts.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final post = _myPosts[index];
            return PostCardWidget(
              post: post,
              onLike: () => _likeMyPost(post),
              onComment: () => _openPostComments(post),
              onEdit: () => _openEditMyPost(post),
              onDelete: () => _deleteMyPost(post),
              onItineraryTap: (itineraryId) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ItineraryDetailScreen(
                      itineraryId: itineraryId,
                      token: widget.authNotifier.token,
                      authNotifier: widget.authNotifier,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildItinerariesTab() {
    if (_itineraries.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.luggage_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Chưa có lịch trình công khai',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Lịch trình công khai của bạn sẽ xuất hiện tại đây.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MyItinerariesScreen(
                        authNotifier: widget.authNotifier,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.luggage_outlined, size: 18),
                label: const Text('Xem tất cả lịch trình của tôi'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _itineraries.length,
      itemBuilder: (context, index) {
        final item = _itineraries[index];
        return ItineraryCard(
          itinerary: item,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ItineraryDetailScreen(
                  itineraryId: item.itineraryId,
                  initialSummary: item,
                  token: widget.authNotifier.token,
                  authNotifier: widget.authNotifier,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _editor() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              const Text(
                'Chỉnh sửa hồ sơ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cập nhật thông tin cá nhân của bạn',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              AppTextField(
                label: 'Họ và tên',
                hint: 'Nhập họ và tên đầy đủ',
                controller: _fullNameController,
                textInputAction: TextInputAction.next,
                errorText: _validationErrors?['fullName'],
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Vui lòng nhập họ và tên'
                    : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Định danh công khai (@handle)',
                hint: 'Ví dụ: minhdanh.travel',
                controller: _handleController,
                textInputAction: TextInputAction.next,
                errorText: _validationErrors?['handle'],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Vui lòng nhập định danh handle';
                  }
                  var trimmed = v.trim().toLowerCase();
                  if (trimmed.startsWith('@')) {
                    trimmed = trimmed.substring(1).trim();
                  }
                  if (trimmed.length < 3 || trimmed.length > 30) {
                    return 'Handle phải từ 3 đến 30 ký tự';
                  }
                  if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(trimmed)) {
                    return 'Chỉ chấp nhận chữ thường, số, dấu chấm và gạch dưới';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ImageUploadPreview(
                circular: true,
                selectedBytes: _selectedAvatarBytes,
                imageUrl: _profile?['avatar']?.toString(),
                buttonLabel: _selectedAvatar == null
                    ? 'Chọn ảnh đại diện'
                    : 'Chọn ảnh khác',
                onPick: _pickAvatar,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Số điện thoại',
                hint: 'Ví dụ: 0912345678',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                errorText: _validationErrors?['phone'],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Địa chỉ',
                hint: 'Ví dụ: TP. Hồ Chí Minh, Việt Nam',
                controller: _addressController,
                textInputAction: TextInputAction.next,
                errorText: _validationErrors?['address'],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Giới thiệu',
                hint: 'Chia sẻ ngắn về sở thích du lịch của bạn...',
                controller: _bioController,
                maxLines: 3,
                minLines: 2,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                errorText: _validationErrors?['bio'],
              ),
              const SizedBox(height: 28),
              AppPrimaryButton(
                text: 'Lưu thay đổi',
                isLoading: _saving,
                onPressed: _saveProfile,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _saving
                    ? null
                    : () {
                        _fillFields(_profile!);
                        setState(() => _editing = false);
                      },
                child: const Text('Hủy'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
