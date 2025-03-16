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
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _syncDrivers();
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _syncDrivers();
    });
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
              1000; // Convert to km
          if (distance <= 8) {
            nearbyDrivers.add(driver);
          }
        }
      }

      if (mounted) {
        setState(() {
          _nearbyDrivers = nearbyDrivers;
          if (requestedDriverId != null) {
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
        ).showSnackBar(SnackBar(content: const Text('Ride requested!')));
        _syncDrivers(); // Refresh to show requested driver
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
    return AlertDialog(
      title: const Text('Passenger Dashboard'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_requestedDriver != null) ...[
              const Text(
                'Requested Driver:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ListTile(
                title: Text(_requestedDriver!['full_name'] as String),
                subtitle: Text(
                  'Location: ${_requestedDriver!['live_location']}',
                ),
              ),
            ] else if (_nearbyDrivers.isEmpty) ...[
              const Text('No drivers within 8km.'),
            ] else ...[
              const Text(
                'Nearby Drivers:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ListView.builder(
                shrinkWrap: true,
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
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
