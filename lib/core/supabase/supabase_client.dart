import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Global accessor for the Supabase client
SupabaseClient get supabase => Supabase.instance.client;

/// Initializes Supabase and loads environment variables.
///
/// Requires a `.env` file at project root with:
/// - SUPABASE_URL=...
/// - SUPABASE_ANON_KEY=...
Future<void> initSupabase() async {
  // Try to load from .env if present. If the asset is missing, keep going.
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('dotenv: .env not found or not declared in assets. Proceeding with dart-define/env.');
  }

  // Resolve config from .env or --dart-define fallbacks
  final envUrl = dotenv.maybeGet('SUPABASE_URL');
  final defineUrl = const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://example.supabase.co');
  final url = (envUrl != null && envUrl.isNotEmpty) ? envUrl : defineUrl;

  final envKey = dotenv.maybeGet('SUPABASE_ANON_KEY');
  final defineKey = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'public-anon-key');
  final anonKey = (envKey != null && envKey.isNotEmpty) ? envKey : defineKey;

  debugPrint('🔧 Supabase URL: $url');
  debugPrint('🔧 Supabase Key: ${anonKey.substring(0, 20)}...');

  await Supabase.initialize(
    url: url,
    anonKey: anonKey,
    debug: kDebugMode,
  );
}


