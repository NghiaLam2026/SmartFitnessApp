import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:smart_fitness_app/features/events/domain/event_model.dart';
import 'package:smart_fitness_app/features/events/domain/register_event_model.dart';
import 'package:smart_fitness_app/features/events/infrastructure/event_repository.dart';
import 'package:smart_fitness_app/features/events/infrastructure/event_repository_impl.dart';
import 'package:smart_fitness_app/features/events/infrastructure/active_events_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';

class EventPage extends StatefulWidget {
  const EventPage({super.key});

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final eventRepository = EventRepositoryImpl(client: Supabase.instance.client);
  final activeEventsService = ActiveEventsService();
  String? _userZipcode;
  bool _zipcodeLoading = false;
  final TextEditingController _zipcodeController = TextEditingController();
  int _refreshKey = 0; // Key to force StreamBuilder refresh
  
  // Cache for events to avoid repeated API calls
  List<Event>? _cachedEvents;
  String? _cachedZipcode; // Track which zipcode the cache is for
  
  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    _loadUserZipcode();
    super.initState();
  }

  Future<void> _loadUserZipcode() async {
    setState(() {
      _zipcodeLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        print('📍 Fetching zipcode from profile for user: ${user.id}');
        final profile = await supabase
            .from('profiles')
            .select('zip_code')
            .eq('user_id', user.id)
            .maybeSingle();
        
        if (profile != null && profile['zip_code'] != null) {
          final zip = (profile['zip_code'] as String?)?.trim();
          if (zip != null && zip.isNotEmpty && zip.length == 5) {
            print('✅ Found zipcode in profile: $zip');
            setState(() {
              // Clear cache if zipcode changed
              if (_cachedZipcode != zip) {
                _cachedEvents = null;
                _cachedZipcode = null;
              }
              _userZipcode = zip;
              _zipcodeLoading = false;
            });
            return;
          }
        }
        print('⚠️ No valid zipcode found in profile');
      } else {
        print('⚠️ No user logged in');
      }
    } catch (e) {
      print('❌ Error loading zipcode from profile: $e');
    }
    
    setState(() {
      _zipcodeLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _all_event(),
                _register_event(),
              ],
            ),
          ),
        ],
      ),
      appBar: AppBar(
        title: const Text("Nearby Community Events"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "All Events"),
            Tab(text: "Registered"),
          ],
        ),
      ),
    );
  }

  Widget _all_event() {
    // If loading zipcode, show loading indicator
    if (_zipcodeLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading your zipcode...'),
          ],
        ),
      );
    }

    // Show zipcode input if no zipcode set
    if (_userZipcode == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, size: 64, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                'Enter Your Zipcode',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'We couldn\'t find your zipcode in your profile. Please enter it to find nearby fitness events.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _zipcodeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Zipcode',
                  hintText: 'e.g., 92101',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.pin),
                ),
                maxLength: 5,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final zip = _zipcodeController.text.trim();
                  if (zip.length == 5) {
                    // Save zipcode to profile for future use
                    final user = Supabase.instance.client.auth.currentUser;
                    if (user != null) {
                      try {
                        await supabase.from('profiles').upsert({
                          'user_id': user.id,
                          'zip_code': zip,
                          'updated_at': DateTime.now().toIso8601String(),
                        });
                        print('✅ Saved zipcode to profile');
                      } catch (e) {
                        print('⚠️ Could not save zipcode to profile: $e');
                      }
                    }
                    
                    setState(() {
                      _userZipcode = zip;
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid 5-digit zipcode'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.search),
                label: const Text('Search Community Events'),
              ),
            ],
          ),
        ),
      );
    }

          // If we have zipcode, fetch events from Active.com API (or use cache)
          if (_userZipcode != null) {
            // Check if we have cached events for this zipcode
            if (_cachedEvents != null && _cachedZipcode == _userZipcode) {
              // Use cached events
              return _buildEventsList(_cachedEvents!);
            }
            
            // Fetch events from API
            return FutureBuilder<List<Event>>(
              future: _fetchActiveEvents(),
              builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('❌ Error loading events: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading events',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      '${snapshot.error}',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (snapshot.hasData) {
            final events = snapshot.data ?? [];
            if (events.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No events found nearby',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back later for upcoming events',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {});
                      },
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      onTap: () {
                        // For Active.com events, we might need to handle differently
                        // For now, try to show details if possible
                        context.push(
                          '/home/events/eventDetail/${event.id}',
                        );
                      },
                      leading: event.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                event.imageUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.event, size: 40);
                                },
                              ),
                            )
                          : const Icon(Icons.event, size: 40),
                      title: Text(
                        event.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          if (event.venue != null && event.venue!.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 16),
                                const SizedBox(width: 4),
                                Expanded(child: Text(event.venue!)),
                              ],
                            ),
                          if (event.startsAt != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat.yMMMEd().format(event.startsAt!),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            );
          }
          return const SizedBox();
        },
      );
    }

    // Fallback: if no zipcode, show message
    return const Center(
      child: Text('Zipcode is required to find events'),
    );
  }

  Future<List<Event>> _fetchActiveEvents() async {
    if (_userZipcode == null) {
      print('❌ No zipcode available');
      return [];
    }

    // Check cache first - if we have cached events for this zipcode, return them
    if (_cachedEvents != null && _cachedZipcode == _userZipcode) {
      print('📦 Using cached events for zipcode: $_userZipcode (${_cachedEvents!.length} events)');
      return _cachedEvents!;
    }

    try {
      print('🔍 Fetching events from API for zipcode: $_userZipcode');
      
      // Don't use query parameter - let API return all events for zipcode
      // We'll filter on the backend if needed
      final response = await activeEventsService.searchNearbyEvents(
        zip: _userZipcode!,
        // No query parameter - get all events
        perPage: 50,
      );

      print('✅ Fetched ${response.events.length} events from Active.com for zipcode $_userZipcode (total: ${response.totalResults})');
      
      if (response.events.isEmpty) {
        print('⚠️ No events returned. Response data: ${response.totalResults} total results');
      }
      
      // Cache the events for future use
      setState(() {
        _cachedEvents = response.events;
        _cachedZipcode = _userZipcode;
      });
      
      return response.events;
    } catch (e) {
      print('❌ Error fetching Active.com events: $e');
      print('   Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }
  
  // Extract events list building into a reusable method
  Widget _buildEventsList(List<Event> events) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No events found nearby',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for upcoming events',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Clear cache and refresh
                setState(() {
                  _cachedEvents = null;
                  _cachedZipcode = null;
                });
              },
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        // Clear cache to force refresh
        setState(() {
          _cachedEvents = null;
          _cachedZipcode = null;
        });
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              onTap: () {
                context.push(
                  '/home/events/eventDetail/${event.id}',
                );
              },
              leading: event.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        event.imageUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.event, size: 40);
                        },
                      ),
                    )
                  : const Icon(Icons.event, size: 40),
              title: Text(
                event.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  if (event.venue != null && event.venue!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16),
                        const SizedBox(width: 4),
                        Expanded(child: Text(event.venue!)),
                      ],
                    ),
                  if (event.startsAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat.yMMMEd().format(event.startsAt!),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  Widget _register_event() {
    return StreamBuilder<List<EventRegisterModel>>(
      key: ValueKey(_refreshKey), // Force rebuild when key changes
      stream: eventRepository.readAllRegisterEvent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          print('Error loading registered events: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading registered events',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (snapshot.hasData) {
          final events = snapshot.data ?? [];
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_available, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No registered events',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Register for events to see them here',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final registeredEvent = events[index];
                return Card(
                  child: ListTile(
                    onTap: () {
                      context.push(
                        '/home/events/eventDetail/${registeredEvent.eventId}',
                      );
                    },
                    title: Text(registeredEvent.eventName),
                    subtitle: Text(
                      "${registeredEvent.eventVenue ?? "NA"} || ${registeredEvent.eventStartDate != null ? DateFormat.yMMMEd().format(registeredEvent.eventStartDate!) : "NA"}",
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        // Show confirmation dialog
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Event'),
                            content: Text(
                              'Are you sure you want to remove "${registeredEvent.eventName}" from your registered events?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true && mounted) {
                          try {
                            await eventRepository.deleteEventRegister(
                              registeredEvent.eventId ?? '',
                            );
                            // Force UI update immediately by refreshing the stream
                            if (mounted) {
                              setState(() {
                                _refreshKey++; // Increment key to force StreamBuilder rebuild
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Event removed successfully'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error deleting event: $e'),
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          );
        }
        return const SizedBox();
      },
    );
  }
}
