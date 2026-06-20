import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthState { unauthenticated, authenticated, loading }

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState.unauthenticated;
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
