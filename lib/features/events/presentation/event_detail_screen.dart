import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_fitness_app/features/events/domain/event_model.dart';
import 'package:smart_fitness_app/features/events/domain/register_event_model.dart';
import 'package:smart_fitness_app/features/events/infrastructure/event_repository_impl.dart';
import 'package:smart_fitness_app/features/workouts/presentation/ai_workout_page.dart';

class EventDetailScreen extends StatefulWidget {
  EventDetailScreen({super.key, required this.eventId});
  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final repo = EventRepositoryImpl();
  var registerLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Events Detail")),
      body: FutureBuilder<Event>(
        future: repo.readSingleEvent(widget.eventId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData) {
            return const Center(child: Text("No event found."));
          }

          final event = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              spacing: 10,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),

                detailTile(label: "Description", value: event.description),

                detailTile(label: "Venue", value: event.venue),

                detailTile(
                  label: "Start Date",
                  value:
                      "${event.startsAt != null ? DateFormat.yMMMMEEEEd().format(event.startsAt!) : 'N/A'}",
                ),
                detailTile(
                  label: "End Date",
                  value:
                      "${event.endsAt != null ? DateFormat.yMMMMEEEEd().format(event.endsAt!) : 'N/A'}",
                ),
                FilledButton(
                  onPressed: () async {
                    setState(() {
                      registerLoading = true;
                    });
                    final events = EventRegisterModel(
                      eventId: widget.eventId,
                      eventName: event.name,
                      eventVenue: event.venue,
                      eventEndDate: event.endsAt,
                      eventStartDate: event.startsAt,
                      id: uuid.v4(),
                    );
                    await repo.createEventRegister(events);
                    setState(() {
                      registerLoading = false;
                    });
                    Navigator.pop(context);
                  },
                  child: registerLoading == true
                      ? CircularProgressIndicator()
                      : Text("Register Events"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Card detailTile({String? label, String? value}) {
    return Card(
      child: ListTile(title: Text(label ?? ""), subtitle: Text(value ?? "")),
    );
  }
}
