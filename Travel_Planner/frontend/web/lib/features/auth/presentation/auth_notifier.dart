import 'package:flutter/material.dart';
import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../data/auth_storage.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthNotifier extends ChangeNotifier {
  final AuthRepository _repository;
  final AuthStorage _storage;

  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  Map<String, String>? _validationErrors;
  Map<String, dynamic>? _currentUser;
  String? _token;

  AuthNotifier({
    AuthRepository? repository,
    AuthStorage? storage,
  })  : _repository = repository ?? AuthRepository(),
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
    await _storage.clear();
    _token = null;
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
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
