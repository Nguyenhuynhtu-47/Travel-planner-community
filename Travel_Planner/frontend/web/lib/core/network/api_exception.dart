class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, String>? validationErrors;

  ApiException({
    required this.statusCode,
    required this.message,
    this.validationErrors,
  });

  @override
  String toString() => message;
}
