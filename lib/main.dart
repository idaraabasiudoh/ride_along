import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'routes.dart';
import 'themes/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://ijloqlvviyfyathgelge.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlqbG9xbHZ2aXlmeWF0aGdlbGdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIwNTg1MzAsImV4cCI6MjA1NzYzNDUzMH0.9adAs-vqUVSyfEp6XRGPqX4-UxCtEuYJ66hB7SkGcEA',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ride Along',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Switches based on system settings
      initialRoute: '/',
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
