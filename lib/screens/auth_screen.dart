import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ride_along/services/supabase_service.dart';
import 'package:ride_along/widgets/custom_button.dart';
import 'package:ride_along/widgets/custom_text_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _supabaseService = SupabaseService();
  final _supabaseClient = Supabase.instance.client;
  bool _isLogin = true;
  bool _isLoading = false;
  List<String> _schools = [];
  String? _selectedSchool;

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/schools.json',
      );
      final data = json.decode(response);
      setState(() {
        _schools = List<String>.from(data['schools']);
        _selectedSchool = null; // No default selection for autocomplete
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading schools: $e')));
    }
  }

  Future<void> _authenticate() async {
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await _supabaseService.signIn(
          _emailController.text,
          _passwordController.text,
        );
      } else {
        if (_selectedSchool == null || !_schools.contains(_selectedSchool)) {
          throw Exception('Please select a valid school from the list.');
        }
        // Sign up with email, password, and full name
        final user = await _supabaseService.signUp(
          _emailController.text,
          _passwordController.text,
          _fullNameController.text,
        );

        // Check if the school exists in the schools table
        final schoolResponse =
            await _supabaseClient
                .from('schools')
                .select('id')
                .eq('name', _selectedSchool!)
                .maybeSingle();

        String schoolId;
        if (schoolResponse == null) {
          // School doesn’t exist, create it
          final newSchool =
              await _supabaseClient
                  .from('schools')
                  .insert({
                    'name': _selectedSchool!,
                    'location': '0,0', // Default location; update as needed
                  })
                  .select('id')
                  .single();
          schoolId = newSchool['id'] as String;
        } else {
          schoolId = schoolResponse['id'] as String;
        }

        // Update the profiles table
        await _supabaseClient.from('profiles').upsert({
          'id': user.id,
          'full_name': _fullNameController.text,
          'email': _emailController.text,
          'school_id': schoolId,
        });
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isLogin) ...[
                CustomTextField(
                  label: 'Full Name',
                  controller: _fullNameController,
                ),
                const SizedBox(height: 16),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return _schools.where((String option) {
                      return option.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      );
                    });
                  },
                  onSelected: (String selection) {
                    setState(() {
                      _selectedSchool = selection;
                    });
                  },
                  fieldViewBuilder: (
                    BuildContext context,
                    TextEditingController fieldTextEditingController,
                    FocusNode fieldFocusNode,
                    VoidCallback onFieldSubmitted,
                  ) {
                    return TextField(
                      controller: fieldTextEditingController,
                      focusNode: fieldFocusNode,
                      decoration: InputDecoration(
                        labelText: 'School',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Password',
                controller: _passwordController,
                obscureText: true,
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: _isLogin ? 'Login' : 'Sign Up',
                onPressed: _authenticate,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(
                  _isLogin
                      ? 'Need an account? Sign Up'
                      : 'Have an account? Login',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }
}
