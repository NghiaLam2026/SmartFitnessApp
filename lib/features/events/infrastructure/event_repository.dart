import 'package:smart_fitness_app/features/events/domain/event_model.dart';
import 'package:smart_fitness_app/features/events/domain/register_event_model.dart';

abstract class EventRepository {
  void createCategoryEvent(Event event);
  void createEventRegister(EventRegisterModel event);
  Stream<List<Event>> readAllCategoryEvent();
  Future<Event> readSingleEvent(String id);
  Future<bool> checkingAdmin();
}
