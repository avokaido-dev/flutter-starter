import 'package:flutter/foundation.dart';

/// Stub [AuthService].
///
/// The UI calls into this so a click-through works without a backend.
/// The Avokaido batch runner REPLACES the body with a FirebaseAuth
/// implementation:
///   - `isSignedIn` reads `FirebaseAuth.instance.currentUser != null`
///   - `signIn` calls `signInWithEmailAndPassword`
///   - The class becomes a `ChangeNotifier` wrapping `authStateChanges`
///
/// TODO(avokaido): auth — wire FirebaseAuth.
///   Contract:
///     - isSignedIn returns true after a successful signIn / token refresh
///     - signOut clears the token and notifies listeners
///     - addListener is called by the router for redirect decisions
class AuthService extends ChangeNotifier {
  bool _signedIn = false;

  bool get isSignedIn => _signedIn;

  Future<void> signIn({required String email, required String password}) async {
    // No-op stub. Pretend the call succeeded so the UI advances.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _signedIn = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    _signedIn = false;
    notifyListeners();
  }
}

/// Shared singleton for the app. Replace with a Provider lookup once
/// the batch runner wires dependency injection.
final AuthService authService = AuthService();
