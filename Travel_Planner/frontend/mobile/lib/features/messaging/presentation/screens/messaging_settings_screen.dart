import 'package:flutter/material.dart';

import '../../data/messaging_repository.dart';
import '../../data/models/messaging_settings.dart';

class MessagingSettingsScreen extends StatefulWidget {
  final String token;
  final MessagingRepository repository;
  const MessagingSettingsScreen({
    super.key,
    required this.token,
    required this.repository,
  });
  @override
  State<MessagingSettingsScreen> createState() =>
      _MessagingSettingsScreenState();
}

class _MessagingSettingsScreenState extends State<MessagingSettingsScreen> {
  MessagingSettings? _settings;
  bool _loading = true, _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await widget.repository.settings(widget.token);
      if (mounted) setState(() => _settings = value);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _update(InboundMessagePolicy policy) async {
    setState(() => _saving = true);
    try {
      final result = await widget.repository.updateSettings(
        MessagingSettings(policy),
        widget.token,
      );
      if (mounted) setState(() => _settings = result);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể lưu quyền riêng tư.')),
        );
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quyền riêng tư tin nhắn')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _settings == null
        ? const Center(child: Text('Không thể tải cài đặt.'))
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Ai có thể nhắn tin cho bạn?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              const SizedBox(height: 8),
              RadioListTile<InboundMessagePolicy>(
                value: InboundMessagePolicy.friendsOnly,
                groupValue: _settings!.inboundPolicy,
                onChanged: _saving ? null : (v) => _update(v!),
                title: const Text('Bạn bè'),
                subtitle: const Text('Cài đặt mặc định'),
              ),
              RadioListTile<InboundMessagePolicy>(
                value: InboundMessagePolicy.everyone,
                groupValue: _settings!.inboundPolicy,
                onChanged: _saving ? null : (v) => _update(v!),
                title: const Text('Mọi người'),
              ),
              RadioListTile<InboundMessagePolicy>(
                value: InboundMessagePolicy.nobody,
                groupValue: _settings!.inboundPolicy,
                onChanged: _saving ? null : (v) => _update(v!),
                title: const Text('Không ai'),
              ),
              const Divider(),
              const Text(
                'Người bị chặn',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              FutureBuilder(
                future: widget.repository.blockedUsers(widget.token),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  final users = snapshot.data!.content;
                  if (users.isEmpty)
                    return const ListTile(title: Text('Bạn chưa chặn ai.'));
                  return Column(
                    children: users
                        .map(
                          (u) => ListTile(
                            title: Text(u.fullName ?? '@${u.effectiveHandle}'),
                            trailing: TextButton(
                              onPressed: () => widget.repository
                                  .unblock(u.userId, widget.token)
                                  .then((_) => setState(() {})),
                              child: const Text('Bỏ chặn'),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
  );
}
