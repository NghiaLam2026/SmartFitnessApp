import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_fitness_app/features/events/domain/event_model.dart';
import 'package:smart_fitness_app/features/events/domain/register_event_model.dart';
import 'package:smart_fitness_app/features/events/infrastructure/event_repository_impl.dart';
import 'package:smart_fitness_app/features/events/infrastructure/active_events_service.dart';

class EventDetailScreen extends StatefulWidget {
  EventDetailScreen({super.key, required this.eventId});
  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final repo = EventRepositoryImpl();
  final activeEventsService = ActiveEventsService();
  var registerLoading = false;

  // Check if eventId is an Active.com GUID (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
  bool _isActiveComEvent(String eventId) {
    final guidPattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
    return guidPattern.hasMatch(eventId);
  }

  Future<Event> _fetchEvent() async {
    // Try Active.com API first if it looks like an Active.com GUID
    if (_isActiveComEvent(widget.eventId)) {
      try {
        return await activeEventsService.getEventDetails(widget.eventId);
      } catch (e) {
        print('Failed to fetch from Active.com, trying database: $e');
        // Fall through to database
      }
    }
    
    // Fallback to database
    return await repo.readSingleEvent(widget.eventId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Community Event Details")),
      body: FutureBuilder<Event>(
        future: _fetchEvent(),
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              spacing: 10,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),

                if (event.description != null && event.description!.isNotEmpty)
                  detailTile(label: "Description", value: event.description!),

                if (event.address != null && event.address!.isNotEmpty)
                  detailTile(label: "Address", value: event.address!),
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
                if (event.registrationUrl != null && event.registrationUrl!.isNotEmpty) ...[
                  detailTile(
                    label: "Registration Link",
                    value: event.registrationUrl!,
                    isLink: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: FilledButton.icon(
                      onPressed: () async {
                        final url = Uri.parse(event.registrationUrl!);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not open ${event.registrationUrl}')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text("Register Online"),
                    ),
                  ),
                ],
                if (event.url != null && event.url!.isNotEmpty && event.url != event.registrationUrl)
                  detailTile(
                    label: "Event Website",
                    value: event.url!,
                    isLink: true,
                  ),
                FilledButton(
                  onPressed: () async {
                    setState(() {
                      registerLoading = true;
                    });
                    try {
                      final events = EventRegisterModel(
                        eventId: widget.eventId,
                        eventName: event.name,
                        eventVenue: event.venue,
                        eventEndDate: event.endsAt,
                        eventStartDate: event.startsAt,
                        id: const Uuid().v4(),
                      );
                      await repo.createEventRegister(events);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Event registered successfully!')),
                        );
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error registering: $e')),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          registerLoading = false;
                        });
                      }
                    }
                  },
                  child: registerLoading == true
                      ? const CircularProgressIndicator()
                      : const Text("Save to My Events"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Card detailTile({String? label, String? value, bool isLink = false}) {
    return Card(
      child: ListTile(
        title: Text(label ?? ""),
        subtitle: isLink
            ? SelectableText(
                value ?? "",
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              )
            : Text(value ?? ""),
        onTap: isLink && value != null && value.isNotEmpty
            ? () async {
                final url = Uri.parse(value);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open $value')),
                    );
                  }
                }
              }
            : null,
      ),
    );
  }
}
