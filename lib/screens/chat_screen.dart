import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ride_along/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supabaseService = SupabaseService();
  final _supabaseClient = Supabase.instance.client;
  final _messageController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  String? _otherUserName;
  String? _otherUserLocation;
  String? _myLocation;
  double? _distance;
  Timer? _locationTimer;
  ScrollController _scrollController = ScrollController();
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _chatInitialized = false;
  bool _isRideActive = false;
  Map<String, dynamic>? _currentRide;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _fetchInitialData();
    _subscribeToMessages();
    _subscribeToRideStatus();
    _syncLocations();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _syncLocations();
    });
    _checkRideStatus();
  }

  Future<void> _initializeNotifications() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _notificationsPlugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> _fetchInitialData() async {
    try {
      final chat =
          await _supabaseClient
              .from('chats')
              .select('messages')
              .eq('id', widget.chatId)
              .single();
      final otherUser =
          await _supabaseClient
              .from('profiles')
              .select('full_name, live_location')
              .eq('id', widget.otherUserId)
              .single();

      final otherUserLocation = await _coordsToAddress(
        otherUser['live_location'] as String?,
      );

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(chat['messages'] ?? []);
          _otherUserName = otherUser['full_name'] as String;
          _otherUserLocation = otherUserLocation;
          _chatInitialized = true;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading chat: $e')));
      }
    }
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

  void _subscribeToMessages() {
    _supabaseClient
        .from('chats')
        .stream(primaryKey: ['id'])
        .eq('id', widget.chatId)
        .listen(
          (data) {
            if (mounted && data.isNotEmpty) {
              final newMessages = List<Map<String, dynamic>>.from(
                data.first['messages'] ?? [],
              );
              if (newMessages.length > _messages.length) {
                final latestMessage = newMessages.last;
                if (latestMessage['sender_id'] !=
                    _supabaseService.getCurrentUser()?.id) {
                  _showSystemNotification(latestMessage['text'] as String);
                }
              }
              setState(() {
                _messages = newMessages;
                _chatInitialized = true;
              });
              _scrollToBottom();
            }
          },
          onError: (error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Chat subscription error: $error')),
              );
            }
          },
        );
  }

  void _subscribeToRideStatus() {
    final user = _supabaseService.getCurrentUser();
    if (user == null) return;

    // Subscription for rides where the user is the driver
    _supabaseClient
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('driver_id', user.id)
        .listen(
          (data) => _handleRideStatusUpdate(data),
          onError: _handleRideStatusError,
        );

    // Subscription for rides where the other user is a passenger
    _supabaseClient
        .from('rides')
        .stream(primaryKey: ['id'])
        .listen(_handleRideStatusUpdate, onError: _handleRideStatusError);
  }

  void _handleRideStatusUpdate(List<Map<String, dynamic>> data) {
    if (mounted && data.isNotEmpty) {
      final filteredData =
          data.where((ride) {
            final passengerIds = List<String>.from(ride['passenger_ids'] ?? []);
            return passengerIds.contains(widget.otherUserId);
          }).toList();
      if (filteredData.isNotEmpty) {
        final ride = filteredData.first;
        final rideStatus = ride['status'] as String;
        setState(() {
          _currentRide = ride;
          _isRideActive = rideStatus == 'pending' || rideStatus == 'accepted';
        });

        if (rideStatus == 'completed') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ride has been completed')),
          );
          Navigator.pop(context);
        }
      }
    }
  }

  void _handleRideStatusError(dynamic error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ride status subscription error: $error')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showSystemNotification(String message) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    await _notificationsPlugin.show(
      0,
      'New Message from $_otherUserName',
      message,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  Future<void> _syncLocations() async {
    try {
      final user = _supabaseService.getCurrentUser();
      if (user == null) return;

      final myProfile =
          await _supabaseClient
              .from('profiles')
              .select('live_location')
              .eq('id', user.id)
              .single();
      final otherProfile =
          await _supabaseClient
              .from('profiles')
              .select('live_location')
              .eq('id', widget.otherUserId)
              .single();

      if (myProfile['live_location'] != null &&
          otherProfile['live_location'] != null) {
        final myCoords = _parseLocation(myProfile['live_location'] as String);
        final otherCoords = _parseLocation(
          otherProfile['live_location'] as String,
        );
        final distance =
            Geolocator.distanceBetween(
              myCoords[0],
              myCoords[1],
              otherCoords[0],
              otherCoords[1],
            ) /
            1000;

        final myLocation = await _coordsToAddress(myProfile['live_location']);
        final otherUserLocation = await _coordsToAddress(
          otherProfile['live_location'],
        );

        if (mounted) {
          setState(() {
            _myLocation = myLocation;
            _otherUserLocation = otherUserLocation;
            _distance = distance;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error syncing locations: $e')));
      }
    }
  }

  Future<void> _checkRideStatus() async {
    final user = _supabaseService.getCurrentUser();
    if (user == null) return;

    final ride =
        await _supabaseClient
            .from('rides')
            .select('id, status, driver_id, passenger_ids')
            .or(
              'driver_id.eq.${user.id},passenger_ids.cs.{${widget.otherUserId}}',
            )
            .inFilter('status', ['pending', 'accepted'])
            .maybeSingle();

    if (mounted && ride != null) {
      setState(() {
        _currentRide = ride;
        _isRideActive = true;
      });
    }
  }

  Future<void> _completeRide() async {
    try {
      final user = _supabaseService.getCurrentUser();
      if (user == null || _currentRide == null) return;

      // Update ride status to completed
      await _supabaseClient
          .from('rides')
          .update({'status': 'completed'})
          .eq('id', _currentRide!['id']);

      // Get all participant IDs
      final driverId = _currentRide!['driver_id'] as String;
      final passengerIds = List<String>.from(
        _currentRide!['passenger_ids'] ?? [],
      );

      // Combine all user IDs that need role reset
      final allUserIds = [driverId, ...passengerIds];

      // Set roles to null for all participants
      await _supabaseClient
          .from('profiles')
          .update({'role': null})
          .inFilter('id', allUserIds);

      // Delete the chat
      await _supabaseClient.from('chats').delete().eq('id', widget.chatId);

      if (mounted) {
        setState(() => _isRideActive = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride completed, roles reset, and chat deleted!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error completing ride: $e')));
      }
    }
  }

  List<double> _parseLocation(String location) {
    final parts = location.split(',');
    return [double.parse(parts[0]), double.parse(parts[1])];
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final user = _supabaseService.getCurrentUser();
    if (user == null) return;

    final newMessage = {
      'sender_id': user.id,
      'text': _messageController.text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _messages.add(newMessage);
    });
    _scrollToBottom();
    _messageController.clear();

    try {
      final currentChat =
          await _supabaseClient
              .from('chats')
              .select('messages')
              .eq('id', widget.chatId)
              .single();

      final updatedMessages = List<Map<String, dynamic>>.from(
        currentChat['messages'] ?? [],
      )..add(newMessage);

      await _supabaseClient
          .from('chats')
          .update({'messages': updatedMessages})
          .eq('id', widget.chatId);
    } catch (e) {
      if (mounted) {
        setState(() => _messages.remove(newMessage));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_otherUserName ?? 'Chat'),
        actions: [
          if (_isRideActive)
            TextButton(
              onPressed: _completeRide,
              child: const Text(
                'Complete Ride',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body:
          _chatInitialized
              ? Column(
                children: [
                  Container(
                    color: theme.colorScheme.surface,
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Text(
                          'You: ${_myLocation ?? 'Loading...'}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          '${_otherUserName ?? 'User'}: ${_otherUserLocation ?? 'Loading...'}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          'Distance: ${_distance?.toStringAsFixed(2) ?? 'Calculating...'} km',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe =
                            message['sender_id'] ==
                            _supabaseService.getCurrentUser()?.id;
                        return Align(
                          alignment:
                              isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  isMe
                                      ? theme.colorScheme.secondary
                                      : theme.colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message['text'] as String,
                                  style: theme.textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateTime.parse(
                                    message['timestamp'] as String,
                                  ).toLocal().toString().substring(11, 16),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send),
                          color: theme.colorScheme.primary,
                          onPressed: _sendMessage,
                        ),
                      ],
                    ),
                  ),
                ],
              )
              : const Center(child: CircularProgressIndicator()),
    );
  }
}
