import 'package:flutter/material.dart';
import 'package:mobile/shared/widgets/app_bottom_sheet.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';

import '../../../../shared/widgets/app_toast.dart';
import '../../data/community_post_repository.dart';

class ReportPostDialog extends StatefulWidget {
  final int postId;
  final String token;
  final CommunityPostRepository repository;
  final bool isBottomSheet;

  const ReportPostDialog({
    super.key,
    required this.postId,
    required this.token,
    required this.repository,
    this.isBottomSheet = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int postId,
    required String token,
    required CommunityPostRepository repository,
  }) {
    return AppBottomSheet.show<bool>(
      context,
      showDragHandle: true,
      builder: (_) => ReportPostDialog(
        postId: postId,
        token: token,
        repository: repository,
        isBottomSheet: true,
      ),
    );
  }

  @override
  State<ReportPostDialog> createState() => _ReportPostDialogState();
}

class _ReportPostDialogState extends State<ReportPostDialog> {
  final List<String> _reasons = const [
    'Nội dung phản cảm hoặc khiêu dâm',
    'Spam hoặc quảng cáo sai sự thật',
    'Ngôn từ thù địch hoặc quấy rối',
    'Thông tin sai lệch hoặc lừa đảo',
    'Khác',
  ];

  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  final FocusNode _detailsFocus = FocusNode();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedReason = _reasons[0];
    _detailsFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _detailsFocus.removeListener(_onFocusChange);
    _detailsFocus.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      await widget.repository.reportPost(
        widget.postId,
        reason: _selectedReason!,
        details: _detailsController.text.trim().isNotEmpty
            ? _detailsController.text.trim()
            : null,
        token: widget.token,
      );

      if (mounted) {
        Navigator.pop(context, true);
        AppToast.showSuccess(
          context,
          'Cảm ơn bạn đã báo cáo. Chúng tôi sẽ xem xét trong thời gian sớm nhất.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        AppToast.showError(
          context,
          'Không thể gửi báo cáo. Vui lòng thử lại sau.',
        );
      }
    }
  }

  Widget _buildContent(BuildContext context) {
    final canSubmit = _selectedReason != null && !_submitting;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          widget.isBottomSheet ? 4 : 20,
          20,
          (widget.isBottomSheet ? 20 + bottomInset : 20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF0F3),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: Color(0xFFFA3E62),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Báo cáo bài viết',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                ),
                BounceTap.icon(
                  child: Material(
                    color: const Color(0xFFF4F5F7),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _submitting ? null : () => Navigator.pop(context),
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Vui lòng chọn lý do bài viết này vi phạm tiêu chuẩn cộng đồng:',
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF6E6E73),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),

            // Selectable Reason Cards
            for (var i = 0; i < _reasons.length; i++) ...[
              _buildReasonCard(_reasons[i]),
              if (i < _reasons.length - 1) const SizedBox(height: 8),
            ],
            const SizedBox(height: 14),

            // Optional Details TextField
            TextField(
              controller: _detailsController,
              focusNode: _detailsFocus,
              maxLines: 3,
              minLines: 2,
              style: const TextStyle(fontSize: 14.5, color: Color(0xFF1E1E1E)),
              decoration: InputDecoration(
                hintText: 'Thêm thông tin chi tiết (tùy chọn)...',
                hintStyle: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF8E8E93),
                ),
                filled: true,
                fillColor: _detailsFocus.hasFocus
                    ? Colors.white
                    : const Color(0xFFF7F8FA),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFEBEBEF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFEBEBEF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFFA3E62),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Equal 2-button bottom row
            Row(
              children: [
                Expanded(
                  child: BounceTap(
                    enabled: !_submitting,
                    child: Material(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: _submitting ? null : () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(14),
                        child: const SizedBox(
                          height: 46,
                          child: Center(
                            child: Text(
                              'Hủy',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BounceTap(
                    enabled: canSubmit,
                    child: Material(
                      color: canSubmit
                          ? const Color(0xFFFA3E62)
                          : const Color(0xFFFAD2DA),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: canSubmit ? _submitReport : null,
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          height: 46,
                          child: Center(
                            child: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : const Text(
                                    'Gửi báo cáo',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonCard(String reason) {
    final isSelected = _selectedReason == reason;
    return BounceTap(
      useSelectionHaptic: true,
      child: Material(
        color: isSelected ? const Color(0xFFFFF0F3) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _submitting ? null : () => setState(() => _selectedReason = reason),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFA3E62)
                    : const Color(0xFFEBEBEF),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    reason,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? const Color(0xFF1E1E1E)
                          : const Color(0xFF374151),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (isSelected)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFA3E62),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  )
                else
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF9CA3AF),
                        width: 1.5,
                      ),
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
    if (widget.isBottomSheet) {
      return _buildContent(context);
    }

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: _buildContent(context),
    );
  }
}
