import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<User> signUp(String email, String password, String fullName) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw Exception('User creation failed, no user returned.');
    }
    return user;
  }

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  User? getCurrentUser() => _client.auth.currentUser;

  Future<void> signOut() async => await _client.auth.signOut();

  Future<void> createChat(String driverId, String passengerId) async {
    await _client.from('chats').insert({
      'driver_id': driverId,
      'passenger_id': passengerId,
      'messages': [],
    });
  }
}
