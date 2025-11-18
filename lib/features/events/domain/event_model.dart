// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:uuid/uuid.dart';

class EventModel {
  String? eventTitle;
  String? eventDescription;
  String? date;
  String? time;
  String? location;
  String? userId;
  String? requriement;
  EventModel({
    this.eventTitle,
    this.eventDescription,
    this.date,
    this.time,
    this.location,
    this.userId,
    this.requriement,
  });
}

class Event {
  final String id;
  final String name;
  final String description;

  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? venue;
  final String? zipCode;
  final double? lat;
  String? userId;
  final double? lng;
  final String? url;
  final String? registrationUrl;

  Event({
    String? id,
    required this.name,
    required this.description,

    this.startsAt,
    this.endsAt,
    this.venue,
    this.zipCode,
    this.lat,
    this.lng,
    this.url,
    this.registrationUrl,
  }) : id = id ?? const Uuid().v4();

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] ?? "",
      description: map['description'] ?? "NA",
      name: map['name'] ?? "",

      startsAt: map['starts_at'] != null
          ? DateTime.parse(map['starts_at'])
          : null,
      endsAt: map['ends_at'] != null ? DateTime.parse(map['ends_at']) : null,
      venue: map['venue'],
      zipCode: map['zip_code'],
      lat: map['lat']?.toDouble(),
      lng: map['lng']?.toDouble(),
      url: map['url'],
      registrationUrl: map['registration_url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,

      'starts_at': startsAt?.toIso8601String(),
      'ends_at': endsAt?.toIso8601String(),
      'venue': venue,
      'zip_code': zipCode,
      'lat': lat,
      'lng': lng,
      'url': url,
      'registration_url': registrationUrl,
    };
  }
}
