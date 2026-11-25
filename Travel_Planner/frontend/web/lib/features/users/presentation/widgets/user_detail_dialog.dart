import 'package:flutter/material.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_dialog.dart';
import '../../../../shared/widgets/admin_status_badge.dart';
import '../../data/admin_user_repository.dart';
import '../../data/models/admin_user_model.dart';
import 'user_action_dialogs.dart';
import 'user_avatar.dart';

class UserDetailDialog extends StatefulWidget {
  final int userId;
  final String token;
  final bool isSelf;
  final AdminUserRepository repository;
  final VoidCallback? onSessionsRevoked;

  const UserDetailDialog({
    super.key,
    required this.userId,
    required this.token,
    required this.isSelf,
    required this.repository,
    this.onSessionsRevoked,
  });

  static Future<void> show({
    required BuildContext context,
    required int userId,
    required String token,
    required bool isSelf,
    required AdminUserRepository repository,
    VoidCallback? onSessionsRevoked,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => UserDetailDialog(
        userId: userId,
        token: token,
        isSelf: isSelf,
        repository: repository,
        onSessionsRevoked: onSessionsRevoked,
      ),
    );
  }

  @override
  State<UserDetailDialog> createState() => _UserDetailDialogState();
}

class _UserDetailDialogState extends State<UserDetailDialog> {
  bool _loading = true;
  String? _error;
  AdminUserDetailModel? _detail;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.repository.getUserDetail(
        widget.userId,
        token: widget.token,
      );
      if (mounted) {
        setState(() {
          _detail = res;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message.isNotEmpty
              ? e.message
              : 'Không thể tải chi tiết người dùng.';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải chi tiết người dùng.';
          _loading = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  Future<void> _handleRevokeSessions() async {
    final detail = _detail;
    if (detail == null) return;

    final confirmed = await showRevokeSessionsConfirmDialog(
      context: context,
      user: detail.user,
      onConfirm: () => widget.repository.revokeAllSessions(
        detail.user.userId,
        token: widget.token,
      ),
    );

    if (confirmed == true && mounted) {
      widget.onSessionsRevoked?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã thu hồi toàn bộ phiên đăng nhập của người dùng.'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadDetail();
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return AdminDialog(
      title: 'Chi tiết người dùng',
      titleBadge: detail != null
          ? AdminStatusBadge(status: detail.user.status)
          : null,
      width: 640,
      content: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : _error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton(
                      onPressed: _loadDetail,
                      child: const Text('Thử lại'),
                    ),
                  ],
                )
              : _buildDetailBody(detail!),
      actions: [
        if (detail != null && !widget.isSelf)
          OutlinedButton.icon(
            onPressed: _handleRevokeSessions,
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Thu hồi tất cả phiên'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentDark,
              side: const BorderSide(color: AppColors.accentBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          child: const Text('Đóng'),
        ),
      ],
    );
  }

  Widget _buildDetailBody(AdminUserDetailModel detail) {
    final u = detail.user;
    final displayName =
        (u.fullName != null && u.fullName!.isNotEmpty) ? u.fullName! : u.username;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Identity strip
        Row(
          children: [
            UserAvatar(
              avatarUrl: u.avatar,
              displayName: displayName,
              size: 42,
              fontSize: 15,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '@${u.handle} • ${u.username} • ID #${u.userId}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            AdminStatusBadge(
              status: u.role == 'ADMIN' ? 'WARNING' : 'INFO',
              customLabel: u.role == 'ADMIN' ? 'Quản trị viên' : 'Người dùng',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // KPI Summary Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _statCell('Lịch trình', '${detail.itineraryCount}'),
              _statCell('Bài viết', '${detail.postCount}'),
              _statCell('Phiên hoạt động', '${detail.activeSessionCount}'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Metadata pairs
        _infoRow('Email', '${u.email} ${u.emailVerified ? "(Đã xác thực)" : "(Chưa xác thực)"}'),
        _infoRow('Số điện thoại', detail.phone ?? '-'),
        _infoRow('Địa chỉ', detail.address ?? '-'),
        _infoRow('Giới thiệu', detail.bio ?? '-'),
        _infoRow('Ngày tạo', _formatDateTime(u.createdAt)),
        const SizedBox(height: AppSpacing.lg),

        // Sessions list
        Text(
          'Lịch sử phiên đăng nhập (${detail.sessions.length}):',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (detail.sessions.isEmpty)
          const Text(
            'Chưa ghi nhận phiên đăng nhập nào.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              children: detail.sessions.take(10).map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.deviceInfo,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'IP: ${s.ipAddress} • Hoạt động cuối: ${_formatDateTime(s.lastActiveAt)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AdminStatusBadge(
                        status: s.status == 'ACTIVE' ? 'ACTIVE' : 'INACTIVE',
                        customLabel: s.status == 'ACTIVE' ? 'Đang mở' : 'Đã thu hồi',
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _statCell(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
