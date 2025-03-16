import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ride_along/services/supabase_service.dart';
import 'package:ride_along/widgets/custom_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabaseService = SupabaseService();
  final _supabaseClient = Supabase.instance.client;
  int _selectedIndex = 0;
  bool _isLoading = false;

  Future<void> _requestLocationPermissionAndUpdate(String role) async {
    setState(() => _isLoading = true);
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      // Check and request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      // Get live location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String liveLocation = '${position.latitude},${position.longitude}';

      // Update profile with role and location
      final user = _supabaseService.getCurrentUser();
      if (user != null) {
        await _supabaseClient
            .from('profiles')
            .update({'role': role, 'live_location': liveLocation})
            .eq('id', user.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: // Home
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Please select your role:',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: 'Driver',
                onPressed: () => _requestLocationPermissionAndUpdate('driver'),
                isLoading: _isLoading,
              ),
              const SizedBox(height: 10),
              CustomButton(
                text: 'Passenger',
                onPressed:
                    () => _requestLocationPermissionAndUpdate('passenger'),
                isLoading: _isLoading,
              ),
            ],
          ),
        );
      case 1: // Chat
        return const Center(child: Text('Chat - Coming Soon'));
      case 2: // Profile
        return const Center(child: Text('Profile - Coming Soon'));
      default:
        return const Center(child: Text('Unknown Tab'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Along'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _supabaseService.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/auth');
              }
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}
