class PageResult<T> {
  final List<T> content;
  final int pageNumber;
  final int pageSize;
  final int totalElements;
  final int totalPages;
  final bool isLast;

  const PageResult({
    required this.content,
    required this.pageNumber,
    required this.pageSize,
    required this.totalElements,
    required this.totalPages,
    required this.isLast,
  });

  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic item) fromItemJson,
  ) {
    final list = json['content'];
    final items = <T>[];
    if (list is List) {
      for (final e in list) {
        try {
          items.add(fromItemJson(e));
        } catch (_) {
          // Gracefully omit individual malformed elements
        }
      }
    }

    final rawPageNumber = json['pageNumber'] ?? json['page'] ?? 0;
    final rawPageSize = json['pageSize'] ?? json['size'] ?? 10;
    final rawTotalElements = json['totalElements'] ?? items.length;
    final rawTotalPages = json['totalPages'] ?? 1;
    final rawIsLast = json['last'] ?? true;

    return PageResult<T>(
      content: items,
      pageNumber: rawPageNumber is num ? rawPageNumber.toInt() : 0,
      pageSize: rawPageSize is num ? rawPageSize.toInt() : 10,
      totalElements: rawTotalElements is num
          ? rawTotalElements.toInt()
          : items.length,
      totalPages: rawTotalPages is num ? rawTotalPages.toInt() : 1,
      isLast: rawIsLast is bool ? rawIsLast : true,
    );
  }

  bool get hasMore => !isLast && pageNumber + 1 < totalPages;
}
