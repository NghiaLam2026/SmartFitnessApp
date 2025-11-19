class EventRegisterModel {
  final String? id; // UUID stored as a String
  final String eventName;
  final String? eventVenue;
  final DateTime? eventStartDate;
  final DateTime? eventEndDate;
  final String? userId;
  final String? eventId;

  EventRegisterModel({
    this.id,
    required this.eventName,
    this.eventVenue,
    this.eventStartDate,
    this.eventEndDate,
    this.userId,
    this.eventId,
  });

  factory EventRegisterModel.fromMap(Map<String, dynamic> map) {
    return EventRegisterModel(
      id: map['id'],
      eventName: map['event_name'] ?? '',
      eventVenue: map['event_venue'],
      eventStartDate: map['event_startdate'] != null
          ? DateTime.parse(map['event_startdate'])
          : null,
      eventEndDate: map['event_enddate'] != null
          ? DateTime.parse(map['event_enddate'])
          : null,
      userId: map['user_id'],
      eventId: map['event_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'event_name': eventName,
      'event_venue': eventVenue,
      'event_startdate': eventStartDate?.toIso8601String(),
      'event_enddate': eventEndDate?.toIso8601String(),
      'user_id': userId,
      'event_id': eventId,
    };
  }
}
