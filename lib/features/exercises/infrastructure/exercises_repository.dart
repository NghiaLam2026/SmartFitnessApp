import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/exercise_models.dart';

abstract class ExercisesRepository {
  Future<List<Exercise>> fetchExercises({
    String? search,
    String? muscle,
    EquipmentYesNo equipment = EquipmentYesNo.any,
    int limit = 50,
    int offset = 0,
  });

  Future<Exercise?> fetchExerciseById(String id);
}

class SupabaseExercisesRepository implements ExercisesRepository {
  final SupabaseClient _client;
  SupabaseExercisesRepository({SupabaseClient? client}) : _client = client ?? supabase;

  @override
  Future<List<Exercise>> fetchExercises({
    String? search,
    String? muscle,
    EquipmentYesNo equipment = EquipmentYesNo.any,
    int limit = 50,
    int offset = 0,
  }) async {
    dynamic qb = _client.from('exercises').select('id, name, muscle, equipment, video_url, instructions');
    if (muscle != null && muscle.isNotEmpty) qb = qb.eq('muscle', muscle);
    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim();
      qb = qb.or('name.ilike.%$term%,muscle.ilike.%$term%');
    }
    if (equipment != EquipmentYesNo.any) {
      if (equipment == EquipmentYesNo.no) {
        qb = qb.eq('equipment', 'none');
      } else {
        qb = qb.neq('equipment', 'none');
      }
    }
    qb = qb.order('name');
    if (limit > 0) qb = qb.range(offset, offset + limit - 1);
    final rows = await qb;
    final List data = rows as List;
    return data.whereType<Map<String, dynamic>>().map(Exercise.fromMap).toList();
  }

  @override
  Future<Exercise?> fetchExerciseById(String id) async {
    final row = await _client
        .from('exercises')
        .select('id, name, muscle, equipment, video_url, instructions')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Exercise.fromMap(row);
  }
}


