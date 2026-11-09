import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../location/data/location_repository.dart';
import '../../../location/data/models/location_search_result.dart';

/// Search suggestions for the itinerary's textual destination field.
/// Selecting a suggestion fills the display text only; itinerary.location has
/// no coordinate/place relation in the current API or database schema.
class ItineraryLocationSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String? token;
  final String? Function(String?)? validator;
  final LocationRepository? repository;

  const ItineraryLocationSearchField({
    super.key,
    required this.controller,
    this.token,
    this.validator,
    this.repository,
  });

  @override
  State<ItineraryLocationSearchField> createState() =>
      _ItineraryLocationSearchFieldState();
}

class _ItineraryLocationSearchFieldState
    extends State<ItineraryLocationSearchField> {
  late final LocationRepository _repository;
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  Timer? _debounce;
  List<LocationSearchResult> _results = [];
  String? _error;
  bool _loading = false;
  final String _sessionId = _newSessionId();
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocationRepository();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _removeOverlay();
    } else if (_results.isNotEmpty || _loading || _error != null) {
      _showOverlay();
    }
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    final requestId = ++_requestId;
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      _removeOverlay();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    _showOverlay();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final results = await _repository.searchLocations(
          query,
          limit: 8,
          mode: 'SUGGEST',
          sessionId: _sessionId,
          token: widget.token,
        );
        if (!mounted || requestId != _requestId) return;
        setState(() {
          _loading = false;
          _results = results;
          _error = results.isEmpty ? 'Không tìm thấy địa điểm phù hợp' : null;
        });
        _showOverlay();
      } on ApiException catch (e) {
        if (!mounted || requestId != _requestId) return;
        setState(() {
          _loading = false;
          _results = [];
          _error = e.message;
        });
        _showOverlay();
      } catch (_) {
        if (!mounted || requestId != _requestId) return;
        setState(() {
          _loading = false;
          _results = [];
          _error = 'Không thể kết nối máy chủ tìm kiếm.';
        });
        _showOverlay();
      }
    });
  }

  void _showOverlay() {
    if (!_focusNode.hasFocus) return;
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.sizeOf(context).width - 40,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 58),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: _loading && _results.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(_error ?? 'Nhập ít nhất 2 ký tự để tìm kiếm'),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            result.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            result.formattedAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () async {
                            var selected = result;
                            if (result.requiresDetails &&
                                result.providerId != null &&
                                result.providerType != null) {
                              try {
                                selected =
                                    await _repository.resolveTomTomPlace(
                                      type: result.providerType!,
                                      id: result.providerId!,
                                      sessionId: result.sessionId,
                                      token: widget.token,
                                    ) ??
                                    result;
                              } on ApiException catch (e) {
                                if (mounted) setState(() => _error = e.message);
                                _showOverlay();
                                return;
                              }
                            }
                            if (!selected.hasCoordinates) {
                              if (mounted) {
                                setState(
                                  () => _error = 'Địa điểm chưa có tọa độ hợp lệ. Bạn vẫn có thể nhập tên thủ công.',
                                );
                              }
                              _showOverlay();
                              return;
                            }
                            widget.controller.text = selected.name;
                            widget.controller.selection =
                                TextSelection.collapsed(
                                  offset: widget.controller.text.length,
                                );
                            _focusNode.unfocus();
                            _removeOverlay();
                          },
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  static String _newSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            onChanged: _onChanged,
            validator: widget.validator,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Điểm đến / Địa điểm *',
              hintText: 'Ví dụ: Đà Lạt, Lâm Đồng',
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
