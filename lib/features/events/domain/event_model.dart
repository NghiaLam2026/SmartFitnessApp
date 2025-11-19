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
  final String? description;

  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? venue;
  final String? address;
  final String? zipCode;
  final double? lat;
  String? userId;
  final double? lng;
  final String? url;
  final String? registrationUrl;
  final String? imageUrl;

  Event({
    String? id,
    required this.name,
    this.description,
    this.startsAt,
    this.endsAt,
    this.venue,
    this.address,
    this.zipCode,
    this.lat,
    this.lng,
    this.url,
    this.registrationUrl,
    this.userId,
    this.imageUrl,
  }) : id = id ?? const Uuid().v4();

  factory Event.fromMap(Map<String, dynamic> map) {
    try {
      return Event(
        id: map['id']?.toString() ?? "",
        description: map['description']?.toString(),
        name: map['name']?.toString() ?? "",
        startsAt: map['starts_at'] != null
            ? (map['starts_at'] is DateTime
                ? map['starts_at'] as DateTime
                : _parseDateTime(map['starts_at'].toString()))
            : null,
        endsAt: map['ends_at'] != null
            ? (map['ends_at'] is DateTime
                ? map['ends_at'] as DateTime
                : _parseDateTime(map['ends_at'].toString()))
            : null,
        venue: map['venue']?.toString(),
        address: map['address']?.toString(),
        zipCode: map['zip_code']?.toString(),
        lat: map['lat'] != null
            ? (map['lat'] is num
                ? map['lat'].toDouble()
                : double.tryParse(map['lat'].toString()))
            : null,
        lng: map['lng'] != null
            ? (map['lng'] is num
                ? map['lng'].toDouble()
                : double.tryParse(map['lng'].toString()))
            : null,
        url: map['url']?.toString(),
        registrationUrl: map['registration_url']?.toString(),
        userId: map['user_id']?.toString(),
        imageUrl: map['imageUrl']?.toString(),
      );
    } catch (e) {
      print('Error parsing Event from map: $e');
      print('Map data: $map');
      rethrow;
    }
  }

  /// Parse date string from Active.com API
  /// Handles various date formats that might be returned
  static DateTime? _parseDateTime(String dateString) {
    if (dateString.isEmpty) return null;
    
    // Try standard ISO 8601 format first
    DateTime? parsed = DateTime.tryParse(dateString);
    if (parsed != null) return parsed;
    
    // Try common date formats
    // Format: "2024-01-15T10:00:00" (without timezone)
    if (dateString.contains('T') && !dateString.contains('Z') && !dateString.contains('+')) {
      parsed = DateTime.tryParse('${dateString}Z');
      if (parsed != null) return parsed;
    }
    
    // Format: "2024-01-15 10:00:00" (space separator)
    final spaceFormat = dateString.replaceAll(' ', 'T');
    parsed = DateTime.tryParse(spaceFormat);
    if (parsed != null) return parsed;
    
    // Log if we couldn't parse it
    print('⚠️ Could not parse date: $dateString');
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      if (startsAt != null) 'starts_at': startsAt?.toIso8601String(),
      if (endsAt != null) 'ends_at': endsAt?.toIso8601String(),
      if (venue != null) 'venue': venue,
      if (address != null) 'address': address,
      if (zipCode != null) 'zip_code': zipCode,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (url != null) 'url': url,
      if (registrationUrl != null) 'registration_url': registrationUrl,
      if (userId != null) 'user_id': userId,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }
}
