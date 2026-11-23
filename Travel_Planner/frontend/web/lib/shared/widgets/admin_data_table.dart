import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'hover_movement.dart';

/// Column definition for [AdminDataTable].
class AdminDataColumn {
  final Widget label;
  final String? tooltip;
  final bool numeric;
  final VoidCallback? onSort;
  final bool isSorted;
  final bool ascending;

  const AdminDataColumn({
    required this.label,
    this.tooltip,
    this.numeric = false,
    this.onSort,
    this.isSorted = false,
    this.ascending = true,
  });

  /// Factory constructor for simple text labels.
  factory AdminDataColumn.text(
    String title, {
    String? tooltip,
    bool numeric = false,
    VoidCallback? onSort,
    bool isSorted = false,
    bool ascending = true,
  }) {
    return AdminDataColumn(
      label: Text(title.toUpperCase()),
      tooltip: tooltip,
      numeric: numeric,
      onSort: onSort,
      isSorted: isSorted,
      ascending: ascending,
    );
  }
}

/// Row definition for [AdminDataTable].
class AdminDataRow {
  final List<Widget> cells;
  final VoidCallback? onTap;
  final bool selected;
  final ValueChanged<bool?>? onSelectChanged;

  const AdminDataRow({
    required this.cells,
    this.onTap,
    this.selected = false,
    this.onSelectChanged,
  });
}

/// Standardized Enterprise Data Table for Flutter Web Admin.
/// Aligned with docs/plan/admin-design-system.md (Section 5.4).
/// Features:
/// - 1px hairline border (`#E2E8F0`) with 8px micro-radius container (`AppRadius.table`).
/// - 38px fixed header row with subtle background (`#F8FAFC`).
/// - 44px fixed data rows with crisp neutral hover highlights.
/// - Bidirectional scrolling (vertical within bounded container, horizontal when needed).
/// - Pinned pagination footer bar that never gets pushed off-screen.
/// - Adaptive column spacing and container width utilization.
/// - Integrated loading spinner and empty states.
class AdminDataTable extends StatefulWidget {
  final List<AdminDataColumn> columns;
  final List<AdminDataRow> rows;
  final bool isLoading;
  final String? emptyMessage;
  final Widget? emptyIcon;
  final double columnSpacing;
  final double horizontalMargin;
  final double headingRowHeight;
  final double dataRowHeight;
  final double minWidth;
  // Pagination options
  final int? currentPage;
  final int? totalPages;
  final int? totalElements;
  final int? pageSize;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;

  const AdminDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.isLoading = false,
    this.emptyMessage = 'Không có dữ liệu phù hợp.',
    this.emptyIcon,
    this.columnSpacing = 24.0,
    this.horizontalMargin = 16.0,
    this.headingRowHeight = AppHeights.tableHeader,
    this.dataRowHeight = AppHeights.tableRow,
    this.minWidth = 720.0,
    this.currentPage,
    this.totalPages,
    this.totalElements,
    this.pageSize,
    this.onPageChanged,
    this.onPageSizeChanged,
  });

  @override
  State<AdminDataTable> createState() => _AdminDataTableState();
}

