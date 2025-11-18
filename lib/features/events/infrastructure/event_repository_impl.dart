import 'dart:convert';

import 'package:smart_fitness_app/core/supabase/supabase_client.dart';
import 'package:smart_fitness_app/features/events/domain/event_model.dart';

import 'package:smart_fitness_app/features/events/domain/register_event_model.dart';
import 'package:smart_fitness_app/features/events/infrastructure/event_repository.dart';
import 'package:smart_fitness_app/features/workouts/presentation/create_workout_page.dart';
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

  @override
  Stream<List<Event>> readAllCategoryEvent() {
    return _client.from("events").stream(primaryKey: ["id"]).map((e) {
      return e.map<Event>((event) => Event.fromMap(event)).toList();
    });
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
}
