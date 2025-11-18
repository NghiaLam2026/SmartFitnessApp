import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../presentation/meditation_page.dart';

class MeditationRepository {
  MeditationRepository({SupabaseClient? client})
      : _client = client ?? supabase;

  final SupabaseClient _client;

  Future<List<MeditationRoutine>> fetchMeditations() async {
    final rows = await _client
        .from('meditation_content') // ⬅️ use the new table name
        .select(
      'id, category, title, subtitle, duration_min, description, instructions, video_url',
    )
        .order('category')
        .order('title');

    final List data = rows as List;

    return data
        .whereType<Map<String, dynamic>>()
        .map(MeditationRoutine.fromMap)
        .toList();
  }
}
