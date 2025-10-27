import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/protocol_models.dart';

class InjuryRepository {
  final SupabaseClient _client;
  InjuryRepository({SupabaseClient? client}) : _client = client ?? supabase;

  Future<List<Protocol>> fetchProtocols({
    String? bodyArea,
    GoalFilter? goal,
  }) async {
    dynamic qb = _client
        .from('protocols')
        .select('id, name, type, body_area, description');
    if (goal != null) {
      qb = qb.eq('type', goal.protocolType.apiValue);
    }
    if (bodyArea != null && bodyArea.isNotEmpty && bodyArea != 'full body') {
      qb = qb.eq('body_area', bodyArea);
    }
    qb = qb.order('name');
    final rows = await qb;
    final List data = rows as List;
    return data.whereType<Map<String, dynamic>>().map(Protocol.fromMap).toList();
  }

  Future<List<ProtocolStepModel>> fetchSteps(String protocolId) async {
    final rows = await _client
        .from('protocol_steps')
        .select('id, protocol_id, order_index, exercise, exercise_id, duration_sec, reps, notes')
        .eq('protocol_id', protocolId)
        .order('order_index');
    final List data = rows as List;
    return data.whereType<Map<String, dynamic>>().map(ProtocolStepModel.fromMap).toList();
  }

  Future<Set<String>> fetchFavoriteProtocolIds(String userId) async {
    final rows = await _client
        .from('user_protocols')
        .select('protocol_id')
        .eq('user_id', userId)
        .eq('favorite', true);
    final List data = rows as List;
    return data.map((e) => e['protocol_id'] as String?).whereType<String>().toSet();
  }

  Future<bool> toggleFavorite(String userId, String protocolId) async {
    final existing = await _client
        .from('user_protocols')
        .select('id, favorite')
        .eq('user_id', userId)
        .eq('protocol_id', protocolId)
        .maybeSingle();
    if (existing == null) {
      await _client.from('user_protocols').insert({
        'user_id': userId,
        'protocol_id': protocolId,
        'favorite': true,
      });
      return true;
    }
    final bool next = !(existing['favorite'] as bool? ?? false);
    await _client
        .from('user_protocols')
        .update({'favorite': next})
        .eq('id', existing['id']);
    return next;
  }

  Future<void> assignToPlan(String userId, String protocolId) async {
    // For now, ensure an active user_protocols row exists
    final existing = await _client
        .from('user_protocols')
        .select('id')
        .eq('user_id', userId)
        .eq('protocol_id', protocolId)
        .maybeSingle();
    if (existing == null) {
      await _client.from('user_protocols').insert({
        'user_id': userId,
        'protocol_id': protocolId,
        'status': 'active',
      });
    }
  }
}


