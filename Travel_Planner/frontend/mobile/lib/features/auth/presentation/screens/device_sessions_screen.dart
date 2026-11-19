import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_page_title.dart';
import '../auth_notifier.dart';

class DeviceSessionsScreen extends StatefulWidget {
  final AuthNotifier authNotifier;

  const DeviceSessionsScreen({
    super.key,
    required this.authNotifier,
  });

  @override
  State<DeviceSessionsScreen> createState() => _DeviceSessionsScreenState();
}

class _DeviceSessionsScreenState extends State<DeviceSessionsScreen> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _sessions = [];
  bool _isRevoking = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final sessions = await widget.authNotifier.getSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải danh sách phiên đăng nhập. Vui lòng thử lại sau.';
        _loading = false;
      });
    }
  }

  Future<void> _revokeSession(String sessionId, String deviceInfo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('Đăng xuất thiết bị'),
        content: Text('Bạn có chắc chắn muốn đăng xuất khỏi thiết bị "$deviceInfo"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRevoking = true);
    try {
      await widget.authNotifier.revokeSession(sessionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã thu hồi phiên đăng nhập thành công'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadSessions();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã có lỗi xảy ra. Vui lòng thử lại sau.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRevoking = false);
      }
    }
  }

  Future<void> _revokeOtherSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('Đăng xuất tất cả thiết bị khác'),
        content: const Text(
          'Tất cả các phiên đăng nhập khác sẽ bị đăng xuất ngay lập tức. Thiết bị hiện tại vẫn được giữ nguyên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Đăng xuất tất cả'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRevoking = true);
    try {
      final count = await widget.authNotifier.revokeOtherSessions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã đăng xuất thành công khỏi $count thiết bị khác'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadSessions();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã có lỗi xảy ra. Vui lòng thử lại sau.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRevoking = false);
      }
    }
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return 'Không rõ';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    return '$hour:$min, $day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppPageTitle(title: 'Thiết bị & Phiên đăng nhập'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 0.5,
            color: AppColors.hairlineSoft,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loadSessions,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_sessions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadSessions,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            Center(
              child: Text(
                'Không tìm thấy phiên đăng nhập nào.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final otherActiveSessions = _sessions
        .where((s) => s['isCurrentSession'] != true && s['status'] == 'ACTIVE')
        .toList();

    return RefreshIndicator(
      onRefresh: _loadSessions,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          const Text(
            'Các thiết bị đang đăng nhập vào tài khoản của bạn. Bạn có thể chủ động đăng xuất khỏi các thiết bị không nhận diện được.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Session list
          ..._sessions.map((session) => _buildSessionCard(session)),

          const SizedBox(height: 24),

          // Revoke other sessions button
          if (otherActiveSessions.isNotEmpty)
            OutlinedButton.icon(
              onPressed: _isRevoking ? null : _revokeOtherSessions,
              icon: const Icon(Icons.devices_other, size: 20),
              label: const Text('Đăng xuất tất cả thiết bị khác'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final bool isCurrent = session['isCurrentSession'] == true;
    final String status = session['status']?.toString() ?? 'ACTIVE';
    final bool isActive = status == 'ACTIVE';
    final String deviceInfo = session['deviceInfo']?.toString() ?? 'Thiết bị không xác định';
    final String ipAddress = session['ipAddress']?.toString() ?? '0.0.0.0';
    final String sessionId = session['sessionId']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent ? AppColors.primary : AppColors.border,
          width: isCurrent ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                deviceInfo.contains('Mobile') || deviceInfo.contains('Android') || deviceInfo.contains('iOS')
                    ? Icons.smartphone
                    : Icons.laptop_mac,
                size: 22,
                color: isCurrent ? AppColors.primary : AppColors.textPrimary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  deviceInfo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Thiết bị này',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                )
              else if (!isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.hairlineSoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status == 'REVOKED' ? 'Đã đăng xuất' : 'Hết hạn',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Địa chỉ IP: ',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                ipAddress,
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                'Hoạt động gần nhất: ',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                _formatDateTime(session['lastActiveAt']),
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              ),
            ],
          ),
          if (!isCurrent && isActive) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isRevoking ? null : () => _revokeSession(sessionId, deviceInfo),
                icon: const Icon(Icons.logout, size: 16, color: AppColors.error),
                label: const Text(
                  'Đăng xuất thiết bị này',
                  style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
