import 'package:smart_fitness_app/core/supabase/supabase_client.dart';
import 'package:smart_fitness_app/features/events/domain/event_model.dart';
import 'package:smart_fitness_app/features/events/domain/register_event_model.dart';
import 'package:smart_fitness_app/features/events/infrastructure/event_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventRepositoryImpl implements EventRepository {
  final SupabaseClient _client;
  EventRepositoryImpl({SupabaseClient? client}) : _client = client ?? supabase;
  @override
  Future<void> createCategoryEvent(Event event) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    var data = event.toMap();
    data['user_id'] = user.id;
    await _client.from('events').insert(data);
  }

  @override
  Stream<List<Event>> readAllCategoryEvent() {
    try {
      print('🔍 Starting to read events from database...');
      return _client
          .from("events")
          .stream(primaryKey: ["id"])
          .map((e) {
            try {
              print('📦 Received ${e.length} events from stream');
              final events = e.map<Event>((event) {
                try {
                  print('📝 Parsing event: ${event['name'] ?? 'Unknown'}');
                  return Event.fromMap(event);
                } catch (e) {
                  print('❌ Error parsing event: $e');
                  print('Event data: $event');
                  rethrow;
                }
              }).toList();
              print('✅ Successfully parsed ${events.length} events');
              return events;
            } catch (e) {
              print('❌ Error mapping events: $e');
              rethrow;
            }
          })
          .handleError((error) {
            print('❌ Stream error in readAllCategoryEvent: $error');
            throw error;
          });
    } catch (e) {
      print('❌ Error creating stream: $e');
      rethrow;
    }
  }

  @override
  Stream<List<EventRegisterModel>> readAllRegisterEvent() {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    return _client
        .from("event_register")
        .stream(primaryKey: ["id"])
        .eq("user_id", user.id)
        .map((rows) {
          final list = rows
              .map<EventRegisterModel>((row) => EventRegisterModel.fromMap(row))
              .toList();

          final unique = {for (var item in list) item.eventId!: item};

          return unique.values.toList();
        });
  }

  @override
  Future<Event> readSingleEvent(String id) async {
    final response = await _client
        .from("events")
        .select()
        .eq("id", id)
        .single();

    return Event.fromMap(response);
  }

  @override
  Future<void> createEventRegister(EventRegisterModel event) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    var data = event.toMap();
    data['user_id'] = user.id;
    await _client.from('event_register').insert(data);
  }

  @override
  Future<void> deleteEventRegister(String eventId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    await _client
        .from('event_register')
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', user.id);
  }
}
