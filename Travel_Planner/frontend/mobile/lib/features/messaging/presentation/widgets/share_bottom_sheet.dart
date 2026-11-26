import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_toast.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../profile/data/models/public_user_summary.dart';
import '../../data/messaging_repository.dart';
import '../../data/models/share_batch_models.dart';
import '../../data/models/user_search_result.dart';

class ShareRecipientItem {
  final int userId;
  final String handle;
  final String? fullName;
  final String? avatar;

  const ShareRecipientItem({
    required this.userId,
    required this.handle,
    this.fullName,
    this.avatar,
  });

  String get displayName =>
      (fullName != null && fullName!.trim().isNotEmpty) ? fullName! : '@$handle';

  factory ShareRecipientItem.fromPublicUser(PublicUserSummary user) =>
      ShareRecipientItem(
        userId: user.userId,
        handle: user.effectiveHandle,
        fullName: user.fullName,
        avatar: user.avatar,
      );

  factory ShareRecipientItem.fromSearchResult(UserSearchResult result) =>
      ShareRecipientItem(
        userId: result.userId,
        handle: result.handle,
        fullName: result.fullName,
        avatar: result.avatar,
      );
}

class ShareBottomSheet extends StatefulWidget {
  final String targetType; // 'ITINERARY' or 'POST'
  final int targetId;
  final String title;
  final String? coverImage;
  final String? subtitle;
  final AuthNotifier? authNotifier;
  final MessagingRepository? messagingRepository;

