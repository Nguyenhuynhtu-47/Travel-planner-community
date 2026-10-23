import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import 'api_exception.dart';

class ApiClient {
  static const Duration _requestTimeout = Duration(seconds: 15);
  final http.Client _client;
  final void Function()? onUnauthorized;

  static void Function()? globalOnUnauthorized;
  static DateTime? _lastUnauthorizedNotification;
  static const Duration _unauthorizedThrottle = Duration(seconds: 2);

  static void resetThrottle() {
    _lastUnauthorizedNotification = null;
  }

  ApiClient({http.Client? client, this.onUnauthorized})
    : _client = client ?? http.Client();

  Future<dynamic> post(
    String path, {
    required Map<String, dynamic> body,
    String? token,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await _client
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(_requestTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw _timeoutException();
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.',
      );
    } on http.ClientException {
      throw ApiException(
        statusCode: 0,
        message: 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.',
      );
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? token,
  }) async {
    Uri uri = Uri.parse('${ApiConstants.baseUrl}$path');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final sanitizedParams = <String, String>{};
      queryParameters.forEach((key, value) {
        if (value != null) {
          sanitizedParams[key] = value.toString();
        }
      });
      if (sanitizedParams.isNotEmpty) {
        uri = uri.replace(
          queryParameters: {...uri.queryParameters, ...sanitizedParams},
        );
      }
    }

    final headers = {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(_requestTimeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw _timeoutException();
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.',
      );
    } on http.ClientException {
      throw ApiException(
        statusCode: 0,
        message: 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.',
      );
    }
  }

  Future<dynamic> put(
    String path, {
    required Map<String, dynamic> body,
    String? token,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    try {
      final response = await _client
          .put(uri, headers: headers, body: jsonEncode(body))
          .timeout(_requestTimeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw _timeoutException();
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.',
      );
    } on http.ClientException {
      throw ApiException(
        statusCode: 0,
        message: 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.',
      );
    }
  }

  ApiException _timeoutException() => ApiException(
    statusCode: 0,
    message: 'Máy chủ không phản hồi sau 15 giây. Hãy kiểm tra điện thoại và máy tính có cùng Wi-Fi, địa chỉ API và trạng thái backend.',
  );

  dynamic _handleResponse(http.Response response) {
    dynamic responseData;
    try {
      if (response.body.isNotEmpty) {
        responseData = jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (_) {
      responseData = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseData;
    }

    if (response.statusCode == 401) {
      _notifyUnauthorized();
    }

    String message = 'Đã có lỗi xảy ra. Vui lòng thử lại sau.';
    Map<String, String>? validationErrors;

    if (responseData is Map<String, dynamic>) {
      if (responseData['message'] is String) {
        message = responseData['message'];
      }
      if (responseData['validationErrors'] is Map) {
        validationErrors = (responseData['validationErrors'] as Map).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      }
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: message,
      validationErrors: validationErrors,
    );
  }

  void _notifyUnauthorized() {
    final now = DateTime.now();
    if (_lastUnauthorizedNotification != null &&
        now.difference(_lastUnauthorizedNotification!) <
            _unauthorizedThrottle) {
      return;
    }
    _lastUnauthorizedNotification = now;

    if (onUnauthorized != null) {
      onUnauthorized!();
    } else if (globalOnUnauthorized != null) {
      globalOnUnauthorized!();
    }
  }
}
