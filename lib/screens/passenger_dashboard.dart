import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ride_along/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PassengerDashboard extends StatefulWidget {
  final String passengerId;

  const PassengerDashboard({super.key, required this.passengerId});

  @override
  _PassengerDashboardState createState() => _PassengerDashboardState();
}

class _PassengerDashboardState extends State<PassengerDashboard> {
  final _supabaseService = SupabaseService();
  final _supabaseClient = Supabase.instance.client;
  List<Map<String, dynamic>> _nearbyDrivers = [];
  Map<String, dynamic>? _requestedDriver;
  Map<String, dynamic>? _activeRide;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _syncDrivers();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) => _syncDrivers(),
    );
  }

  Future<void> _syncDrivers() async {
    try {
      final passengerProfile =
          await _supabaseClient
              .from('profiles')
              .select('school_id, live_location, ride_request_driver_id')
              .eq('id', widget.passengerId)
              .single();

      final schoolId = passengerProfile['school_id'] as String;
      final passengerLocation = passengerProfile['live_location'] as String;
      final requestedDriverId =
          passengerProfile['ride_request_driver_id'] as String?;

      // Check for an active ride
      final ride =
          await _supabaseClient
              .from('rides')
              .select('id, driver_id, status')
              .eq('status', 'pending')
              .contains('passenger_ids', [widget.passengerId])
              .maybeSingle();

      final drivers = await _supabaseClient
          .from('profiles')
          .select('id, full_name, live_location')
          .eq('role', 'driver')
          .eq('school_id', schoolId);

      final passengerCoords = _parseLocation(passengerLocation);
      List<Map<String, dynamic>> nearbyDrivers = [];

      for (var driver in drivers) {
        final driverLocation = driver['live_location'] as String?;
        if (driverLocation != null) {
          final driverCoords = _parseLocation(driverLocation);
          final distance =
              Geolocator.distanceBetween(
                passengerCoords[0],
                passengerCoords[1],
                driverCoords[0],
                driverCoords[1],
              ) /
              1000; // Convert meters to kilometers
          if (distance <= 8) {
            nearbyDrivers.add(driver);
          }
        }
      }

      if (mounted) {
        setState(() {
          _nearbyDrivers = nearbyDrivers;
          _activeRide = ride;
          if (_activeRide != null && _activeRide!['driver_id'] != null) {
            _requestedDriver = nearbyDrivers.firstWhere(
              (driver) => driver['id'] == _activeRide!['driver_id'],
              orElse:
                  () => {
                    'id': _activeRide!['driver_id'],
                    'full_name': 'Accepted Driver',
                    'live_location': 'Unknown',
                  },
            );
          } else if (requestedDriverId != null) {
            _requestedDriver = nearbyDrivers.firstWhere(
              (driver) => driver['id'] == requestedDriverId,
              orElse:
                  () => {
                    'id': requestedDriverId,
                    'full_name': 'Requested Driver',
                    'live_location': 'Unknown',
                  },
            );
          } else {
            _requestedDriver = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error syncing drivers: $e')));
      }
    }
  }

  List<double> _parseLocation(String location) {
    final parts = location.split(',');
    return [double.parse(parts[0]), double.parse(parts[1])];
  }

  Future<void> _requestDriver(String driverId) async {
    if (_activeRide != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already in an active ride.')),
      );
      return;
    }

    try {
      final currentRequest =
          await _supabaseClient
              .from('profiles')
              .select('ride_request_driver_id')
              .eq('id', widget.passengerId)
              .single();

      if (currentRequest['ride_request_driver_id'] != null) {
        throw Exception('You have already requested a ride.');
      }

      await _supabaseClient
          .from('profiles')
          .update({'ride_request_driver_id': driverId})
          .eq('id', widget.passengerId);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ride requested!')));
        _syncDrivers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error requesting driver: $e')));
      }
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passenger Dashboard')),
      body: Column(
        children: [
          if (_activeRide != null && _requestedDriver != null) ...[
            const Text(
              'Accepted Driver:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ListTile(
              title: Text(_requestedDriver!['full_name'] as String),
              subtitle: Text('Location: ${_requestedDriver!['live_location']}'),
            ),
          ] else if (_requestedDriver != null) ...[
            const Text(
              'Requested Driver:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ListTile(
              title: Text(_requestedDriver!['full_name'] as String),
              subtitle: Text('Location: ${_requestedDriver!['live_location']}'),
            ),
          ] else if (_nearbyDrivers.isEmpty) ...[
            const Center(child: Text('No drivers within 8km.')),
          ] else ...[
            const Text(
              'Nearby Drivers:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _nearbyDrivers.length,
                itemBuilder: (context, index) {
                  final driver = _nearbyDrivers[index];
                  return ListTile(
                    title: Text(driver['full_name'] as String),
                    subtitle: Text('Location: ${driver['live_location']}'),
                    trailing: ElevatedButton(
                      onPressed: () => _requestDriver(driver['id'] as String),
                      child: const Text('Request'),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
