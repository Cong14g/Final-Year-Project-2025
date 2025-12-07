import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<AuthResponse> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmailPassword(
    String email,
    String password,
    String firstName,
    String lastName, {
    String role = 'user',
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'first_name': firstName, 'last_name': lastName, 'role': role},
    );

    if (response.user != null) {
      await _supabase.auth.signInWithPassword(email: email, password: password);

      // Optional: Create a parallel user record in your public `users` table
      await _supabase.from('users').insert({
        'id': response.user!.id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
      });
    }

    return response;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<String?> getCurrentUserFirstName() async {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.userMetadata?['first_name']?.toString();
  }
}
