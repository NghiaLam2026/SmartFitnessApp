import 'package:flutter/foundation.dart';

@immutable
class Exercise {
  final String id;
  final String name;
  final String? muscle; // body area
  final String? equipment; // 'none' or tool name
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? instructions;
  final bool isPrevention; // true if this is an injury prevention/rehabilitation exercise

  const Exercise({
    required this.id,
    required this.name,
    this.muscle,
    this.equipment,
    this.thumbnailUrl,
    this.videoUrl,
    this.instructions,
    this.isPrevention = false,
  });

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?)?.trim() ?? 'Untitled',
      muscle: (map['muscle'] as String?)?.trim(),
      equipment: (map['equipment'] as String?)?.trim(),
      thumbnailUrl: (map['thumbnail_url'] as String?)?.trim(),
      videoUrl: (map['video_url'] as String?)?.trim(),
      instructions: (map['instructions'] as String?)?.trim(),
      isPrevention: (map['is_prevention'] as bool?) ?? false,
    );
  }
}

enum EquipmentYesNo { yes, no, any }


