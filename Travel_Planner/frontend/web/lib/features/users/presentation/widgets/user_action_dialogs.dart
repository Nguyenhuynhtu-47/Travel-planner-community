import 'package:flutter/material.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_dialog.dart';
import '../../../../shared/widgets/admin_status_badge.dart';
import '../../data/models/admin_user_model.dart';

Future<bool?> showBanUnbanUserDialog({
  required BuildContext context,
  required AdminUserModel user,
  required Future<void> Function(String reason) onSubmit,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BanUnbanUserDialog(user: user, onSubmit: onSubmit),
  );
}

class _BanUnbanUserDialog extends StatefulWidget {
  final AdminUserModel user;
  final Future<void> Function(String reason) onSubmit;

  const _BanUnbanUserDialog({
    required this.user,
    required this.onSubmit,
  });

  @override
  State<_BanUnbanUserDialog> createState() => _BanUnbanUserDialogState();
}

class _BanUnbanUserDialogState extends State<_BanUnbanUserDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _submitting = false;
  String? _inlineError;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final reason = _reasonController.text.trim();
    if (reason.length < 3 || reason.length > 255) {
      setState(() {
        _inlineError = 'Vui lòng nhập lý do từ 3 đến 255 ký tự.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _inlineError = null;
    });
    try {
      await widget.onSubmit(reason);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _inlineError = e.message.isNotEmpty
              ? e.message
              : 'Không thể cập nhật trạng thái tài khoản.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _inlineError = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isBan = user.status != 'BANNED';
    final targetStatus = isBan ? 'BANNED' : 'ACTIVE';

    return AdminDialog(
      title: isBan ? 'Khóa tài khoản người dùng' : 'Mở khóa tài khoản',
      titleBadge: AdminStatusBadge(status: targetStatus),
      width: 480,
      onClose: _submitting ? null : () => Navigator.of(context).pop(false),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tài khoản: ${user.fullName?.isNotEmpty == true ? user.fullName : user.username} (@${user.handle})',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isBan ? AppColors.errorLight : AppColors.successLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: isBan ? AppColors.errorBorder : AppColors.successBorder,
              ),
            ),
            child: Text(
              isBan
                  ? 'Khóa tài khoản sẽ thu hồi ngay lập tức toàn bộ JWT và phiên đăng nhập đang hoạt động của người dùng này.'
                  : 'Mở khóa sẽ khôi phục trạng thái Hoạt động để người dùng có thể đăng nhập trở lại.',
              style: TextStyle(
                fontSize: 12.5,
                color: isBan ? AppColors.error : AppColors.success,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _reasonController,
            enabled: !_submitting,
            maxLines: 3,
            maxLength: 255,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: isBan
                  ? 'Lý do khóa tài khoản (hiển thị với người dùng) *'
                  : 'Lý do mở khóa (hiển thị với người dùng) *',
              hintText: isBan
                  ? 'VD: Vi phạm tiêu chuẩn cộng đồng, phát tán spam...'
                  : 'VD: Đã xác minh khiếu nại hợp lệ...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          if (_inlineError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _inlineError!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.borderStrong),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _handleConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: isBan ? AppColors.error : AppColors.success,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isBan ? 'Xác nhận khóa' : 'Xác nhận mở khóa'),
        ),
      ],
    );
  }
}

Future<bool?> showChangeRoleDialog({
  required BuildContext context,
  required AdminUserModel user,
  required Future<void> Function(String targetRole, String reason) onSubmit,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ChangeRoleDialog(user: user, onSubmit: onSubmit),
  );
}

class _ChangeRoleDialog extends StatefulWidget {
  final AdminUserModel user;
  final Future<void> Function(String targetRole, String reason) onSubmit;

  const _ChangeRoleDialog({
    required this.user,
    required this.onSubmit,
  });

  @override
  State<_ChangeRoleDialog> createState() => _ChangeRoleDialogState();
}

class _ChangeRoleDialogState extends State<_ChangeRoleDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _submitting = false;
  String? _inlineError;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm(String targetRole) async {
    final reason = _reasonController.text.trim();
    if (reason.length < 3 || reason.length > 255) {
      setState(() {
        _inlineError = 'Vui lòng nhập lý do từ 3 đến 255 ký tự.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _inlineError = null;
    });
    try {
      await widget.onSubmit(targetRole, reason);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _inlineError = e.message.isNotEmpty
              ? e.message
              : 'Không thể thay đổi vai trò tài khoản.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _inlineError = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final targetRole = user.role == 'ADMIN' ? 'USER' : 'ADMIN';
    final isPromote = targetRole == 'ADMIN';

    return AdminDialog(
      title: isPromote ? 'Nâng quyền Quản trị viên' : 'Hạ quyền về Người dùng',
      titleBadge: AdminStatusBadge(
        status: isPromote ? 'WARNING' : 'INACTIVE',
        customLabel: '${user.role} → $targetRole',
      ),
      width: 480,
      onClose: _submitting ? null : () => Navigator.of(context).pop(false),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tài khoản: ${user.fullName?.isNotEmpty == true ? user.fullName : user.username} (@${user.handle})',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isPromote ? AppColors.warningLight : AppColors.accentLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: isPromote ? AppColors.warningBorder : AppColors.accentBorder,
              ),
            ),
            child: Text(
              isPromote
                  ? 'Cấp quyền ADMIN cho phép tài khoản này truy cập toàn bộ chức năng quản trị và thu hồi các phiên đăng nhập cũ để xác thực lại.'
                  : 'Hạ quyền về USER sẽ tước quyền quản trị và thu hồi ngay các phiên đăng nhập hiện tại của tài khoản.',
              style: TextStyle(
                fontSize: 12.5,
                color: isPromote ? AppColors.warning : AppColors.accentDark,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _reasonController,
            enabled: !_submitting,
            maxLines: 3,
            maxLength: 255,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Lý do thay đổi vai trò *',
              hintText: isPromote
                  ? 'VD: Bổ nhiệm điều phối viên kiểm duyệt...'
                  : 'VD: Kết thúc nhiệm kỳ quản trị...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          if (_inlineError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _inlineError!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.borderStrong),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : () => _handleConfirm(targetRole),
          style: ElevatedButton.styleFrom(
            backgroundColor: isPromote ? AppColors.primary : AppColors.accentDark,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isPromote ? 'Xác nhận nâng quyền' : 'Xác nhận hạ quyền'),
        ),
      ],
    );
  }
}

Future<bool?> showRevokeSessionsConfirmDialog({
  required BuildContext context,
  required AdminUserModel user,
  required Future<int> Function() onConfirm,
}) {
  bool submitting = false;
  String? inlineError;

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> handleRevoke() async {
            setDialogState(() {
              submitting = true;
              inlineError = null;
            });
            try {
              await onConfirm();
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            } on ApiException catch (e) {
              setDialogState(() {
                submitting = false;
                inlineError = e.message.isNotEmpty
                    ? e.message
                    : 'Không thể thu hồi phiên đăng nhập.';
              });
            } catch (_) {
              setDialogState(() {
                submitting = false;
                inlineError = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
              });
            }
          }

          return AdminDialog(
            title: 'Thu hồi toàn bộ phiên đăng nhập',
            width: 440,
            onClose: submitting ? null : () => Navigator.of(dialogContext).pop(false),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bạn có chắc chắn muốn đăng xuất từ xa tất cả thiết bị đang hoạt động của @${user.handle}?',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                if (inlineError != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    inlineError!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.borderStrong),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: submitting ? null : handleRevoke,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Thu hồi phiên'),
              ),
            ],
          );
        },
      );
    },
  );
}
