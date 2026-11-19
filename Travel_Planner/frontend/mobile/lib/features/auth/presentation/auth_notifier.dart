import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../data/auth_storage.dart';
import '../data/google_sign_in_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthNotifier extends ChangeNotifier {
  final AuthRepository _repository;
  final AuthStorage _storage;

  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  Map<String, String>? _validationErrors;
  Map<String, dynamic>? _currentUser;
  String? _token;

  AuthNotifier({AuthRepository? repository, AuthStorage? storage})
    : _repository = repository ?? AuthRepository(),
      _storage = storage ?? AuthStorage();

  AuthStatus get status => _status;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get errorMessage => _errorMessage;
  Map<String, String>? get validationErrors => _validationErrors;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get token => _token;

  Future<void> checkAuthStatus() async {
    final savedToken = await _storage.getToken();

    if (savedToken != null && savedToken.isNotEmpty) {
      if (!AuthStorage.isTokenExpired(savedToken)) {
        final cachedUser = await _storage.getUser();

        try {
          final verifiedUser = await _repository.getCurrentUser(savedToken);
          _token = savedToken;
          _currentUser = verifiedUser;
          await _storage.saveUser(verifiedUser);
          _status = AuthStatus.authenticated;
          notifyListeners();
          return;
        } on ApiException catch (e) {
          if (e.statusCode == 401 || e.statusCode == 403) {
            await _storage.clear();
            _token = null;
            _currentUser = null;
            _status = AuthStatus.unauthenticated;
            notifyListeners();
            return;
          }

          // Network error or server 500: do not assume token is invalid.
          // Maintain session with locally cached state if available.
          _token = savedToken;
          _currentUser = cachedUser;
          _status = AuthStatus.authenticated;
          notifyListeners();
          return;
        } catch (_) {
          // Other unexpected errors: retain existing valid session
          _token = savedToken;
          _currentUser = cachedUser;
          _status = AuthStatus.authenticated;
          notifyListeners();
          return;
        }
      }
    }

    await _storage.clear();
    _token = null;
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> login(String usernameOrEmail, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _validationErrors = null;
    notifyListeners();

    try {
      final response = await _repository.login(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );

      final token = response['token'] as String;
      final user = response['user'] as Map<String, dynamic>;

      await _storage.saveToken(token);
      await _storage.saveUser(user);

      _token = token;
      _currentUser = user;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      _validationErrors = e.validationErrors;
      notifyListeners();
      return false;
    } catch (_) {
      _status = AuthStatus.error;
      _errorMessage = 'Đã có lỗi xảy ra. Vui lòng thử lại sau.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle({GoogleSignInService? googleSignInService}) async {
    if (_status == AuthStatus.loading) {
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    _validationErrors = null;
    notifyListeners();

    try {
      final googleService = googleSignInService ?? GoogleSignInServiceImpl();
      final idToken = await googleService.signInAndGetIdToken();

      if (idToken == null) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }

      final response = await _repository.loginWithGoogle(idToken: idToken);

      final token = response['token'] as String;
      final user = response['user'] as Map<String, dynamic>;

      await _storage.saveToken(token);
      await _storage.saveUser(user);

      _token = token;
      _currentUser = user;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      debugPrint('[AuthNotifier] ApiException during Google login: ${e.statusCode} - ${e.message}');
      _status = AuthStatus.error;
      _errorMessage = e.message;
      _validationErrors = e.validationErrors;
      notifyListeners();
      return false;
    } catch (e, st) {
      debugPrint('[AuthNotifier] General exception during Google login: $e');
      debugPrint('[AuthNotifier] StackTrace: $st');
      _status = AuthStatus.error;
      _errorMessage = 'Đăng nhập Google thất bại: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> linkGoogle({
    required String idToken,
  }) async {
    if (_token == null) {
      _status = AuthStatus.error;
      _errorMessage = 'Bạn chưa đăng nhập.';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.linkGoogle(token: _token!, idToken: idToken);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _status = AuthStatus.error;
      _errorMessage = 'Liên kết tài khoản Google thất bại. Vui lòng thử lại sau.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _validationErrors = null;
    notifyListeners();

    try {
      final response = await _repository.register(
        username: username,
        email: email,
        password: password,
        fullName: fullName,
      );

      // In Phase 1, registration returns requiresVerification: true without token
      final token = response['token'] as String?;
      final user = response['user'] as Map<String, dynamic>?;

      if (token != null && user != null) {
        await _storage.saveToken(token);
        await _storage.saveUser(user);
        _token = token;
        _currentUser = user;
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      _validationErrors = e.validationErrors;
      notifyListeners();
      return false;
    } catch (_) {
      _status = AuthStatus.error;
      _errorMessage = 'Đã có lỗi xảy ra. Vui lòng thử lại sau.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyEmail({
    required String email,
    required String code,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _validationErrors = null;
    notifyListeners();

    try {
      final response = await _repository.verifyEmail(
        email: email,
        code: code,
      );

      final token = response['token'] as String;
      final user = response['user'] as Map<String, dynamic>;

      await _storage.saveToken(token);
      await _storage.saveUser(user);

      _token = token;
      _currentUser = user;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      _validationErrors = e.validationErrors;
      notifyListeners();
      return false;
    } catch (_) {
      _status = AuthStatus.error;
      _errorMessage = 'Đã có lỗi xảy ra. Vui lòng thử lại sau.';
      notifyListeners();
      return false;
    }
  }

  Future<String?> resendVerification({
    required String email,
  }) async {
    try {
      final response = await _repository.resendVerification(
        email: email,
      );
      return response['message'] as String?;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _validationErrors = null;
    notifyListeners();

    try {
      final response = await _repository.forgotPassword(email: email);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return response;
    } on ApiException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      _validationErrors = e.validationErrors;
      notifyListeners();
      rethrow;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Đã có lỗi xảy ra. Vui lòng thử lại sau.';
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyResetOtp({
    required String email,
    required String otp,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _validationErrors = null;
    notifyListeners();

    try {
      final response = await _repository.verifyResetOtp(
        email: email,
        otp: otp,
      );
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return response;
    } on ApiException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      _validationErrors = e.validationErrors;
      notifyListeners();
      rethrow;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Đã có lỗi xảy ra. Vui lòng thử lại sau.';
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    String? otp,
    String? resetToken,
    required String newPassword,
    String? confirmPassword,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _validationErrors = null;
    notifyListeners();

    try {
      final response = await _repository.resetPassword(
        email: email,
        otp: otp,
        resetToken: resetToken,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return response;
    } on ApiException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      _validationErrors = e.validationErrors;
      notifyListeners();
      rethrow;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Đã có lỗi xảy ra. Vui lòng thử lại sau.';
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final activeToken = _token ?? await _storage.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw ApiException(
        statusCode: 401,
        message: 'Không tìm thấy phiên đăng nhập. Vui lòng đăng nhập lại.',
      );
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    _validationErrors = null;
    notifyListeners();

    try {
      final response = await _repository.changePassword(
        token: activeToken,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      // Clear session locally because backend incremented token_version
      await logout();
      return response;
    } on ApiException catch (e) {
      _status = AuthStatus.authenticated;
      _errorMessage = e.message;
      _validationErrors = e.validationErrors;
      notifyListeners();
      rethrow;
    } catch (e) {
      _status = AuthStatus.authenticated;
      _errorMessage = 'Đã có lỗi xảy ra. Vui lòng thử lại sau.';
      notifyListeners();
      rethrow;
    }
  }

  bool _isHandlingSessionExpired = false;

  Future<void> handleSessionExpired() async {
    if (_status == AuthStatus.unauthenticated || _isHandlingSessionExpired) {
      return;
    }
    _isHandlingSessionExpired = true;
    try {
      await logout();
    } finally {
      _isHandlingSessionExpired = false;
    }
  }

  Future<void> logout() async {
    final activeToken = _token ?? await _storage.getToken();
    if (activeToken != null && activeToken.isNotEmpty) {
      try {
        await _repository.logout(activeToken);
      } catch (_) {
        // If server fails or offline, continue with local cleanup
      }
    }
    await _storage.clear();
    _token = null;
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getSessions() async {
    final activeToken = _token ?? await _storage.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      return [];
    }
    return await _repository.getSessions(activeToken);
  }

  Future<void> revokeSession(String sessionId) async {
    final activeToken = _token ?? await _storage.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw ApiException(
        statusCode: 401,
        message: 'Không tìm thấy phiên đăng nhập. Vui lòng đăng nhập lại.',
      );
    }
    await _repository.revokeSession(token: activeToken, sessionId: sessionId);
  }

  Future<int> revokeOtherSessions() async {
    final activeToken = _token ?? await _storage.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw ApiException(
        statusCode: 401,
        message: 'Không tìm thấy phiên đăng nhập. Vui lòng đăng nhập lại.',
      );
    }
    return await _repository.revokeOtherSessions(activeToken);
  }

  Future<Map<String, dynamic>> requestEmailChange({
    required String newEmail,
    String? password,
  }) async {
    final activeToken = _token ?? await _storage.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw ApiException(
        statusCode: 401,
        message: 'Không tìm thấy phiên đăng nhập. Vui lòng đăng nhập lại.',
      );
    }

    return await _repository.requestEmailChange(
      token: activeToken,
      newEmail: newEmail,
      password: password,
    );
  }

  Future<Map<String, dynamic>> verifyEmailChange({
    required String newEmail,
    required String otp,
  }) async {
    final activeToken = _token ?? await _storage.getToken();
    if (activeToken == null || activeToken.isEmpty) {
      throw ApiException(
        statusCode: 401,
        message: 'Không tìm thấy phiên đăng nhập. Vui lòng đăng nhập lại.',
      );
    }

    final response = await _repository.verifyEmailChange(
      token: activeToken,
      newEmail: newEmail,
      otp: otp,
    );

    var userToUpdate = _currentUser ?? await _storage.getUser();
    if (userToUpdate != null) {
      final updatedUser = Map<String, dynamic>.from(userToUpdate);
      updatedUser['email'] = newEmail;
      updatedUser['emailVerified'] = true;
      await updateCurrentUser(updatedUser);
    }

    return response;
  }

  Future<void> updateCurrentUser(Map<String, dynamic> user) async {
    _currentUser = user;
    await _storage.saveUser(user);
    notifyListeners();
  }

  void clearErrors() {
    _errorMessage = null;
    _validationErrors = null;
    notifyListeners();
  }
}
