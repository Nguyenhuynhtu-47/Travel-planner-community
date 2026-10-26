import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../explore_notifier.dart';

class FilterBottomSheet extends StatefulWidget {
  final ExploreFilter initialFilter;
  final String initialSort;
  final Function(ExploreFilter filter, String sort) onApply;

  const FilterBottomSheet({
    super.key,
    required this.initialFilter,
    required this.initialSort,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required ExploreFilter currentFilter,
    required String currentSort,
    required Function(ExploreFilter filter, String sort) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheet(
        initialFilter: currentFilter,
        initialSort: currentSort,
        onApply: onApply,
      ),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late final TextEditingController _locationController;
  late final TextEditingController _minBudgetController;
  late final TextEditingController _maxBudgetController;
  late final TextEditingController _minDaysController;
  late final TextEditingController _maxDaysController;

  String? _selectedTheme;
  double? _selectedMinRating;
  late String _selectedSort;

  final List<String> _popularThemes = [
    'Nghỉ dưỡng',
    'Phượt',
    'Ẩm thực',
    'Khám phá',
    'Văn hóa',
    'Gia đình',
  ];

  final List<String> _popularLocations = [
    'Đà Lạt',
    'Đà Nẵng',
    'Hà Nội',
    'Phú Quốc',
    'Hội An',
    'Sapa',
    'Nha Trang',
  ];

  final Map<String, String> _sortOptions = {
    'createdAt,desc': 'Mới nhất',
    'rating,desc': 'Đánh giá cao nhất',
    'budget,asc': 'Ngân sách: Thấp đến cao',
    'budget,desc': 'Ngân sách: Cao đến thấp',
    'totalDays,asc': 'Số ngày: Ngắn nhất',
    'viewCount,desc': 'Xem nhiều nhất',
  };

  @override
  void initState() {
    super.initState();
    final filter = widget.initialFilter;
    _locationController = TextEditingController(text: filter.location ?? '');
    _minBudgetController = TextEditingController(
      text: filter.minBudget != null
          ? filter.minBudget!.toInt().toString()
          : '',
    );
    _maxBudgetController = TextEditingController(
      text: filter.maxBudget != null
          ? filter.maxBudget!.toInt().toString()
          : '',
    );
    _minDaysController = TextEditingController(
      text: filter.minDays != null ? filter.minDays.toString() : '',
    );
    _maxDaysController = TextEditingController(
      text: filter.maxDays != null ? filter.maxDays.toString() : '',
    );
    _selectedTheme = filter.theme;
    _selectedMinRating = filter.minRating;
    _selectedSort = widget.initialSort;
  }

  @override
  void dispose() {
    _locationController.dispose();
    _minBudgetController.dispose();
    _maxBudgetController.dispose();
    _minDaysController.dispose();
    _maxDaysController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _locationController.clear();
      _minBudgetController.clear();
      _maxBudgetController.clear();
      _minDaysController.clear();
      _maxDaysController.clear();
      _selectedTheme = null;
      _selectedMinRating = null;
      _selectedSort = 'createdAt,desc';
    });
  }

  void _apply() {
    final minBudget = double.tryParse(_minBudgetController.text.trim());
    final maxBudget = double.tryParse(_maxBudgetController.text.trim());
    final minDays = int.tryParse(_minDaysController.text.trim());
    final maxDays = int.tryParse(_maxDaysController.text.trim());

    final filter = ExploreFilter(
      location: _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : null,
      theme: _selectedTheme,
      minBudget: minBudget,
      maxBudget: maxBudget,
      minDays: minDays,
      maxDays: maxDays,
      minRating: _selectedMinRating,
    );

    widget.onApply(filter, _selectedSort);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Bộ lọc & Sắp xếp',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      color: AppColors.textPrimary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.hairline),

              // Filter Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sắp xếp
                      const Text(
                        'Sắp xếp theo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _sortOptions.entries.map((entry) {
                          final isSelected = _selectedSort == entry.key;
                          return ChoiceChip(
                            label: Text(entry.value),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedSort = entry.key);
                              }
                            },
                            selectedColor: AppColors.textPrimary,
                            backgroundColor: AppColors.surface,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.border,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9999),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Điểm đến
                      const Text(
                        'Điểm đến / Tỉnh thành',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _locationController,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Ví dụ: Đà Lạt, Phú Quốc...',
                          prefixIcon: const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _popularLocations.map((loc) {
                          return ActionChip(
                            label: Text(loc),
                            onPressed: () {
                              setState(() {
                                _locationController.text = loc;
                              });
                            },
                            backgroundColor: AppColors.surfaceSoft,
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9999),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Chủ đề du lịch
                      const Text(
                        'Chủ đề chuyến đi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _popularThemes.map((theme) {
                          final isSelected = _selectedTheme == theme;
                          return ChoiceChip(
                            label: Text(theme),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedTheme = selected ? theme : null;
                              });
                            },
                            selectedColor: AppColors.textPrimary,
                            backgroundColor: AppColors.surface,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.border,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9999),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Số ngày
                      const Text(
                        'Thời gian chuyến đi (Số ngày)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minDaysController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Tối thiểu',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              '—',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _maxDaysController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Tối đa',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Ngân sách
                      const Text(
                        'Khoảng ngân sách dự kiến (VNĐ)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minBudgetController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Từ (VNĐ)',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              '—',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _maxBudgetController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Đến (VNĐ)',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Đánh giá tối thiểu
                      const Text(
                        'Đánh giá tối thiểu',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Tất cả'),
                            selected: _selectedMinRating == null,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedMinRating = null);
                              }
                            },
                            selectedColor: AppColors.textPrimary,
                            backgroundColor: AppColors.surface,
                            labelStyle: TextStyle(
                              color: _selectedMinRating == null
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: _selectedMinRating == null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            side: BorderSide(
                              color: _selectedMinRating == null
                                  ? AppColors.textPrimary
                                  : AppColors.border,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9999),
                            ),
                          ),
                          ...[3.0, 4.0, 4.5].map((rating) {
                            final isSelected = _selectedMinRating == rating;
                            return ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    size: 15,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text('$rating+'),
                                ],
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedMinRating = selected ? rating : null;
                                });
                              },
                              selectedColor: AppColors.textPrimary,
                              backgroundColor: AppColors.surface,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.border,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9999),
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _reset,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Đặt lại'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppPrimaryButton(
                        text: 'Áp dụng',
                        onPressed: _apply,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
