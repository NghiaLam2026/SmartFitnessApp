import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';


class BadgeRepository {
  final SupabaseClient _client;

  BadgeRepository({SupabaseClient? client}) : _client = client ?? supabase;

  //Insert badge ONLY IF it doesnt exist already
  Future<bool> awardBadge({
    required String badgeName,
    required String description,
    required String iconUrl,
    String? progressType,
    num? progressValue,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    //check if this badge is already earned
    final existing = await _client
      .from('user_badges')
      .select()
      .eq('user_id', user.id)
      .eq('badge_name', badgeName)
      .maybeSingle();

    //alreadt earned -> dont insert again
    if (existing != null) return false;

    //Insert NEW badge
    await _client.from('user_badges').insert({
      'user_id': user.id,
      'badge_name': badgeName,
      'description': description,
      'icon_url': iconUrl,
      'progress_type': progressType,
      'progress_value': progressValue,
    });
    return true; //means we inserted a new badge

    //Fetch all badges user has unlocked
  }
  Future<List<Map<String, dynamic>>> getAllBadges() async{
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    return await _client
      .from('user_badges')
      .select()
      .eq('user_id', user.id)
      .order('unlocked_at', ascending: false);
  }
  //Fetch the most recent badge the user unlocked
  Future<Map<String, dynamic>?> getLatestBadge() async{
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final response = await _client
      .from('user_badges')
      .select()
      .eq('user_id', user.id)
      .order('unlocked_at', ascending: false)
      .limit(1)
      .maybeSingle();
    return response;
  }
}
