import 'package:flutter/material.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/activity_detail.dart';

/// Reveals a visit-status action when the activity row is swiped to the right.
class ActivityVisitSwipeAction extends StatefulWidget {
  final ActivityDetail activity;
  final Widget child;
  final Future<bool> Function(bool visited) onUpdate;

  const ActivityVisitSwipeAction({
    super.key,
    required this.activity,
    required this.child,
    required this.onUpdate,
  });

  @override
  State<ActivityVisitSwipeAction> createState() =>
      _ActivityVisitSwipeActionState();
}

class _ActivityVisitSwipeActionState extends State<ActivityVisitSwipeAction> {
  static const double _actionWidth = 132;
  double _offset = 0;
  double _dragStartOffset = 0;
  double _dragStartX = 0;
  bool _isUpdating = false;
  bool _isDragging = false;

  @override
  void didUpdateWidget(ActivityVisitSwipeAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity.visited != widget.activity.visited) {
      _offset = 0;
    }
  }

  void _handleDragStart(DragStartDetails details) {
    _dragStartOffset = _offset;
    _dragStartX = details.globalPosition.dx;
    setState(() => _isDragging = true);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isUpdating) return;
    setState(() {
      final dragDistance = details.globalPosition.dx - _dragStartX;
      final minimumOffset = widget.activity.visited ? -_actionWidth : 0.0;
      final maximumOffset = widget.activity.visited ? 0.0 : _actionWidth;
      _offset = (_dragStartOffset + dragDistance).clamp(
        minimumOffset,
        maximumOffset,
      );
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_isUpdating) return;
    final shouldReveal = _offset.abs() >= _actionWidth * 0.35;
    setState(() {
      _isDragging = false;
      _offset = shouldReveal
          ? (widget.activity.visited ? -_actionWidth : _actionWidth)
          : 0;
    });
  }

  Future<void> _updateVisitStatus() async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    final success = await widget.onUpdate(!widget.activity.visited);
    if (!mounted) return;
    setState(() {
      _isUpdating = false;
      if (success) _offset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visited = widget.activity.visited;
    final actionAlignment = visited
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final actionLabel = visited ? 'Chưa ghé thăm' : 'Đã ghé thăm';
    final actionIcon = visited ? Icons.undo_rounded : Icons.check_rounded;
    final backgroundColor = AppColors.primaryLight;

    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: Align(
                alignment: actionAlignment,
                child: SizedBox(
                  width: _actionWidth,
                  child: Material(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    child: BounceTap(
                      enabled: !_isUpdating,
                      child: TextButton.icon(
                        onPressed: _isUpdating ? null : _updateVisitStatus,
                        icon: _isUpdating
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : Icon(actionIcon, size: 18),
                        label: Text(actionLabel, maxLines: 1),
                        style: TextButton.styleFrom(
                          backgroundColor: backgroundColor,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: _handleDragStart,
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: _handleDragEnd,
              child: SizedBox(
                width: constraints.maxWidth,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: _offset),
                  duration:
                      _isDragging || MediaQuery.of(context).disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  builder: (context, offset, child) => Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  ),
                  child: Material(
                    color: AppColors.surface,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
