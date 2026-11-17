import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/api_constants.dart';

abstract class GoogleSignInService {
  /// Prompts the user to select their Google account, authenticates,
  /// and returns the raw Google ID Token string.
  /// Returns null if the user cancelled the dialog.
  Future<String?> signInAndGetIdToken();

  /// Signs out of the local Google session.
  Future<void> signOut();
}

class GoogleSignInServiceImpl implements GoogleSignInService {
  final GoogleSignIn _googleSignIn;

  GoogleSignInServiceImpl({GoogleSignIn? googleSignIn, String? serverClientId})
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              serverClientId: serverClientId ??
                  (ApiConstants.googleServerClientId.isNotEmpty
                      ? ApiConstants.googleServerClientId
                      : null),
              scopes: const ['email', 'profile'],
            );

  @override
  Future<String?> signInAndGetIdToken() async {
    try {
      debugPrint('[GoogleSignInService] Calling _googleSignIn.signIn()...');
      final account = await _googleSignIn.signIn();
      debugPrint('[GoogleSignInService] Account result: ${account?.email ?? "null"}');
      if (account == null) {
        debugPrint('[GoogleSignInService] User cancelled or Google Play Services returned null');
        return null;
      }
      debugPrint('[GoogleSignInService] Calling account.authentication...');
      final auth = await account.authentication;
      final idToken = auth.idToken;
      debugPrint('[GoogleSignInService] idToken received: ${idToken != null ? "YES (length ${idToken.length})" : "NO (null)"}');
      if (idToken == null) {
        debugPrint('[GoogleSignInService] WARNING: idToken is null! On Android, requesting an ID token requires serverClientId (Web Client ID).');
      }
      return idToken;
    } catch (e, st) {
      debugPrint('[GoogleSignInService] Exception during Google Sign-In: $e');
      debugPrint('[GoogleSignInService] StackTrace: $st');
      rethrow;
    } finally {
      // Do not retain persistent Google SDK session locally
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }
}