  const ShareBottomSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.title,
    this.coverImage,
    this.subtitle,
    this.authNotifier,
    this.messagingRepository,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String targetType,
    required int targetId,
    required String title,
    String? coverImage,
    String? subtitle,
    AuthNotifier? authNotifier,
    MessagingRepository? messagingRepository,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareBottomSheet(
        targetType: targetType,
        targetId: targetId,
        title: title,
        coverImage: coverImage,
        subtitle: subtitle,
        authNotifier: authNotifier,
        messagingRepository: messagingRepository,
      ),
    );
  }

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  late final MessagingRepository _repository =
      widget.messagingRepository ?? MessagingRepository();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final Set<int> _selectedUserIds = {};
  final Map<int, ShareRecipientItem> _selectedUsersMap = {};

  late final String _shareBatchId =
      'batch_${DateTime.now().microsecondsSinceEpoch}_${widget.targetType}_${widget.targetId}';

  List<ShareRecipientItem> _recipients = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isSending = false;
  bool _hasSentAnySuccess = false;
  String? _error;
  Timer? _debounceTimer;

  int? get _currentUserId {
    final rawId = widget.authNotifier?.currentUser?['userId'];
    return rawId != null ? int.tryParse('$rawId') : null;
  }

  String? get _token => widget.authNotifier?.token;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    if (_token == null) {
      setState(() {
        _isLoading = false;
        _error = 'Vui lòng đăng nhập để chia sẻ nội dung';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _repository.friends(_token!);
      if (!mounted) return;
      final friends = result.content
          .where((u) => u.userId != _currentUserId)
          .map(ShareRecipientItem.fromPublicUser)
          .toList();

      setState(() {
        _recipients = friends;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Không thể tải danh sách bạn bè. Vui lòng thử tìm kiếm.';
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _loadFriends();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || _token == null) return;
      setState(() {
        _isSearching = true;
        _error = null;
      });

      try {
        final result = await _repository.searchUsers(trimmed, _token!);
        if (!mounted) return;
        final list = result.content
            .where((u) => !u.isSelf && u.userId != _currentUserId)
            .map(ShareRecipientItem.fromSearchResult)
            .toList();

        setState(() {
          _recipients = list;
          _isSearching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isSearching = false;
          _error = 'Lỗi tìm kiếm người dùng';
        });
      }
    });
  }

  void _toggleSelection(ShareRecipientItem item) {
    setState(() {
      if (_selectedUserIds.contains(item.userId)) {
        _selectedUserIds.remove(item.userId);
        _selectedUsersMap.remove(item.userId);
      } else {
        if (_selectedUserIds.length >= 10) {
          AppToast.showWarning(
            context,
            'Chỉ được chọn tối đa 10 người nhận mỗi lần',
            duration: const Duration(seconds: 2),
          );
          return;
        }
        _selectedUserIds.add(item.userId);
        _selectedUsersMap[item.userId] = item;
      }
    });
  }

  void _removeSelectedUser(int userId) {
    setState(() {
      _selectedUserIds.remove(userId);
      _selectedUsersMap.remove(userId);
    });
  }

  Future<void> _handleSend() async {
    if (_selectedUserIds.isEmpty || _isSending || _token == null) return;

    setState(() {
      _isSending = true;
      _error = null;
    });

    final request = ShareBatchRequest(
      targetType: widget.targetType,
      targetId: widget.targetId,
      recipientUserIds: _selectedUserIds.toList(),
      note: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
      shareBatchId: _shareBatchId,
    );

    try {
      final response = await _repository.shareContent(request, _token!);
      if (!mounted) return;

      if (response.isAllSuccess) {
        Navigator.of(context).pop(true);
      } else if (response.isPartialSuccess) {
        _hasSentAnySuccess = true;
        final successfulUserIds = response.results
            .where((r) => r.success)
            .map((r) => r.recipientUserId)
            .toSet();
        final failedNames = response.results
            .where((r) => !r.success)
            .map((r) => r.recipientFullName ?? '@${r.recipientUsername ?? 'user'}')
            .join(', ');

        setState(() {
          _isSending = false;
          _selectedUserIds.removeWhere((id) => successfulUserIds.contains(id));
          _selectedUsersMap.removeWhere((id, _) => successfulUserIds.contains(id));
          _error =
              'Đã gửi thành công cho ${response.successCount} người. Không thể gửi cho: $failedNames. Bạn có thể nhấn Gửi lại cho người chưa nhận được.';
        });
      } else {
        setState(() {
          _isSending = false;
          _error = response.results.isNotEmpty
              ? (response.results.first.errorMessage ?? 'Không thể gửi tin nhắn chia sẻ')
              : 'Chia sẻ không thành công';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _error = 'Có lỗi xảy ra khi chia sẻ. Vui lòng thử lại sau.';
      });
    }
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.hairlineSoft,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // 1. Header "Chia sẻ qua tin nhắn", nút đóng
  Widget _buildHeader() {
    final count = _selectedUserIds.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Chia sẻ qua tin nhắn',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count == 0
                      ? 'Chọn bạn bè để gửi'
                      : 'Đã chọn $count/10 người',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: count > 0 ? FontWeight.w600 : FontWeight.w400,
                    color: count == 10
                        ? Colors.red
                        : (count > 0 ? AppColors.primary : AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          BounceTap.icon(
            child: IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Đóng',
              onPressed: () =>
                  Navigator.of(context).pop(_hasSentAnySuccess ? true : null),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Preview bài đăng hoặc lịch trình đang được chia sẻ
  Widget _buildPreviewCard() {
    final isItinerary = widget.targetType.toUpperCase() == 'ITINERARY';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceStrong,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairlineSoft),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: (widget.coverImage != null && widget.coverImage!.isNotEmpty)
                ? Image.network(
                    widget.coverImage!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildFallbackCover(isItinerary),
                  )
                : _buildFallbackCover(isItinerary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isItinerary ? 'Lịch trình' : 'Bài viết',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                  Text(
                    widget.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackCover(bool isItinerary) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        isItinerary ? Icons.map_outlined : Icons.article_outlined,
        color: AppColors.primary,
        size: 22,
      ),
    );
  }

  // 5. Ô tìm kiếm bạn bè
  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm bạn bè...',
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.muted),
          suffixIcon: _searchController.text.isNotEmpty
              ? BounceTap.icon(
                  child: IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      _loadFriends();
                    },
                  ),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          filled: true,
          fillColor: AppColors.surfaceStrong,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // 6. Hiển thị những người đã chọn (Selected chips)
  Widget _buildSelectedRecipientsBar() {
    if (_selectedUserIds.isEmpty) return const SizedBox.shrink();

    final selectedList = _selectedUsersMap.values.toList();
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 2),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: selectedList.length,
          separatorBuilder: (context, index) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final user = selectedList[index];
            return Container(
              padding: const EdgeInsets.only(left: 4, right: 6, top: 2, bottom: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    backgroundImage: (user.avatar != null && user.avatar!.isNotEmpty)
                        ? NetworkImage(user.avatar!)
                        : null,
                    child: (user.avatar == null || user.avatar!.isEmpty)
                        ? const Icon(Icons.person, size: 14, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 100),
                    child: Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  BounceTap.icon(
                    child: GestureDetector(
                      onTap: () => _removeSelectedUser(user.userId),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // 3. Danh sách bạn bè hiển thị bằng avatar tròn và tên, cho phép vuốt ngang
  // 4. Nhấn avatar để chọn/bỏ chọn người nhận, hiển thị dấu tick khi được chọn
  Widget _buildFriendsAvatarRow() {
    if (_isLoading || _isSearching) {
      return const SizedBox(
        height: 105,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      );
    }

    final isQueryActive = _searchController.text.trim().isNotEmpty;
    final List<ShareRecipientItem> displayList = [];
    final seenIds = <int>{};

    if (isQueryActive) {
      for (final selectedUser in _selectedUsersMap.values) {
        if (seenIds.add(selectedUser.userId)) {
          displayList.add(selectedUser);
        }
      }
    }

    for (final r in _recipients) {
      if (seenIds.add(r.userId)) {
        displayList.add(r);
      }
    }

    if (displayList.isEmpty) {
      return SizedBox(
        height: 90,
        child: Center(
          child: Text(
            isQueryActive
                ? 'Không tìm thấy người dùng phù hợp'
                : 'Chưa có bạn bè trong danh sách.\nHãy nhập tên người dùng để tìm kiếm.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: displayList.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = displayList[index];
          final isSelected = _selectedUserIds.contains(item.userId);

          return BounceTap(
            useSelectionHaptic: true,
            child: GestureDetector(
              onTap: () => _toggleSelection(item),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 66,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.hairlineSoft,
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: CircleAvatar(
                            backgroundColor: AppColors.surfaceStrong,
                            backgroundImage: (item.avatar != null &&
                                    item.avatar!.isNotEmpty)
                                ? NetworkImage(item.avatar!)
                                : null,
                            child: (item.avatar == null ||
                                    item.avatar!.isEmpty)
                                ? const Icon(
                                    Icons.person,
                                    size: 26,
                                    color: AppColors.muted,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.displayName,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.15,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          );
        },
      ),
    );
  }

  // 7. Ô nhập lời nhắn tùy chọn
  Widget _buildNoteInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceStrong,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.hairlineSoft),
        ),
        child: TextField(
          controller: _noteController,
          minLines: 1,
          maxLines: 3,
          maxLength: 4000,
          decoration: const InputDecoration(
            hintText: 'Soạn tin nhắn...',
            hintStyle: TextStyle(fontSize: 13, color: AppColors.muted),
            counterText: '',
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  // 8. Nút "Gửi (N)" ở cuối giao diện
  Widget _buildSendButton() {
    final count = _selectedUserIds.length;
    final isEnabled = count > 0 && !_isSending;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: BounceTap(
          enabled: isEnabled,
          child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          onPressed: isEnabled ? _handleSend : null,
          child: _isSending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      count == 0 ? 'Gửi' : 'Gửi ($count)',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_hasSentAnySuccess ? true : null);
      },
      child: AnimatedPadding(
        padding: EdgeInsets.only(bottom: bottomInset),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDragHandle(),
                  _buildHeader(),
                  _buildPreviewCard(),
                  _buildSearchField(),
                  _buildSelectedRecipientsBar(),
                  const SizedBox(height: 6),
                  _buildFriendsAvatarRow(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 4),
                  _buildNoteInput(),
                  _buildSendButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
