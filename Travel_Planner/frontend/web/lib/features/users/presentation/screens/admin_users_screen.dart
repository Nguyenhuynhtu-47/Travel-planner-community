import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_data_table.dart';
import '../../../../shared/widgets/admin_page_header.dart';
import '../../../../shared/widgets/admin_status_badge.dart';
import '../../../../shared/widgets/admin_toolbar.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/admin_user_repository.dart';
import '../../data/models/admin_user_model.dart';
import '../widgets/user_action_dialogs.dart';
import '../widgets/user_avatar.dart';
import '../widgets/user_detail_dialog.dart';

class AdminUsersScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final AdminUserRepository? repository;
  final bool embedded;

  const AdminUsersScreen({
    super.key,
    required this.authNotifier,
    this.repository,
    this.embedded = false,
  });

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late final AdminUserRepository _repository;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _loading = false;
  List<AdminUserModel> _users = [];
  int _page = 0;
  final int _pageSize = 20;
  int _totalPages = 0;
  int _totalElements = 0;

  String _searchKeyword = '';
  String _roleFilter = 'ALL';
  String _statusFilter = 'ALL';
  String? _errorMessage;

  String? get _token => widget.authNotifier.token;

  bool get _isAdmin {
    final role =
        widget.authNotifier.currentUser?['role']?.toString().toUpperCase();
    return role == 'ADMIN';
  }

  bool _isSelfUser(AdminUserModel user) {
    final currentUser = widget.authNotifier.currentUser;
    if (currentUser == null) return false;
    final currentId = (currentUser['userId'] as num?)?.toInt();
    final currentUsername = currentUser['username']?.toString();
    if (currentId != null && currentId == user.userId) return true;
    if (currentUsername != null &&
        currentUsername.isNotEmpty &&
        currentUsername.toLowerCase() == user.username.toLowerCase()) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AdminUserRepository();
    if (_isAdmin) {
      _loadUsers();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final res = await _repository.getUsersPaged(
        keyword: _searchKeyword.trim().isEmpty ? null : _searchKeyword.trim(),
        role: _roleFilter == 'ALL' ? null : _roleFilter,
        status: _statusFilter == 'ALL' ? null : _statusFilter,
        page: _page,
        size: _pageSize,
        token: token,
      );
      if (mounted) {
        setState(() {
          _users = res.content;
          _totalElements = res.totalElements;
          _totalPages = res.totalPages;
          _page = res.page;
        });
      }
    } catch (e) {
      final msg = e is ApiException && e.message.isNotEmpty
          ? e.message
          : 'Không thể tải danh sách người dùng';
      if (mounted) {
        setState(() => _errorMessage = msg);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _searchKeyword = value;
        _page = 0;
      });
      _loadUsers();
    });
  }

  void _onClearFilters() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchKeyword = '';
      _roleFilter = 'ALL';
      _statusFilter = 'ALL';
      _page = 0;
    });
    _loadUsers();
  }

  Future<void> _openDetail(AdminUserModel user) async {
    final token = _token;
    if (token == null) return;
    await UserDetailDialog.show(
      context: context,
      userId: user.userId,
      token: token,
      isSelf: _isSelfUser(user),
      repository: _repository,
      onSessionsRevoked: _loadUsers,
    );
  }

  Future<void> _openBanUnban(AdminUserModel user) async {
    final token = _token;
    if (token == null || _isSelfUser(user)) return;

    final targetStatus = user.status == 'BANNED' ? 'ACTIVE' : 'BANNED';
    final confirmed = await showBanUnbanUserDialog(
      context: context,
      user: user,
      onSubmit: (reason) => _repository.updateUserStatus(
        user.userId,
        status: targetStatus,
        reason: reason,
        token: token,
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targetStatus == 'BANNED'
                ? 'Đã khóa tài khoản @${user.handle} và thu hồi phiên đăng nhập.'
                : 'Đã mở khóa tài khoản @${user.handle}.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadUsers();
    }
  }

  Future<void> _openChangeRole(AdminUserModel user) async {
    final token = _token;
    if (token == null || _isSelfUser(user)) return;

    final confirmed = await showChangeRoleDialog(
      context: context,
      user: user,
      onSubmit: (targetRole, reason) => _repository.updateUserRole(
        user.userId,
        role: targetRole,
        reason: reason,
        token: token,
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật vai trò cho @${user.handle}.'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadUsers();
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

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const Center(
        child: Text(
          'Bạn không có quyền truy cập chức năng Quản lý người dùng.',
          style: TextStyle(color: AppColors.error, fontSize: 14),
        ),
      );
    }

    final hasFilters = _searchKeyword.trim().isNotEmpty ||
        _roleFilter != 'ALL' ||
        _statusFilter != 'ALL';

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          title: 'Quản lý người dùng',
          actions: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Tổng: $_totalElements tài khoản',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _loading ? null : _loadUsers,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Làm mới'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.borderStrong),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
          ],
        ),
        AdminToolbar(
          searchField: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onSubmitted: (val) {
              _debounce?.cancel();
              setState(() {
                _searchKeyword = val;
                _page = 0;
              });
              _loadUsers();
            },
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              hintText: 'Tìm theo tên, @handle, email...',
              hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textMuted),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 15),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          filters: [
            _buildDropdown(
              value: _roleFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('Tất cả vai trò')),
                DropdownMenuItem(value: 'USER', child: Text('Người dùng (USER)')),
                DropdownMenuItem(value: 'ADMIN', child: Text('Quản trị viên (ADMIN)')),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _roleFilter = val;
                  _page = 0;
                });
                _loadUsers();
              },
            ),
            _buildDropdown(
              value: _statusFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('Tất cả trạng thái')),
                DropdownMenuItem(value: 'ACTIVE', child: Text('Hoạt động')),
                DropdownMenuItem(value: 'BANNED', child: Text('Đã khóa')),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _statusFilter = val;
                  _page = 0;
                });
                _loadUsers();
              },
            ),
            if (hasFilters)
              TextButton.icon(
                onPressed: _onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
                label: const Text('Xóa bộ lọc'),
              ),
          ],
        ),
        if (_errorMessage != null)
          Container(
            margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.errorBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: _loadUsers,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth =
                    constraints.maxWidth.isFinite ? constraints.maxWidth : 1080.0;
                final tableMinWidth =
                    availableWidth > 1070.0 ? availableWidth : 1070.0;
                final contentBudget = (tableMinWidth - 650).clamp(420.0, 960.0);
                final userColWidth = (contentBudget * 0.56).clamp(240.0, 440.0);
                final emailColWidth = (contentBudget * 0.44).clamp(190.0, 360.0);

                return AdminDataTable(
                  isLoading: _loading,
                  emptyMessage: 'Không tìm thấy người dùng nào phù hợp.',
                  minWidth: tableMinWidth,
                  columnSpacing: 18,
                  horizontalMargin: 16,
                  dataRowHeight: 56,
                  currentPage: _page,
                  totalPages: _totalPages,
                  totalElements: _totalElements,
                  pageSize: _pageSize,
                  onPageChanged: (newPage) {
                    if (newPage != _page && newPage >= 0) {
                      setState(() => _page = newPage);
                      _loadUsers();
                    }
                  },
                  columns: [
                    const AdminDataColumn(
                      label: SizedBox(width: 52, child: Text('ID')),
                    ),
                    AdminDataColumn(
                      label: SizedBox(
                        width: userColWidth,
                        child: const Text('NGƯỜI DÙNG'),
                      ),
                    ),
                    AdminDataColumn(
                      label: SizedBox(
                        width: emailColWidth,
                        child: const Text('EMAIL'),
                      ),
                    ),
                    const AdminDataColumn(
                      label: SizedBox(width: 90, child: Text('VAI TRÒ')),
                    ),
                    const AdminDataColumn(
                      label: SizedBox(width: 105, child: Text('TRẠNG THÁI')),
                    ),
                    const AdminDataColumn(
                      label: SizedBox(width: 120, child: Text('NGÀY TẠO')),
                    ),
                    const AdminDataColumn(
                      label: SizedBox(width: 124, child: Text('THAO TÁC')),
                    ),
                  ],
                  rows: _users.map((user) {
                    final isSelf = _isSelfUser(user);
                    final isBanned = user.status == 'BANNED';
                    final displayName =
                        (user.fullName != null && user.fullName!.isNotEmpty)
                            ? user.fullName!
                            : user.username;

                    return AdminDataRow(
                      onTap: () => _openDetail(user),
                      cells: [
                        SizedBox(
                          width: 52,
                          child: Text(
                            '#${user.userId}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: userColWidth,
                          child: Row(
                            children: [
                              UserAvatar(
                                avatarUrl: user.avatar,
                                displayName: displayName,
                                size: 34,
                                fontSize: 12.5,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Tooltip(
                                            message: displayName,
                                            waitDuration:
                                                const Duration(milliseconds: 400),
                                            child: Text(
                                              displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (isSelf) ...[
                                          const SizedBox(width: 6),
                                          const AdminStatusBadge(
                                            status: 'INFO',
                                            customLabel: 'Bạn',
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '@${user.handle} • ${user.username}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: emailColWidth,
                          child: Tooltip(
                            message: user.email,
                            waitDuration: const Duration(milliseconds: 400),
                            child: Text(
                              user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AdminStatusBadge(
                              status: user.role == 'ADMIN' ? 'WARNING' : 'INFO',
                              customLabel:
                                  user.role == 'ADMIN' ? 'ADMIN' : 'USER',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 105,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AdminStatusBadge(status: user.status),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            _formatDateTime(user.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 124,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(36, 36),
                                  fixedSize: const Size(36, 36),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 17,
                                ),
                                tooltip: 'Xem chi tiết',
                                onPressed: () => _openDetail(user),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(36, 36),
                                  fixedSize: const Size(36, 36),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: Icon(
                                  isBanned
                                      ? Icons.lock_open_outlined
                                      : Icons.block,
                                  size: 17,
                                  color: isSelf
                                      ? AppColors.textMuted
                                      : (isBanned
                                          ? AppColors.success
                                          : AppColors.error),
                                ),
                                tooltip: isSelf
                                    ? 'Không thể tự khóa tài khoản đang đăng nhập'
                                    : (isBanned
                                        ? 'Mở khóa tài khoản'
                                        : 'Khóa tài khoản'),
                                onPressed:
                                    isSelf ? null : () => _openBanUnban(user),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(36, 36),
                                  fixedSize: const Size(36, 36),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: Icon(
                                  Icons.admin_panel_settings_outlined,
                                  size: 17,
                                  color: isSelf
                                      ? AppColors.textMuted
                                      : AppColors.primary,
                                ),
                                tooltip: isSelf
                                    ? 'Không thể tự thay đổi vai trò của chính mình'
                                    : 'Điều chỉnh vai trò',
                                onPressed:
                                    isSelf ? null : () => _openChangeRole(user),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return content;
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: content,
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
          iconSize: 18,
        ),
      ),
    );
  }
}