class _AdminDataTableState extends State<AdminDataTable> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final List<RowHoverTracker> _rowTrackers = [];

  void _syncTrackers() {
    while (_rowTrackers.length < widget.rows.length) {
      _rowTrackers.add(RowHoverTracker());
    }
    while (_rowTrackers.length > widget.rows.length) {
      _rowTrackers.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final tracker in _rowTrackers) {
      tracker.dispose();
    }
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  bool get _hasPagination =>
      widget.currentPage != null &&
      widget.totalPages != null &&
      widget.totalPages! > 0;

  @override
  Widget build(BuildContext context) {
    _syncTrackers();
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.maxHeight.isFinite;
        final effectiveMinWidth = widget.minWidth;
        final effectiveColumnSpacing = widget.columnSpacing;

        Widget contentWidget;
        if (widget.isLoading) {
          contentWidget = Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          );
        } else if (widget.rows.isEmpty) {
          contentWidget = Container(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.emptyIcon ??
                    const Icon(Icons.inbox_outlined, size: 36, color: AppColors.textMuted),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.emptyMessage ?? 'Không có dữ liệu phù hợp.',
                  style: AppTypography.bodyData.copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        } else {
          final dataTable = ConstrainedBox(
            constraints: BoxConstraints(minWidth: effectiveMinWidth),
            child: DataTable(
              showCheckboxColumn: false,
              columnSpacing: effectiveColumnSpacing,
              horizontalMargin: widget.horizontalMargin,
              headingRowHeight: widget.headingRowHeight,
              dataRowMinHeight: widget.dataRowHeight,
              dataRowMaxHeight: widget.dataRowHeight,
              headingRowColor: const WidgetStatePropertyAll(AppColors.surfaceSubtle),
              headingTextStyle: AppTypography.captionTable,
              dataTextStyle: AppTypography.bodyData,
              dividerThickness: 1.0,
              columns: widget.columns.map((col) {
                return DataColumn(
                  label: col.label,
                  tooltip: col.tooltip,
                  numeric: col.numeric,
                  onSort: col.onSort != null ? (_, _) => col.onSort!() : null,
                );
              }).toList(),
              rows: widget.rows.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                final tracker = _rowTrackers[index];

                return DataRow(
                  selected: row.selected,
                  onSelectChanged: row.onSelectChanged ??
                      (row.onTap != null ? (_) => row.onTap!() : (_) {}),
                  color: WidgetStateProperty.resolveWith<Color>((states) {
                    if (row.selected) return AppColors.primaryLight;
                    if (states.contains(WidgetState.hovered)) return AppColors.primaryTint;
                    return AppColors.surface;
                  }),
                  cells: row.cells.map((cell) {
                    return DataCell(
                      _RowCellHoverWrapper(
                        tracker: tracker,
                        child: cell,
                      ),
                      onTap: row.onTap,
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          );

          if (hasBoundedHeight) {
            contentWidget = Scrollbar(
              controller: _verticalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _verticalController,
                scrollDirection: Axis.vertical,
                physics: const ClampingScrollPhysics(),
                child: Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: true,
                  notificationPredicate: (notif) => notif.depth == 1,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: dataTable,
                  ),
                ),
              ),
            );
          } else {
            contentWidget = Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: dataTable,
              ),
            );
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.table),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (hasBoundedHeight)
                Expanded(child: contentWidget)
              else
                contentWidget,
              if (_hasPagination) ...[
                const Divider(height: 1, color: AppColors.border),
                _buildPaginationBar(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaginationBar() {
    final page = widget.currentPage ?? 0;
    final total = widget.totalPages ?? 1;
    final count = widget.totalElements ?? widget.rows.length;
    final size = widget.pageSize ?? 20;

    final startItem = (page * size) + (widget.rows.isNotEmpty ? 1 : 0);
    final endItem = (page * size) + widget.rows.length;

    return Container(
      height: AppHeights.paginationBar,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.table - 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Range indicator
          Flexible(
            child: Text(
              'Hiển thị $startItem - $endItem trong số $count bản ghi',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Pagination buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page, size: 18),
                tooltip: 'Trang đầu',
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: page > 0 ? () => widget.onPageChanged?.call(0) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                tooltip: 'Trang trước',
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: page > 0 ? () => widget.onPageChanged?.call(page - 1) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Trang ${page + 1} / $total',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                tooltip: 'Trang sau',
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: page < total - 1 ? () => widget.onPageChanged?.call(page + 1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page, size: 18),
                tooltip: 'Trang cuối',
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: page < total - 1 ? () => widget.onPageChanged?.call(total - 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RowCellHoverWrapper extends StatelessWidget {
  final RowHoverTracker tracker;
  final Widget child;

  const _RowCellHoverWrapper({
    required this.tracker,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => tracker.enter(),
      onExit: (_) => tracker.exit(),
      child: ValueListenableBuilder<bool>(
        valueListenable: tracker.isHovered,
        builder: (context, isHovered, ch) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(
              isHovered ? 1.5 : 0.0,
              0.0,
              0.0,
            ),
            child: ch,
          );
        },
        child: child,
      ),
    );
  }
}
