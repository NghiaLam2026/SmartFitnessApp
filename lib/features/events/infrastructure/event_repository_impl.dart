import 'package:smart_fitness_app/core/supabase/supabase_client.dart';
import 'package:smart_fitness_app/features/events/domain/event_model.dart';
import 'package:smart_fitness_app/features/events/domain/register_event_model.dart';
import 'package:smart_fitness_app/features/events/infrastructure/event_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventRepositoryImpl implements EventRepository {
  final SupabaseClient _client;

  EventRepositoryImpl({SupabaseClient? client})
      : _client = client ?? supabase;

  // ---------------------------------------------------------------------------
  // CREATE EVENT (Admin only)
  // ---------------------------------------------------------------------------
  @override
  Future<void> createCategoryEvent(Event event) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    var data = event.toMap();
    data['user_id'] = user.id;

    await _client.from('events').insert(data);
  }

  // ---------------------------------------------------------------------------
  // CHECK ADMIN ROLE
  // ---------------------------------------------------------------------------
  @override
  Future<bool> checkingAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final data = await _client
        .from('profiles')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();

    if (data == null) return false;

    final role = data['role'];
    return role == 'admin';
  }

  // ---------------------------------------------------------------------------
  // READ ALL EVENTS (Stream)
  // ---------------------------------------------------------------------------
  @override
  Stream<List<Event>> readAllCategoryEvent() {
    return _client
        .from("events")
        .stream(primaryKey: ["id"])
        .handleError((err) {
      print("STREAM ERROR EVENTS === $err");
    })
        .map((rows) {
      return rows
          .map<Event>((event) => Event.fromMap(event))
          .toList();
    });
  }

  // ---------------------------------------------------------------------------
  // READ REGISTERED EVENTS (Stream)
  // ---------------------------------------------------------------------------
  @override
  Stream<List<EventRegisterModel>> readAllRegisterEvent() {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    return _client
        .from("event_register")
        .stream(primaryKey: ["id"])
        .eq("user_id", user.id)
        .handleError((err) {
      print("STREAM ERROR REGISTER === $err");
    })
        .map((rows) {
      final list = rows
          .map<EventRegisterModel>(
              (row) => EventRegisterModel.fromMap(row))
          .toList();

      // Unique events grouped by eventId
      final unique = {
        for (var item in list) item.eventId!: item
      };

      return unique.values.toList();
    });
  }

  // ---------------------------------------------------------------------------
  // READ SINGLE EVENT
  // ---------------------------------------------------------------------------
  @override
  Future<Event> readSingleEvent(String id) async {
    final response = await _client
        .from("events")
        .select()
        .eq("id", id)
        .single();

    return Event.fromMap(response);
  }

  // ---------------------------------------------------------------------------
  // REGISTER FOR EVENT
  // ---------------------------------------------------------------------------
  @override
  Future<void> createEventRegister(EventRegisterModel event) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    var data = event.toMap();
    data['user_id'] = user.id;

    await _client.from('event_register').insert(data);
  }
}

