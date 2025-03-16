import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:ride_along/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverDashboard extends StatefulWidget {
  final String driverId;

  const DriverDashboard({super.key, required this.driverId});

  @override
  _DriverDashboardState createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final _supabaseService = SupabaseService();
  final _supabaseClient = Supabase.instance.client;
  List<Map<String, dynamic>> _passengerRequests = [];
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _syncPassengerRequests();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) => _syncPassengerRequests(),
    );
  }

  Future<String?> _coordsToAddress(String? coords) async {
    if (coords == null) return 'Unknown';
    try {
      final parts = coords.split(',');
      final lat = double.parse(parts[0]);
      final lon = double.parse(parts[1]);
      final addresses = await placemarkFromCoordinates(lat, lon);
      return addresses.isNotEmpty
          ? '${addresses.first.street}, ${addresses.first.locality}'
          : 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _syncPassengerRequests() async {
    try {
      final driverProfile =
          await _supabaseClient
              .from('profiles')
              .select('school_id')
              .eq('id', widget.driverId)
              .single();

      final schoolId = driverProfile['school_id'] as String;
      final requests = await _supabaseClient
          .from('profiles')
          .select('id, full_name, live_location')
          .eq('role', 'passenger')
          .eq('school_id', schoolId)
          .eq('ride_request_driver_id', widget.driverId);

      if (mounted) {
        setState(() {
          _passengerRequests = List<Map<String, dynamic>>.from(requests);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error syncing requests: $e')));
      }
    }
  }

  Future<void> _acceptPassenger(
    String passengerId,
    String passengerName,
    String passengerLocation,
  ) async {
    try {
      final existingRide =
          await _supabaseClient
              .from('rides')
              .select('id, passenger_ids')
              .eq('driver_id', widget.driverId)
              .eq('status', 'pending')
              .maybeSingle();

      String rideId;
      List<String> passengerIds = [];

      if (existingRide != null) {
        rideId = existingRide['id'] as String;
        passengerIds = List<String>.from(existingRide['passenger_ids'] as List);
        if (passengerIds.length >= 4) {
          throw Exception('Maximum passenger limit (4) reached.');
        }
        passengerIds.add(passengerId);
        await _supabaseClient
            .from('rides')
            .update({'passenger_ids': passengerIds})
            .eq('id', rideId);
      } else {
        final driverProfile =
            await _supabaseClient
                .from('profiles')
                .select('school_id')
                .eq('id', widget.driverId)
                .single();
        final schoolId = driverProfile['school_id'] as String;

        final newRide =
            await _supabaseClient
                .from('rides')
                .insert({
                  'driver_id': widget.driverId,
                  'passenger_ids': [passengerId],
                  'school_id': schoolId,
                  'status': 'pending',
                  'start_location': passengerLocation,
                  'departure_time': DateTime.now().toIso8601String(),
                })
                .select('id')
                .single();
        rideId = newRide['id'] as String;
      }

      await _supabaseService.createChat(widget.driverId, passengerId);
      await _supabaseClient
          .from('profiles')
          .update({'ride_request_driver_id': null})
          .eq('id', passengerId);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Accepted $passengerName')));
        _syncPassengerRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting passenger: $e')),
        );
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Dashboard')),
      body:
          _passengerRequests.isEmpty
              ? const Center(child: Text('No passenger requests yet.'))
              : ListView.builder(
                itemCount: _passengerRequests.length,
                itemBuilder: (context, index) {
                  final passenger = _passengerRequests[index];
                  return FutureBuilder<String?>(
                    future: _coordsToAddress(
                      passenger['live_location'] as String?,
                    ),
                    builder: (context, snapshot) {
                      final location = snapshot.data ?? 'Loading...';
                      return ListTile(
                        title: Text(
                          passenger['full_name'] as String,
                          style: theme.textTheme.bodyLarge,
                        ),
                        subtitle: Text(
                          'Location: $location',
                          style: theme.textTheme.bodyMedium,
                        ),
                        trailing: ElevatedButton(
                          onPressed:
                              () => _acceptPassenger(
                                passenger['id'] as String,
                                passenger['full_name'] as String,
                                passenger['live_location'] as String,
                              ),
                          child: const Text('Accept'),
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}
