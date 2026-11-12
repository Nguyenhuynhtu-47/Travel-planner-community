import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/community_post_repository.dart';

class ReportPostDialog extends StatefulWidget {
  final int postId;
  final String token;
  final CommunityPostRepository repository;

  const ReportPostDialog({
    super.key,
    required this.postId,
    required this.token,
    required this.repository,
  });

  @override
  State<ReportPostDialog> createState() => _ReportPostDialogState();
}

class _ReportPostDialogState extends State<ReportPostDialog> {
  final List<String> _reasons = [
    'Nội dung phản cảm hoặc khiêu dâm',
    'Spam hoặc quảng cáo sai sự thật',
    'Ngôn từ thù địch hoặc quấy rối',
    'Thông tin sai lệch hoặc lừa đảo',
    'Khác',
  ];

  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedReason = _reasons[0];
  }

  @override
  void dispose() {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cảm ơn bạn đã báo cáo. Chúng tôi sẽ xem xét trong thời gian sớm nhất.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể gửi báo cáo. Vui lòng thử lại sau.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Báo cáo bài viết',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vui lòng chọn lý do bài viết này vi phạm tiêu chuẩn cộng đồng:',
              style: TextStyle(fontSize: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            ..._reasons.map((reason) {
              return RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(reason, style: const TextStyle(fontSize: 14)),
                value: reason,
                groupValue: _selectedReason,
                activeColor: AppColors.primary,
                onChanged: (val) => setState(() => _selectedReason = val),
              );
            }),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Thêm thông tin chi tiết (tùy chọn)...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
                filled: true,
                fillColor: AppColors.surfaceSoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.hairlineSoft),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _submitting ? null : _submitReport,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Gửi báo cáo'),
        ),
      ],
    );
  }
}
