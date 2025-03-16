import 'dart:async';
import 'package:flutter/material.dart';
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
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _syncPassengerRequests();
    });
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
                  'start_location':
                      passengerLocation, // Use passenger's location as start
                  'departure_time': DateTime.now().toIso8601String(),
                })
                .select('id')
                .single();
        rideId = newRide['id'] as String;
      }

      // Clear the passenger's ride request
      await _supabaseClient
          .from('profiles')
          .update({'ride_request_driver_id': null})
          .eq('id', passengerId);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Accepted $passengerName')));
        _syncPassengerRequests(); // Refresh the list
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
    return AlertDialog(
      title: const Text('Driver Dashboard'),
      content: SizedBox(
        width: double.maxFinite,
        child:
            _passengerRequests.isEmpty
                ? const Text('No passenger requests yet.')
                : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _passengerRequests.length,
                  itemBuilder: (context, index) {
                    final passenger = _passengerRequests[index];
                    return ListTile(
                      title: Text(passenger['full_name'] as String),
                      subtitle: Text('Location: ${passenger['live_location']}'),
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
