import 'package:flutter/material.dart';
import 'package:ride_along/services/supabase_service.dart';
import 'package:ride_along/widgets/loading_indicator.dart';

class SupabaseGate extends StatefulWidget {
  const SupabaseGate({super.key});

  @override
  _SupabaseGateState createState() => _SupabaseGateState();
}

class _SupabaseGateState extends State<SupabaseGate> {
  final _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final user = _supabaseService.getCurrentUser();
    await Future.delayed(Duration.zero); // Ensure context is available
    if (!mounted) return; // Check if widget is still mounted
    if (user != null) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: LoadingIndicator());
  }
}
