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
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();

  // Services and clients
  final _supabaseService = SupabaseService();
  final _supabaseClient = Supabase.instance.client;

  // State variables
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
      final String jsonString = await rootBundle.loadString(
        'assets/schools.json',
      );
      final data = jsonDecode(jsonString);
      setState(() {
        _schools = List<String>.from(data['schools']);
        _selectedSchool = null;
      });
    } catch (e) {
      _showErrorSnackBar('Error loading schools: $e');
    }
  }

  Future<void> _authenticate() async {
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _supabaseService.signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await _handleSignUp();
      }
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSignUp() async {
    if (_selectedSchool == null || !_schools.contains(_selectedSchool)) {
      throw Exception('Please select a valid school from the list');
    }

    final user = await _supabaseService.signUp(
      _emailController.text.trim(),
      _passwordController.text,
      _fullNameController.text.trim(),
    );

    final schoolId = await _getOrCreateSchoolId();
    await _updateUserProfile(user.id, schoolId);
  }

  Future<String> _getOrCreateSchoolId() async {
    final schoolResponse =
        await _supabaseClient
            .from('schools')
            .select('id')
            .eq('name', _selectedSchool!)
            .maybeSingle();

    if (schoolResponse == null) {
      final newSchool =
          await _supabaseClient
              .from('schools')
              .insert({'name': _selectedSchool!, 'location': '0,0'})
              .select('id')
              .single();
      return newSchool['id'] as String;
    }
    return schoolResponse['id'] as String;
  }

  Future<void> _updateUserProfile(String userId, String schoolId) async {
    await _supabaseClient.from('profiles').upsert({
      'id': userId,
      'full_name': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'school_id': schoolId,
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Login' : 'Sign Up'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400,
              ), // Optional: Limits width for larger screens
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isLogin) ...[
                      CustomTextField(
                        label: 'Full Name',
                        controller: _fullNameController,
                      ),
                      const SizedBox(height: 16),
                      _buildSchoolAutocomplete(),
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
                    const SizedBox(height: 24),
                    CustomButton(
                      text: _isLogin ? 'Login' : 'Sign Up',
                      onPressed: _authenticate,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 12),
                    _buildToggleButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolAutocomplete() {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty)
          return const Iterable<String>.empty();
        return _schools.where(
          (option) => option.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          ),
        );
      },
      onSelected: (String selection) {
        setState(() => _selectedSchool = selection);
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
    );
  }

  Widget _buildToggleButton() {
    return TextButton(
      onPressed: () => setState(() => _isLogin = !_isLogin),
      child: Text(
        _isLogin ? 'Need an account? Sign Up' : 'Have an account? Login',
        style: const TextStyle(fontSize: 16),
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
