import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/sync/app_sync_bus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../notification_unread_count_notifier.dart';

class NotificationBellButton extends StatefulWidget {
  final AuthNotifier? authNotifier;
  final VoidCallback onPressed;
  final NotificationUnreadCountNotifier? countNotifier;

  const NotificationBellButton({
    super.key,
    required this.onPressed,
    this.authNotifier,
    this.countNotifier,
  });

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton>
    with WidgetsBindingObserver {
  late final NotificationUnreadCountNotifier _countNotifier;
  StreamSubscription<SyncEvent>? _syncSubscription;
  String? get _token => widget.authNotifier?.token;
  String? get _account =>
      widget.authNotifier?.currentUser?['userId']?.toString();

  @override
  void initState() {
    super.initState();
    _countNotifier =
        widget.countNotifier ?? NotificationUnreadCountNotifier.shared;
    WidgetsBinding.instance.addObserver(this);
    widget.authNotifier?.addListener(_onAuthChanged);
    _countNotifier.addListener(_onCountChanged);
    _syncSubscription = AppSyncBus.instance
        .on(SyncDomain.notifications)
        .listen((_) => _loadCount(force: true));
    _loadCount();
  }

  @override
  void didUpdateWidget(covariant NotificationBellButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authNotifier != widget.authNotifier) {
      oldWidget.authNotifier?.removeListener(_onAuthChanged);
      widget.authNotifier?.addListener(_onAuthChanged);
      _onAuthChanged();
    }
  }

  void _onAuthChanged() {
    _loadCount(force: true);
  }

  Future<void> _loadCount({bool force = false}) async {
    final token = _token;
    final account = _account;
    if (token == null || account == null) {
      if (widget.authNotifier != null) _countNotifier.clear();
      return;
    }
    try {
      await _countNotifier.refresh(account, token, force: force);
    } catch (_) {
      // The bell remains usable; the notification screen exposes retry state.
    }
  }

  void _onCountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCount(force: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.authNotifier?.removeListener(_onAuthChanged);
    _countNotifier.removeListener(_onCountChanged);
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _countNotifier.count == 0
          ? 'Thông báo'
          : 'Thông báo chưa đọc: ${_countNotifier.count}',
      onPressed: widget.onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (_countNotifier.accountKey == _account && _countNotifier.count > 0)
            Positioned(
              right: -9,
              top: -6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                alignment: Alignment.center,
                child: Text(
                  _countNotifier.count > 99 ? '99+' : '${_countNotifier.count}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
