import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  
  AuthState({required this.status, this.errorMessage});
  
  AuthState copyWith({AuthStatus? status, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(() => _checkAuth());
    return AuthState(status: AuthStatus.initial);
  }

  Future<void> _checkAuth() async {
    final token = await ref.read(authRepositoryProvider).getToken();
    if (token != null) {
      state = state.copyWith(status: AuthStatus.authenticated);
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> verifyOTP(String phone, String otp) async {
    state = state.copyWith(status: AuthStatus.loading);
    
    final repo = ref.read(authRepositoryProvider);
    bool success;
    
    // Developer Shortcut: Bypass Firebase for easier local testing
    if (phone == '1234567890' || phone == '0000000000') {
      success = await repo.devLogin(phone);
    } else {
      // Normal Firebase flow (or mock logic)
      success = await repo.verifyFirebaseToken(phone);
    }

    if (success) {
      state = state.copyWith(status: AuthStatus.authenticated);
    } else {
      state = state.copyWith(
        status: AuthStatus.error, 
        errorMessage: "Login failed. Please check your connection."
      );
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
