import 'package:flutter/foundation.dart';

@immutable
class Protocol {
  final String id;
  final String name;
  final ProtocolType type;
  final String? bodyArea;
  final String? description;

  const Protocol({
    required this.id,
    required this.name,
    required this.type,
    this.bodyArea,
    this.description,
  });

  factory Protocol.fromMap(Map<String, dynamic> map) {
    return Protocol(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?)?.trim() ?? 'Untitled',
      type: ProtocolTypeApi.from(map['type']) ?? ProtocolType.prehab,
      bodyArea: (map['body_area'] as String?)?.trim(),
      description: (map['description'] as String?)?.trim(),
    );
  }
}

@immutable
class ProtocolStepModel {
  final String id;
  final String protocolId;
  final int orderIndex;
  final String exerciseName;
  final String? exerciseId;
  final int? durationSec;
  final int? reps;
  final String? notes;

  const ProtocolStepModel({
    required this.id,
    required this.protocolId,
    required this.orderIndex,
    required this.exerciseName,
    this.exerciseId,
    this.durationSec,
    this.reps,
    this.notes,
  });

  factory ProtocolStepModel.fromMap(Map<String, dynamic> map) {
    return ProtocolStepModel(
      id: (map['id'] as String?) ?? '',
      protocolId: (map['protocol_id'] as String?) ?? '',
      orderIndex: (map['order_index'] as int?) ?? 0,
      exerciseName: (map['exercise'] as String?)?.trim() ?? 'Exercise',
      exerciseId: (map['exercise_id'] as String?)?.trim(),
      durationSec: map['duration_sec'] as int?,
      reps: map['reps'] as int?,
      notes: (map['notes'] as String?)?.trim(),
    );
  }
}

enum ProtocolType { prehab, rehab, mobility }

extension ProtocolTypeApi on ProtocolType {
  String get apiValue => switch (this) {
        ProtocolType.prehab => 'prehab',
        ProtocolType.rehab => 'rehab',
        ProtocolType.mobility => 'mobility',
      };

  static ProtocolType? from(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'prehab':
        return ProtocolType.prehab;
      case 'rehab':
        return ProtocolType.rehab;
      case 'mobility':
        return ProtocolType.mobility;
      default:
        return null;
    }
  }
}

enum EquipmentFilter { auto, none, minimal, full }

enum GoalFilter { warmup, mobility, recovery }

extension GoalFilterToProtocolType on GoalFilter {
  ProtocolType get protocolType => switch (this) {
        GoalFilter.warmup => ProtocolType.prehab,
        GoalFilter.mobility => ProtocolType.mobility,
        GoalFilter.recovery => ProtocolType.rehab,
      };
}


