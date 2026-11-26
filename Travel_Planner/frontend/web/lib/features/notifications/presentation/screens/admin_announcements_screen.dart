import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';
import 'package:travel_planner_web/features/notifications/data/announcement_admin_repository.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final AnnouncementAdminRepository repository;
  const AdminAnnouncementsScreen({
    super.key,
    required this.authNotifier,
    required this.repository,
  });
  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _status;
  String _query = '';
  int _page = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = widget.authNotifier.token;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Phiên đăng nhập đã hết hạn.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.list(
        token,
        page: _page,
        status: _status,
        query: _query,
      );
      if (!mounted) return;
      setState(() {
        _items = (result['content'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _totalPages = (result['totalPages'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Không tải được thông báo hệ thống.';
        });
      }
    }
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final title = TextEditingController(text: item?['title']?.toString() ?? '');
    final body = TextEditingController(text: item?['body']?.toString() ?? '');
    final expiry = TextEditingController(
      text: item?['expiresAt']?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, _) => AlertDialog(
          title: Text(
            item == null ? 'Tạo thông báo nháp' : 'Sửa thông báo nháp',
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: title,
                      maxLength: 160,
                      decoration: const InputDecoration(labelText: 'Tiêu đề'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Nhập tiêu đề' : null,
                    ),
                    TextFormField(
                      controller: body,
                      maxLines: 6,
                      maxLength: 10000,
                      decoration: const InputDecoration(labelText: 'Nội dung'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Nhập nội dung'
                          : null,
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Nhóm: Thông báo hệ thống'),
                      ),
                    ),
                    TextFormField(
                      controller: expiry,
                      decoration: const InputDecoration(
                        labelText: 'Hết hạn (ISO, tùy chọn)',
                        hintText: '2026-12-31T23:59:00',
                      ),
                      validator: (v) =>
                          v != null &&
                              v.trim().isNotEmpty &&
                              DateTime.tryParse(v) == null
                          ? 'Thời gian không hợp lệ'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Xem trước',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Card(
                      color: AppColors.surfaceSubtle,
                      child: ListTile(
                        title: Text(
                          title.text.isEmpty ? 'Tiêu đề thông báo' : title.text,
                        ),
                        subtitle: Text(
                          body.text.isEmpty
                              ? 'Nội dung thông báo sẽ hiển thị tại đây.'
                              : body.text,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Lưu nháp'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final token = widget.authNotifier.token;
    if (token == null) return;
    final expiresAt = expiry.text.trim();
    final data = {
      'title': title.text.trim(),
      'body': body.text.trim(),
      'expiresAt': expiresAt.isEmpty
          ? null
          : DateTime.parse(expiresAt).toIso8601String().replaceFirst('Z', ''),
    };
    setState(() => _saving = true);
    try {
      if (item == null) {
        await widget.repository.create(token, data);
      } else {
        await widget.repository.update(
          token,
          (item['id'] as num).toInt(),
          data,
        );
      }
      if (mounted) {
        setState(() => _saving = false);
        await _load();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _message('Không lưu được bản nháp. Kiểm tra dữ liệu rồi thử lại.');
      }
    }
  }

  Future<void> _transition(
    Map<String, dynamic> item, {
    required bool publish,
  }) async {
    final action = publish
        ? 'phát hành cho toàn bộ tài khoản đang hoạt động'
        : 'hủy thông báo';
    final okay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(publish ? 'Xác nhận phát hành' : 'Xác nhận hủy'),
        content: Text(
          'Bạn có chắc muốn $action? Nội dung đã phát hành không thể chỉnh sửa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(publish ? 'Phát hành' : 'Hủy thông báo'),
          ),
        ],
      ),
    );
    if (okay != true) return;
    final token = widget.authNotifier.token;
    if (token == null) return;
    setState(() => _saving = true);
    try {
      final id = (item['id'] as num).toInt();
      if (publish) {
        await widget.repository.publish(token, id);
      } else {
        await widget.repository.cancel(token, id);
      }
      if (mounted) {
        setState(() => _saving = false);
        await _load();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _message('Không cập nhật được trạng thái thông báo.');
      }
    }
  }

  void _message(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Thông báo hệ thống',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            FilledButton.icon(
              onPressed: _saving ? null : () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Tạo bản nháp'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Nội dung đã phát hành được chia sẻ một lần; người dùng mới vẫn thấy thông báo còn hiệu lực.',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Tìm tiêu đề',
                ),
                onSubmitted: (v) {
                  _query = v.trim();
                  _page = 0;
                  _load();
                },
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String?>(
              value: _status,
              hint: const Text('Mọi trạng thái'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Mọi trạng thái')),
                DropdownMenuItem(value: 'DRAFT', child: Text('Nháp')),
                DropdownMenuItem(
                  value: 'PUBLISHED',
                  child: Text('Đã phát hành'),
                ),
                DropdownMenuItem(value: 'CANCELLED', child: Text('Đã hủy')),
              ],
              onChanged: (v) {
                setState(() {
                  _status = v;
                  _page = 0;
                });
                _load();
              },
            ),
            const Spacer(),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _items.isEmpty
              ? const Center(child: Text('Chưa có thông báo.'))
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final status = item['status'];
                    return ListTile(
                      title: Text(item['title']?.toString() ?? ''),
                      subtitle: Text(
                        'Thông báo hệ thống · $status${item['expiresAt'] == null ? '' : ' · Hết hạn ${item['expiresAt']}'}\n${item['body'] ?? ''}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          if (status == 'DRAFT')
                            IconButton(
                              tooltip: 'Sửa nháp',
                              onPressed: _saving ? null : () => _edit(item),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          if (status == 'DRAFT')
                            IconButton(
                              tooltip: 'Phát hành',
                              onPressed: _saving
                                  ? null
                                  : () => _transition(item, publish: true),
                              icon: const Icon(Icons.send_outlined),
                            ),
                          if (status == 'PUBLISHED')
                            IconButton(
                              tooltip: 'Hủy',
                              onPressed: _saving
                                  ? null
                                  : () => _transition(item, publish: false),
                              icon: const Icon(Icons.cancel_outlined),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Trang ${_totalPages == 0 ? 0 : _page + 1} / $_totalPages'),
            IconButton(
              onPressed: _page > 0 && !_loading
                  ? () {
                      setState(() => _page--);
                      _load();
                    }
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              onPressed: _page + 1 < _totalPages && !_loading
                  ? () {
                      setState(() => _page++);
                      _load();
                    }
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    ),
  );
}
