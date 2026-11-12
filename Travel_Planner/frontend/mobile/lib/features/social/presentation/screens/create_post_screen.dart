import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
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

  const CreatePostScreen({
    super.key,
    required this.authNotifier,
    this.repository,
    this.notifier,
    this.itineraryRepository,
    this.editingPost,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  late final TextEditingController _contentController;
  late final CommunityPostRepository _repo;
  late final ItineraryCrudRepository _itineraryRepo;

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
    _contentController = TextEditingController(text: widget.editingPost?.content ?? '');

    if (widget.editingPost != null) {
      _visibility = widget.editingPost!.visibility;
      _existingItinerary = widget.editingPost!.itinerary;
      for (int i = 0; i < widget.editingPost!.mediaUrls.length; i++) {
        _mediaItems.add(_UploadedMediaItem(
          mediaAssetId: i < widget.editingPost!.mediaAssetIds.length ? widget.editingPost!.mediaAssetIds[i] : null,
          url: widget.editingPost!.mediaUrls[i],
        ));
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_mediaItems.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tối đa 5 ảnh cho mỗi bài viết')),
      );
      return;
    }

    final picker = ImagePicker();
    final token = widget.authNotifier.token;
    if (token == null) return;

    try {
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isEmpty) return;

      final remainingSlots = 5 - _mediaItems.length;
      final filesToUpload = pickedFiles.take(remainingSlots).toList();

      setState(() => _isUploading = true);

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
          if (assetId != null && mounted) {
            setState(() {
              _mediaItems.add(_UploadedMediaItem(
                mediaAssetId: assetId,
                url: result['secureUrl'] as String? ?? '',
                bytes: bytes,
              ));
            });
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Một số ảnh tải lên thất bại. Vui lòng thử lại.')),
            );
          }
        }
      }
    } catch (_) {
      // Ignored or picker cancelled
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaItems.removeAt(index);
    });
  }

  Future<void> _pickItinerary() async {
    final token = widget.authNotifier.token;
    if (token == null) return;

    final selected = await showModalBottomSheet<ItinerarySummary>(
      context: context,
      isScrollControlled: true,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tải ảnh lên, vui lòng chờ trong giây lát...')),
      );
      return;
    }

    final content = _contentController.text.trim();
    final assetIds = _mediaItems
        .map((m) => m.mediaAssetId)
        .whereType<int>()
        .toList();
    final hasItinerary = _selectedItinerary != null || _existingItinerary != null;

    if (content.isEmpty && assetIds.isEmpty && !hasItinerary) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung, thêm ảnh hoặc đính kèm lịch trình')),
      );
      return;
    }

    final token = widget.authNotifier.token;
    if (token == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      if (widget.editingPost != null) {
        // Update Post
        final updated = await _repo.updatePost(
          widget.editingPost!.postId,
          content: content,
          visibility: _visibility,
          token: token,
        );
        widget.notifier?.updatePostInList(updated);
        if (mounted) {
          Navigator.pop(context, updated);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chỉnh sửa bài viết thành công')),
          );
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
        if (mounted) {
          Navigator.pop(context, created);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng bài viết thành công')),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authNotifier.currentUser;
    final fullName = user?['fullName'] ?? user?['username'] ?? 'Người dùng';
    final avatar = user?['avatar'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.editingPost != null ? 'Chỉnh sửa bài viết' : 'Tạo bài viết',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(64, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: (_isSubmitting || _isUploading) ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(widget.editingPost != null ? 'Lưu' : 'Đăng'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header + Visibility Selector
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.surfaceStrong,
                  backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar == null || avatar.isEmpty
                      ? const Icon(Icons.person, color: AppColors.muted)
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.hairline),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _visibility,
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          onChanged: (val) {
                            if (val != null) setState(() => _visibility = val);
                          },
                          items: const [
                            DropdownMenuItem(
                              value: 'PUBLIC',
                              child: Row(
                                children: [
                                  Icon(Icons.public, size: 14),
                                  SizedBox(width: 6),
                                  Text('Công khai'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'FRIENDS',
                              child: Row(
                                children: [
                                  Icon(Icons.group_outlined, size: 14),
                                  SizedBox(width: 6),
                                  Text('Bạn bè'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'PRIVATE',
                              child: Row(
                                children: [
                                  Icon(Icons.lock_outline, size: 14),
                                  SizedBox(width: 6),
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
              ],
            ),
            const SizedBox(height: 16),

            // Content Text Field
            TextField(
              controller: _contentController,
              maxLines: 8,
              minLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'Bạn đang nghĩ gì về chuyến đi của mình? Chia sẻ khoảnh khắc, mẹo du lịch hoặc lịch trình...',
                hintStyle: TextStyle(color: AppColors.muted, fontSize: 15),
                border: InputBorder.none,
              ),
            ),

            // Selected Media Thumbnails Row
            if (_mediaItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _mediaItems.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final item = _mediaItems[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
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
                                ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => _removeMedia(index),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
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
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Đang tải ảnh lên...', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ],

            // Attached Itinerary Preview (if selected)
            if (_selectedItinerary != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairlineSoft),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _selectedItinerary!.coverImage != null
                          ? Image.network(
                              _selectedItinerary!.coverImage!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 50,
                                height: 50,
                                color: AppColors.surfaceStrong,
                                child: const Icon(Icons.map_outlined),
                              ),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              color: AppColors.surfaceStrong,
                              child: const Icon(Icons.map_outlined),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedItinerary!.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${_selectedItinerary!.totalDays} ngày • ${_selectedItinerary!.location}',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _selectedItinerary = null),
                    ),
                  ],
                ),
              ),
            ] else if (_existingItinerary != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairlineSoft),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.map_outlined, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _existingItinerary!.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Divider(color: AppColors.hairlineSoft),

            // Action Attachment Buttons
            if (widget.editingPost == null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.photo_library_outlined, color: Colors.green),
                title: Text(
                  'Thêm ảnh (${_mediaItems.length}/5)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: _isUploading ? null : _pickImages,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.map_outlined, color: AppColors.primary),
                title: const Text(
                  'Đính kèm lịch trình',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: _pickItinerary,
              ),
            ],
          ],
        ),
      ),
    );
  }
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chọn lịch trình để đính kèm',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Expanded(
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
          ),
        ],
      ),
    );
  }
}
