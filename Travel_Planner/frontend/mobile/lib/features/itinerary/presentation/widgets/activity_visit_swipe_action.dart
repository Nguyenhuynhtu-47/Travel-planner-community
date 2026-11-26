import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';

import '../../data/models/activity_detail.dart';

/// Reveals a unified left-to-right swipe action for checking in or unchecking an activity.
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
  static const double _actionWidth = 100;
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
      _offset = (_dragStartOffset + dragDistance).clamp(0.0, _actionWidth);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_isUpdating) return;
    final shouldReveal = _offset >= _actionWidth * 0.35;
    setState(() {
      _isDragging = false;
      _offset = shouldReveal ? _actionWidth : 0;
    });
  }

  Future<void> _updateVisitStatus() async {
    if (_isUpdating) return;
    HapticFeedback.mediumImpact();
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
    final actionLabel = visited ? 'Chưa ghé thăm' : 'Đã ghé thăm';
    final actionIcon = visited ? Icons.close_rounded : Icons.check_rounded;
    final backgroundColor = visited
        ? const Color(0xFFF59E0B)
        : const Color(0xFF2563EB);
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IgnorePointer(
                    ignoring: _offset <= 0.5 && !_isUpdating,
                    child: SizedBox(
                      width: _actionWidth,
                      height: double.infinity,
                      child: BounceTap(
                        enabled: !_isUpdating,
                        child: Material(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: _isUpdating ? null : _updateVisitStatus,
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isUpdating)
                                    const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    Icon(
                                      actionIcon,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    actionLabel,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.15,
                                    ),
                                  ),
                                ],
                              ),
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
                    duration: _isDragging || disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    builder: (context, offset, child) => Transform.translate(
                      offset: Offset(offset, 0),
                      child: child,
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
