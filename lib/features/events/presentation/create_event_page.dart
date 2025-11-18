import 'package:flutter/material.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';
import 'package:smart_fitness_app/features/events/domain/event_model.dart';
import 'package:smart_fitness_app/features/events/infrastructure/event_repository_impl.dart';
import 'package:intl/intl.dart';

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key});

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  var _formkey = GlobalKey<FormState>();
  var loading = false;
  String? title;
  String? description;
  DateTime? startDate;
  DateTime? endDate;
  String? venue;
  double? lat;
  double? lng;
  final venueController = TextEditingController();
  String? url;
  final eventRepository = EventRepositoryImpl();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create Event")),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Form(
            key: _formkey,
            child: Column(
              spacing: 20,
              children: [
                eventTextField(
                  title: "Event Title",
                  onSaved: (value) {
                    setState(() {
                      title = value;
                    });
                  },
                ),
                eventTextField(
                  title: "Event Description",
                  maxLines: 4,
                  onSaved: (value) {
                    setState(() {
                      description = value;
                    });
                  },
                ),

                Row(
                  children: [
                    Expanded(
                      child: eventTextField(
                        controller: TextEditingController(
                          text: startDate != null
                              ? DateFormat.yMMMd().format(startDate!)
                              : "",
                        ),
                        readOnly: true,
                        title: "start date",
                        onTap: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(Duration(days: 365)),
                          );
                          setState(() {
                            startDate = pickedDate;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: eventTextField(
                        controller: TextEditingController(
                          text: endDate != null
                              ? DateFormat.yMMMd().format(endDate!)
                              : "",
                        ),
                        readOnly: true,
                        title: "end date",
                        onTap: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(Duration(days: 365)),
                          );
                          setState(() {
                            endDate = pickedDate;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GooglePlacesAutoCompleteTextFormField(
                    config: const GoogleApiConfig(
                      apiKey: 'AIzaSyAXfKpG8TAL8HaVG3eMoMfKeNcekmmevWA',
                      countries: ['us'],
                      fetchPlaceDetailsWithCoordinates: true,
                      debounceTime: 400,
                    ),
                    textEditingController: venueController,
                    decoration: textFieldDecoration("Venue"),
                    onSuggestionClicked: (prediction) {
                      setState(() {
                        venue = prediction.description;
                        venueController.text = prediction.description ?? "";
                        lat = double.tryParse(prediction.lat ?? "0");
                        lng = double.tryParse(prediction.lng ?? "0");
                      });
                      print(prediction.description);
                    },
                  ),
                ),

                eventTextField(
                  title: "Registration URL",
                  onSaved: (value) {
                    setState(() {
                      url = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20.0),
        child: FilledButton(
          onPressed: () async {
            if (_formkey.currentState?.validate() ?? false) {
              _formkey.currentState?.save();
              setState(() {
                loading = true;
              });
              final event = Event(
                name: title ?? "NA",
                description: description ?? "NA",
                startsAt: startDate ?? DateTime.now(),
                endsAt: endDate ?? DateTime.now(),
                venue: venue,
                zipCode: "12345",
                lat: lat,
                lng: lng,
                url: url,
                registrationUrl: url,
              );
              await eventRepository.createCategoryEvent(event);
              setState(() {
                loading = false;
              });
              Navigator.pop(context);
            }
          },
          child: loading ? CircularProgressIndicator() : Text("Create Event"),
        ),
      ),
    );
  }

  Padding eventTextField({
    required String title,
    Function(String?)? onSaved,
    readOnly = false,
    Function()? onTap,
    TextEditingController? controller,
    int? maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextFormField(
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "$title is required";
          }
          return null;
        },
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        onSaved: onSaved,
        maxLines: maxLines,
        decoration: textFieldDecoration(title),
      ),
    );
  }

  InputDecoration textFieldDecoration(String title) {
    return InputDecoration(
      label: Text("$title"),
      hintText: "Enter $title",
      hintStyle: TextStyle(fontSize: 10, color: Colors.grey.shade200),
      border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
    );
  }
}
