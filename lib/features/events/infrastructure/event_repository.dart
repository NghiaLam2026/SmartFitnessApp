import 'package:smart_fitness_app/features/events/domain/event_model.dart';
import 'package:smart_fitness_app/features/events/domain/register_event_model.dart';

abstract class EventRepository {
  void createCategoryEvent(Event event);
  void createEventRegister(EventRegisterModel event);
  Future<void> deleteEventRegister(String eventId);
  Stream<List<Event>> readAllCategoryEvent();
  Stream<List<EventRegisterModel>> readAllRegisterEvent();
  Future<Event> readSingleEvent(String id);
}
