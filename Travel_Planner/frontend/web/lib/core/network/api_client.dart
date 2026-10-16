import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import 'api_exception.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

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
      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );

      return _handleResponse(response);
    } on http.ClientException {
      throw ApiException(
        statusCode: 0,
        message: 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'Lỗi kết nối máy chủ: $e',
      );
    }
  }

  Future<dynamic> get(
    String path, {
    String? token,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    final headers = {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await _client.get(uri, headers: headers);
      return _handleResponse(response);
    } on http.ClientException {
      throw ApiException(
        statusCode: 0,
        message: 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'Lỗi kết nối máy chủ: $e',
      );
    }
  }

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
}
