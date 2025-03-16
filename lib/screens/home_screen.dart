import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ride_along/screens/chat_screen.dart';
import 'package:ride_along/screens/driver_dashboard.dart';
import 'package:ride_along/screens/passenger_dashboard.dart';
import 'package:ride_along/services/supabase_service.dart';
import 'package:ride_along/widgets/custom_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
  String? _currentRole;
  Map<String, dynamic>? _activeRide;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    final user = _supabaseService.getCurrentUser();
    if (user == null) return;

    try {
      final profile =
          await _supabaseClient
              .from('profiles')
              .select('role')
              .eq('id', user.id)
              .single();

      final ride =
          await _supabaseClient
              .from('rides')
              .select('id, status, driver_id, passenger_ids')
              .or('driver_id.eq.${user.id},passenger_ids.cs.{${user.id}}')
              .eq('status', 'pending')
              .maybeSingle();

      if (mounted) {
        setState(() {
          _currentRole = profile['role'] as String?;
          _activeRide = ride;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error checking status: $e')));
    }
  }

  Future<void> _requestLocationPermissionAndUpdate(String role) async {
    if (_activeRide != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot switch roles during an active ride.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String liveLocation = '${position.latitude},${position.longitude}';

      final user = _supabaseService.getCurrentUser();
      if (user != null) {
        await _supabaseClient
            .from('profiles')
            .update({'role': role, 'live_location': liveLocation})
            .eq('id', user.id);

        if (mounted) {
          setState(() {
            _currentRole = role;
          });
          _checkUserStatus();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchChats() async {
    final user = _supabaseService.getCurrentUser();
    if (user == null) return [];

    final profile =
        await _supabaseClient
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .single();

    final role = profile['role'];
    final chats = await _supabaseClient
        .from('chats')
        .select()
        .or('driver_id.eq.${user.id},passenger_id.eq.${user.id}');

    return chats.map((chat) {
      final otherUserId =
          role == 'driver' ? chat['passenger_id'] : chat['driver_id'];
      return {'chat_id': chat['id'], 'other_user_id': otherUserId};
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchRideParticipants() async {
    final user = _supabaseService.getCurrentUser();
    if (user == null || _activeRide == null) return [];

    List<Map<String, dynamic>> participants = [];

    if (_currentRole != 'driver' && _activeRide!['driver_id'] != null) {
      final driver =
          await _supabaseClient
              .from('profiles')
              .select('id, live_location')
              .eq('id', _activeRide!['driver_id'])
              .not('live_location', 'is', null)
              .single();
      participants.add(driver);
    }

    if (_activeRide!['passenger_ids'] != null) {
      final passengers = await _supabaseClient
          .from('profiles')
          .select('id, live_location')
          .inFilter('id', _activeRide!['passenger_ids'] as List)
          .not('live_location', 'is', null);
      participants.addAll(passengers);
    }

    return participants;
  }

  Widget _buildMapsScreen() {
    final user = _supabaseService.getCurrentUser();
    if (user == null) return const Center(child: Text('Please log in.'));

    return StreamBuilder<Position>(
      stream: Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ),
      builder: (context, positionSnapshot) {
        if (!positionSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final currentPosition = LatLng(
          positionSnapshot.data!.latitude,
          positionSnapshot.data!.longitude,
        );

        List<Marker> markers = [
          Marker(
            point: currentPosition,
            child: Icon(
              Icons.person_pin_circle,
              color: _activeRide == null ? Colors.blue : Colors.green,
              size: 40,
            ),
          ),
        ];

        if (_activeRide != null) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchRideParticipants(),
            builder: (context, participantsSnapshot) {
              if (participantsSnapshot.hasData) {
                markers.addAll(
                  participantsSnapshot.data!
                      .where((p) => p['id'] != user.id)
                      .map((participant) {
                        final location =
                            (participant['live_location'] as String).split(',');
                        final position = LatLng(
                          double.parse(location[0]),
                          double.parse(location[1]),
                        );

                        if (_currentRole == 'driver' &&
                            participant['id'] == _activeRide!['driver_id']) {
                          return Marker(
                            point: position,
                            child: const Icon(
                              Icons.directions_car,
                              color: Colors.red,
                              size: 40,
                            ),
                          );
                        }
                        return Marker(
                          point: position,
                          child: const Icon(
                            Icons.person_pin_circle,
                            color: Colors.pink,
                            size: 30,
                          ),
                        );
                      }),
                );
              }

              return FlutterMap(
                options: MapOptions(
                  initialCenter: currentPosition,
                  initialZoom: 13.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  MarkerLayer(markers: markers),
                ],
              );
            },
          );
        }

        return FlutterMap(
          options: MapOptions(
            initialCenter: currentPosition,
            initialZoom: 13.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
            ),
            MarkerLayer(markers: markers),
          ],
        );
      },
    );
  }

  Widget _buildBody() {
    final user = _supabaseService.getCurrentUser();
    if (user == null) {
      return const Center(child: Text('Please log in.'));
    }

    if (_activeRide != null && _selectedIndex == 0) {
      if (_currentRole == 'driver') {
        return DriverDashboard(driverId: user.id);
      } else if (_currentRole == 'passenger') {
        return PassengerDashboard(passengerId: user.id);
      }
    }

    Widget getContent() {
      switch (_selectedIndex) {
        case 0: // Home
          if (_currentRole == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Please select your role:',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: 'Driver',
                    onPressed:
                        () => _requestLocationPermissionAndUpdate('driver'),
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
          }
          return _currentRole == 'driver'
              ? DriverDashboard(driverId: user.id)
              : PassengerDashboard(passengerId: user.id);

        case 1: // Chat
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchChats(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final chats = snapshot.data ?? [];
              if (chats.isEmpty) {
                return Center(
                  child: Text(
                    'No chats yet.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: GestureDetector(
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => ChatScreen(
                                    chatId: chat['chat_id'] as String,
                                    otherUserId:
                                        chat['other_user_id'] as String,
                                  ),
                            ),
                          ),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12.0),
                        child: FutureBuilder<Map<String, dynamic>>(
                          future:
                              _supabaseClient
                                  .from('profiles')
                                  .select('full_name')
                                  .eq('id', chat['other_user_id'])
                                  .single(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Text(
                                'Loading...',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              );
                            }
                            return Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.1),
                                  ),
                                  child: Center(
                                    child: Text(
                                      snapshot.data!['full_name'][0]
                                          .toString()
                                          .toUpperCase(),
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    snapshot.data!['full_name'] as String,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.copyWith(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );

        case 2: // Maps
          return _buildMapsScreen();

        case 3: // Profile
          return ProfileScreen(userId: user.id);

        default:
          return const Center(child: Text('Unknown Tab'));
      }
    }

    return getContent();
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
            activeIcon: Icon(Icons.home_filled),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
            activeIcon: Icon(Icons.chat_bubble),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Maps',
            activeIcon: Icon(Icons.map_rounded),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
            activeIcon: Icon(Icons.person_rounded),
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(
          context,
        ).colorScheme.onSurface.withOpacity(0.6),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}

// New ProfileScreen widget
class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabaseService = SupabaseService();
  final _supabaseClient = Supabase.instance.client;
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _activeRide;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final profile =
          await _supabaseClient
              .from('profiles')
              .select('full_name, role, email')
              .eq('id', widget.userId)
              .single();

      final ride =
          await _supabaseClient
              .from('rides')
              .select('id, status, driver_id, passenger_ids')
              .or(
                'driver_id.eq.${widget.userId},passenger_ids.cs.{${widget.userId}}',
              )
              .inFilter('status', ['pending', 'accepted'])
              .maybeSingle();

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _activeRide = ride;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Account'),
            content: const Text(
              'Are you sure you want to delete your account? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _supabaseClient.rpc(
        'delete_user',
        params: {'user_id': widget.userId},
      );
      await _supabaseService.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/auth');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting account: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_userProfile != null) ...[
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Name: ${_userProfile!['full_name'] ?? 'Not set'}',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Email: ${_userProfile!['email'] ?? 'Not set'}',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Role: ${_userProfile!['role'] ?? 'Not selected'}',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ride Status',
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _activeRide != null
                                ? 'Active Ride - Status: ${_activeRide!['status']}'
                                : 'No active ride',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: 'Logout',
                    onPressed: () async {
                      await _supabaseService.signOut();
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, '/auth');
                      }
                    },
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 10),
                  CustomButton(
                    text: 'Delete Account',
                    onPressed: _deleteAccount,
                    isLoading: _isLoading,
                  ),
                ],
              ),
    );
  }
}
