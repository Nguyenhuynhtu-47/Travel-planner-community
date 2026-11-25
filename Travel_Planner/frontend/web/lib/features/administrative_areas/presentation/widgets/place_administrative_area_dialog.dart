import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../locations/data/models/place_model.dart';
import '../../data/administrative_area_repository.dart';
import '../../data/models/administrative_area_model.dart';

/// ID 5.9: Dialog integrated into AdminPlacesScreen to preview,
/// auto-resolve, manually link, or unlink a Place's Administrative Area.
class PlaceAdministrativeAreaDialog extends StatefulWidget {
  final PlaceModel place;
  final String? token;
  final AdministrativeAreaRepository? repository;

  const PlaceAdministrativeAreaDialog({
    super.key,
    required this.place,
    this.token,
    this.repository,
  });

  @override
  State<PlaceAdministrativeAreaDialog> createState() =>
      _PlaceAdministrativeAreaDialogState();
}

class _PlaceAdministrativeAreaDialogState
    extends State<PlaceAdministrativeAreaDialog> {
  late final AdministrativeAreaRepository _repo;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController(
    text: 'Quản trị viên gán mã hành chính thủ công',
  );

  bool _isPreviewing = false;
  bool _isSearching = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  PlaceResolutionResultModel? _previewResult;
  List<AdministrativeAreaSummaryModel> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? AdministrativeAreaRepository();
    if (widget.place.administrativeAreaCode != null) {
      _codeController.text = widget.place.administrativeAreaCode!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _codeController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handlePreview() async {
    setState(() {
      _isPreviewing = true;
      _errorMessage = null;
    });
    try {
      final result = await _repo.previewPlaceResolution(
        widget.place.placeId,
        token: widget.token,
      );
      if (!mounted) return;
      setState(() {
        _previewResult = result;
        _isPreviewing = false;
        if (result.resolvedArea != null &&
            !result.resolvedArea!.isQuarantined) {
          _codeController.text = result.resolvedArea!.code;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isPreviewing = false;
      });
    }
  }

  Future<void> _handleAutoResolveAndLink() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await _repo.resolveAndLinkPlace(
        widget.place.placeId,
        overwriteExisting: true,
        token: widget.token,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  Future<void> _handleSearchAreas() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });
    try {
      final results = await _repo.searchAreas(
        query,
        limit: 12,
        token: widget.token,
      );
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSearching = false;
      });
    }
  }

  Future<void> _handleManualLink() async {
    final code = _codeController.text.trim();
    final reason = _reasonController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng chọn hoặc nhập mã khu vực hành chính.';
      });
      return;
    }
    if (reason.length < 3) {
      setState(() {
        _errorMessage = 'Vui lòng nhập lý do gán mã (tối thiểu 3 ký tự).';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await _repo.linkPlaceManually(
        placeId: widget.place.placeId,
        administrativeAreaCode: code,
        reason: reason,
        token: widget.token,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  Future<void> _handleUnlink() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await _repo.unlinkPlace(
        widget.place.placeId,
        token: widget.token,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCurrentArea = widget.place.administrativeAreaName != null &&
        widget.place.administrativeAreaName!.isNotEmpty;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.location_city_outlined,
              size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Gán mã khu vực hành chính: ${widget.place.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.place.address,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text(
                          'Liên kết hiện tại: ',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            hasCurrentArea
                                ? '${widget.place.administrativeAreaName}'
                                    '${widget.place.administrativeAreaCode != null ? ' (${widget.place.administrativeAreaCode})' : ''}'
                                    '${widget.place.administrativeAreaParentName != null ? ' - ${widget.place.administrativeAreaParentName}' : ''}'
                                : 'Chưa liên kết',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: hasCurrentArea
                                  ? AppColors.success
                                  : AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (hasCurrentArea)
                          TextButton(
                            onPressed: _isSubmitting ? null : _handleUnlink,
                            child: const Text(
                              'Gỡ liên kết',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: _isPreviewing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high_outlined, size: 16),
                    label: const Text('Xem trước phân giải tự động'),
                    onPressed:
                        (_isPreviewing || _isSubmitting) ? null : _handlePreview,
                  ),
                  if (_previewResult != null &&
                      _previewResult!.eligibleForAutoLink &&
                      _previewResult!.resolvedArea != null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Áp dụng tự động'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                      onPressed:
                          _isSubmitting ? null : _handleAutoResolveAndLink,
                    ),
                ],
              ),
              if (_previewResult != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Độ tin cậy: ${_previewResult!.confidence}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_previewResult!.resolvedArea != null)
                        Text(
                          'Đề xuất: ${_previewResult!.resolvedArea!.displayLabel}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (_previewResult!.explanation != null)
                        Text(
                          _previewResult!.explanation!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Tra cứu & Gán mã thủ công',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Tìm xã/phường/tỉnh (vd: Hoàn Kiếm)...',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _handleSearchAreas(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSearching ? null : _handleSearchAreas,
                    child: _isSearching
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Tìm'),
                  ),
                ],
              ),
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final area = _searchResults[idx];
                      return ListTile(
                        dense: true,
                        title: Text(
                          area.displayLabel,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        trailing: const Text(
                          'Chọn',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _codeController.text = area.code;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Mã đơn vị hành chính',
                  hintText: 'Ví dụ: 00070',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Lý do gán mã',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSubmitting ? null : _handleManualLink,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Lưu mã khu vực'),
        ),
      ],
    );
  }
}
