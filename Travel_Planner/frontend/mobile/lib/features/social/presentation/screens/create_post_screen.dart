import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/sync/app_sync_bus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_page_title.dart';
import '../../../../shared/widgets/app_toast.dart';
import 'package:mobile/shared/widgets/app_header_button.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../itinerary/data/itinerary_crud_repository.dart';
import '../../../explore/data/models/itinerary_summary.dart';
import '../community_feed_notifier.dart';
import '../../data/community_post_repository.dart';
import '../../data/models/post_model.dart';

class CreatePostScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final CommunityPostRepository? repository;
  final CommunityFeedNotifier? notifier;
  final ItineraryCrudRepository? itineraryRepository;
  final PostModel? editingPost;
  final ImagePicker? imagePicker;

  const CreatePostScreen({
    super.key,
    required this.authNotifier,
    this.repository,
    this.notifier,
    this.itineraryRepository,
    this.editingPost,
    this.imagePicker,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  late final TextEditingController _contentController;
  late final CommunityPostRepository _repo;
  late final ItineraryCrudRepository _itineraryRepo;
  late final ImagePicker _picker;

  String _visibility = 'PUBLIC';
  final List<_UploadedMediaItem> _mediaItems = [];
  ItinerarySummary? _selectedItinerary;
  PostItineraryModel? _existingItinerary;

  bool _isUploading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? CommunityPostRepository();
    _itineraryRepo = widget.itineraryRepository ?? ItineraryCrudRepository();
    _picker = widget.imagePicker ?? ImagePicker();
    _contentController = TextEditingController(text: widget.editingPost?.content ?? '');

    if (widget.editingPost != null) {
      _visibility = widget.editingPost!.visibility;
      _existingItinerary = widget.editingPost!.itinerary;
      for (int i = 0; i < widget.editingPost!.mediaUrls.length; i++) {
        final assetId = i < widget.editingPost!.mediaAssetIds.length ? widget.editingPost!.mediaAssetIds[i] : null;
        _mediaItems.add(_UploadedMediaItem(
          mediaAssetId: (assetId != null && assetId > 0) ? assetId : null,
          url: widget.editingPost!.mediaUrls[i],
        ));
      }
      if (widget.editingPost!.mediaUrls.isNotEmpty &&
          _mediaItems.any((m) => m.mediaAssetId == null || m.mediaAssetId! <= 0)) {
        _fetchFreshPostMedia();
      }
    }
  }

  Future<void> _fetchFreshPostMedia() async {
    final token = widget.authNotifier.token;
    final postId = widget.editingPost?.postId;
    if (postId == null) return;
    try {
      final fresh = await _repo.getPostById(postId, token: token);
      if (fresh.mediaAssetIds.isNotEmpty && mounted) {
        setState(() {
          for (int i = 0; i < _mediaItems.length; i++) {
            if (_mediaItems[i].mediaAssetId == null || _mediaItems[i].mediaAssetId! <= 0) {
              final url = _mediaItems[i].url;
              final matchIdx = fresh.mediaUrls.indexOf(url);
              if (matchIdx != -1 && matchIdx < fresh.mediaAssetIds.length) {
                _mediaItems[i] = _UploadedMediaItem(
                  mediaAssetId: fresh.mediaAssetIds[matchIdx],
                  url: url,
                  bytes: _mediaItems[i].bytes,
                );
              } else if (i < fresh.mediaAssetIds.length) {
                _mediaItems[i] = _UploadedMediaItem(
                  mediaAssetId: fresh.mediaAssetIds[i],
                  url: url,
                  bytes: _mediaItems[i].bytes,
                );
              }
            }
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_isUploading) return;
    if (_mediaItems.length >= 5) {
      AppToast.showWarning(context, 'Tối đa 5 ảnh cho mỗi bài viết');
      return;
    }

    final token = widget.authNotifier.token;
    if (token == null) return;

    List<XFile> pickedFiles = [];
    try {
      pickedFiles = await _picker.pickMultiImage();
    } catch (_) {
      try {
        final single = await _picker.pickImage(source: ImageSource.gallery);
        if (single != null) {
          pickedFiles = [single];
        }
      } catch (_) {}
    }

    if (pickedFiles.isEmpty) return;

    final remainingSlots = 5 - _mediaItems.length;
    final filesToUpload = pickedFiles.take(remainingSlots).toList();
    if (filesToUpload.isEmpty) return;

    setState(() => _isUploading = true);

    try {
      for (final file in filesToUpload) {
        final bytes = await file.readAsBytes();
        final filename = file.name.isNotEmpty ? file.name : 'upload.jpg';

        try {
          final result = await _repo.uploadImage(
            bytes: bytes,
            filename: filename,
            token: token,
          );
          final assetId = result['mediaAssetId'] is int
              ? result['mediaAssetId'] as int
              : int.tryParse('${result['mediaAssetId']}');
          final secureUrl = result['secureUrl'] as String? ?? '';
          if (assetId != null && assetId > 0 && mounted) {
            setState(() {
              _mediaItems.add(_UploadedMediaItem(
                mediaAssetId: assetId,
                url: secureUrl,
                bytes: bytes,
              ));
            });
          }
        } catch (e) {
          if (mounted) {
            AppToast.showError(
              context,
              'Một số ảnh tải lên thất bại. Vui lòng thử lại.',
            );
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaItems.removeAt(index);
    });
  }

  Future<void> _replaceMedia(int index) async {
    if (_isUploading) return;
    final token = widget.authNotifier.token;
    if (token == null) return;

    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      setState(() => _isUploading = true);
      final bytes = await pickedFile.readAsBytes();
      final filename = pickedFile.name.isNotEmpty ? pickedFile.name : 'replace.jpg';

      final result = await _repo.uploadImage(
        bytes: bytes,
        filename: filename,
        token: token,
      );
      final assetId = result['mediaAssetId'] is int
          ? result['mediaAssetId'] as int
          : int.tryParse('${result['mediaAssetId']}');
      final secureUrl = result['secureUrl'] as String? ?? '';
      if (assetId != null && assetId > 0 && mounted) {
        setState(() {
          _mediaItems[index] = _UploadedMediaItem(
            mediaAssetId: assetId,
            url: secureUrl,
            bytes: bytes,
          );
        });
      }
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          context,
          'Không thể thay thế ảnh. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickItinerary() async {
    final token = widget.authNotifier.token;
    if (token == null) return;

    final selected = await AppBottomSheet.show<ItinerarySummary>(
      context,
      title: 'Chọn lịch trình để đính kèm',
      builder: (ctx) => _ItinerarySelectionSheet(
        token: token,
        repository: _itineraryRepo,
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedItinerary = selected;
        _existingItinerary = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_isUploading) {
      AppToast.showInfo(
        context,
        'Đang tải ảnh lên, vui lòng chờ trong giây lát...',
      );
      return;
    }

    final token = widget.authNotifier.token;
    if (token == null || _isSubmitting) return;

    if (widget.editingPost != null &&
        _mediaItems.any((m) => m.mediaAssetId == null || m.mediaAssetId! <= 0)) {
      await _fetchFreshPostMedia();
    }

    final content = _contentController.text.trim();
    final assetIds = _mediaItems
        .map((m) => m.mediaAssetId)
        .whereType<int>()
        .where((id) => id > 0)
        .toList();
    final hasItinerary = _selectedItinerary != null || _existingItinerary != null;

    if (content.isEmpty && _mediaItems.isEmpty && !hasItinerary) {
      if (mounted) {
        AppToast.showWarning(
          context,
          'Vui lòng nhập nội dung, thêm ảnh hoặc đính kèm lịch trình',
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (widget.editingPost != null) {
        // Update Post
        final bool detachItinerary = (_selectedItinerary == null && _existingItinerary == null && widget.editingPost?.itinerary != null);
        final int? itineraryId = _selectedItinerary?.itineraryId;

        final updated = await _repo.updatePost(
          widget.editingPost!.postId,
          content: content,
          visibility: _visibility,
          mediaAssetIds: assetIds,
          itineraryId: itineraryId,
          detachItinerary: detachItinerary,
          token: token,
        );
        widget.notifier?.updatePostInList(updated);
        AppSyncBus.emitPostUpdated(updated, widget.editingPost!.postId);
        if (mounted) {
          Navigator.pop(context, updated);
          AppToast.showSuccess(context, 'Chỉnh sửa bài viết thành công');
        }
      } else {
        // Create Post
        final created = await _repo.createPost(
          content: content,
          visibility: _visibility,
          itineraryId: _selectedItinerary?.itineraryId,
          mediaAssetIds: assetIds.isNotEmpty ? assetIds : null,
          token: token,
        );

        widget.notifier?.addPost(created);
        AppSyncBus.emitPostCreated(created);
        if (mounted) {
          Navigator.pop(context, created);
          AppToast.showSuccess(context, 'Đăng bài viết thành công');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final errorMsg = e is ApiException
            ? e.message
            : (e is Exception
                ? e.toString().replaceFirst('Exception: ', '')
                : 'Không thể đăng bài viết. Vui lòng thử lại.');
        AppToast.showError(context, errorMsg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authNotifier.currentUser;
    final fullName = user?['fullName'] ?? user?['username'] ?? 'Người dùng';
    final avatar = user?['avatar'] as String?;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          leadingWidth: 58,
          leading: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Center(child: AppHeaderBackButton()),
          ),
          title: AppPageTitle(
            title: widget.editingPost != null ? 'Chỉnh sửa bài viết' : 'Tạo bài viết',
            fontSize: 18,
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E1E1E),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 0.5,
              color: const Color(0xFFF0F0F5),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: BounceTap(
                enabled: !(_isSubmitting || _isUploading),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFA3E62),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(68, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  onPressed: (_isSubmitting || _isUploading) ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          widget.editingPost != null ? 'Lưu' : 'Đăng',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author Avatar + Name + Compact Visibility Pill
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceStrong,
                            border: Border.all(color: const Color(0xFFEFEFF4)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: avatar != null && avatar.isNotEmpty
                              ? Image.network(
                                  avatar,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.person,
                                    color: AppColors.muted,
                                  ),
                                )
                              : const Icon(Icons.person, color: AppColors.muted),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                  color: Color(0xFF1E1E1E),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 28,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F5F7),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _visibility,
                                    isDense: true,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: Color(0xFF4B5563),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E1E1E),
                                    ),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _visibility = val);
                                      }
                                    },
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'PUBLIC',
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.public, size: 14, color: Color(0xFF4B5563)),
                                            SizedBox(width: 5),
                                            Text('Công khai'),
                                          ],
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'FRIENDS',
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.group_outlined, size: 14, color: Color(0xFF4B5563)),
                                            SizedBox(width: 5),
                                            Text('Bạn bè'),
                                          ],
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'PRIVATE',
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.lock_outline, size: 14, color: Color(0xFF4B5563)),
                                            SizedBox(width: 5),
                                            Text('Chỉ mình tôi'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Clean Borderless Composer
                    TextField(
                      controller: _contentController,
                      maxLines: 10,
                      minLines: 4,
                      maxLength: 2000,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Color(0xFF1E1E1E),
                      ),
                      decoration: const InputDecoration(
                        hintText:
                            'Bạn đang nghĩ gì về chuyến đi của mình? Chia sẻ khoảnh khắc, mẹo du lịch hoặc lịch trình...',
                        hintStyle: TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 15.5,
                          height: 1.45,
                        ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        counterText: '',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_contentController.text.length}/2000',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ),

                    // Selected Media Thumbnails Row + Dashed "Thêm ảnh"
                    if (_mediaItems.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount:
                              _mediaItems.length + (_mediaItems.length < 5 ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            if (index == _mediaItems.length) {
                              return BounceTap(
                                enabled: !(_isUploading || _mediaItems.length >= 5),
                                child: InkWell(
                                  onTap: (_isUploading || _mediaItems.length >= 5)
                                      ? null
                                      : _pickImages,
                                  borderRadius: BorderRadius.circular(14),
                                  child: CustomPaint(
                                    painter: _DashedBorderPainter(
                                      color: const Color(0xFFFAD2DA),
                                      borderRadius: 14,
                                    ),
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF8F9),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate_outlined,
                                            color: Color(0xFFFA3E62),
                                            size: 26,
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Thêm ảnh',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFFA3E62),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            final item = _mediaItems[index];
                            return Stack(
                              children: [
                                BounceTap(
                                  child: InkWell(
                                    onTap: () => _replaceMedia(index),
                                    borderRadius: BorderRadius.circular(14),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: item.bytes != null
                                          ? Image.memory(
                                              item.bytes!,
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.network(
                                              item.url,
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Container(
                                                width: 100,
                                                height: 100,
                                                color: AppColors.surfaceStrong,
                                                child: const Icon(
                                                  Icons.broken_image_outlined,
                                                  color: AppColors.muted,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 5,
                                  right: 5,
                                  child: BounceTap.icon(
                                    child: GestureDetector(
                                      onTap: () => _removeMedia(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.55),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 5,
                                  right: 5,
                                  child: BounceTap.icon(
                                    child: GestureDetector(
                                      onTap: () => _replaceMedia(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.55),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.swap_horiz,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],

                    if (_isUploading) ...[
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFA3E62),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Đang tải ảnh lên...',
                            style: TextStyle(color: Color(0xFF6E6E73), fontSize: 13),
                          ),
                        ],
                      ),
                    ],

                    // Attached Itinerary Mini Preview Card
                    if (_selectedItinerary != null) ...[
                      const SizedBox(height: 16),
                      _buildAttachedItineraryCard(
                        title: _selectedItinerary!.title,
                        subtitle:
                            '${_selectedItinerary!.totalDays} ngày • ${_selectedItinerary!.location}',
                        coverImage: _selectedItinerary!.coverImage,
                        onDetach: () => setState(() => _selectedItinerary = null),
                      ),
                    ] else if (_existingItinerary != null) ...[
                      const SizedBox(height: 16),
                      _buildAttachedItineraryCard(
                        title: _existingItinerary!.title,
                        subtitle: 'Lịch trình đính kèm',
                        coverImage: _existingItinerary!.coverImage,
                        onDetach: () => setState(() => _existingItinerary = null),
                      ),
                    ],
                  ],
                ),
              ),

              // Section Divider
              Container(
                height: 8,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  border: Border(
                    top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
                    bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
                  ),
                ),
              ),

              // Bottom Action Rows (no duplicate "Thêm ảnh" when images already exist)
              if (_mediaItems.isEmpty)
                _buildToolbarRow(
                  icon: Icons.photo_library_outlined,
                  iconColor: const Color(0xFF059669),
                  badgeBgColor: const Color(0xFFECFDF5),
                  label: 'Thêm ảnh (tối đa 5 ảnh)',
                  onTap: _isUploading ? null : _pickImages,
                ),
              _buildToolbarRow(
                icon: Icons.map_outlined,
                iconColor: const Color(0xFFFA3E62),
                badgeBgColor: const Color(0xFFFFF0F3),
                label: (_selectedItinerary != null || _existingItinerary != null)
                    ? 'Thay đổi lịch trình'
                    : 'Đính kèm lịch trình',
                onTap: _pickItinerary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachedItineraryCard({
    required String title,
    required String subtitle,
    String? coverImage,
    required VoidCallback onDetach,
  }) {
    final hasCover = coverImage != null && coverImage.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEBEBEF)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F3),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasCover
                ? Image.network(
                    coverImage.trim(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.map_outlined,
                      color: Color(0xFFFA3E62),
                    ),
                  )
                : const Icon(Icons.map_outlined, color: Color(0xFFFA3E62)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6E6E73),
                  ),
                ),
              ],
            ),
          ),
          BounceTap.icon(
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF6E6E73)),
              tooltip: 'Gỡ lịch trình',
              onPressed: onDetach,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarRow({
    required IconData icon,
    required Color iconColor,
    required Color badgeBgColor,
    required String label,
    VoidCallback? onTap,
  }) {
    return BounceTap(
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 19, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF8E8E93),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;

  const _DashedBorderPainter({
    required this.color,
    this.borderRadius = 14,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);
    const dashWidth = 6.0;
    const dashSpace = 4.0;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderRadius != borderRadius;
}

class _UploadedMediaItem {
  final int? mediaAssetId;
  final String url;
  final Uint8List? bytes;

  _UploadedMediaItem({
    this.mediaAssetId,
    required this.url,
    this.bytes,
  });
}

class _ItinerarySelectionSheet extends StatefulWidget {
  final String token;
  final ItineraryCrudRepository repository;

  const _ItinerarySelectionSheet({
    required this.token,
    required this.repository,
  });

  @override
  State<_ItinerarySelectionSheet> createState() => _ItinerarySelectionSheetState();
}

class _ItinerarySelectionSheetState extends State<_ItinerarySelectionSheet> {
  List<ItinerarySummary> _itineraries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await widget.repository.getMyItineraries(token: widget.token);
      if (mounted) {
        setState(() {
          _itineraries = res.content.where((it) => (it.status ?? '').toUpperCase() == 'ACTIVE').toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _itineraries.isEmpty
              ? const Center(
                  child: Text(
                    'Bạn chưa có lịch trình công khai nào.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView.separated(
                  itemCount: _itineraries.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final item = _itineraries[i];
                    return ListTile(
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${item.totalDays} ngày • ${item.location.isNotEmpty ? item.location : "Chưa có địa điểm"}'),
                      trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                      onTap: () => Navigator.pop(ctx, item),
                    );
                  },
                ),
    );
  }
}
