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
    // We can't await async in build synchronously if it returns AuthState
    // So we queue a future to update it.
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

  Future<void> verifyOTP(
    String phone, 
    String otp, {
    String name = '', 
    String email = '', 
    String location = ''
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    
    final repo = ref.read(authRepositoryProvider);
    final error = await repo.verifyOTPDemo(
      phone: phone,
      otp: otp,
      name: name,
      email: email,
      location: location,
    );
    
    if (error == null) {
      state = state.copyWith(status: AuthStatus.authenticated);
    } else {
      state = state.copyWith(
        status: AuthStatus.error, 
        errorMessage: error
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
