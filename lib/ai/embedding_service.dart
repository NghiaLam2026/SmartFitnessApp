// lib/features/ai/embedding_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/supabase_client.dart';

class EmbeddingService {
  final SupabaseClient _client;

  EmbeddingService({SupabaseClient? client}) : _client = client ?? supabase;

  // ------------------------------------------------------------
  // DEVICE MODES
  // ------------------------------------------------------------
  //
  // useEmulator     → Android Studio Emulator
  // useUsbDevice    → Physical Android device via USB + adb reverse
  // useWifiDevice   → Physical Android device on same Wi-Fi
  //
  static const bool useEmulator = false;
  static const bool useUsbDevice = true;    // <-- ENABLE THIS FOR USB
  static const bool useWifiDevice = false;

  // ------------------------------------------------------------
  // Configure Wi-Fi IPv4 here if using Wi-Fi mode
  // (Run `ipconfig` → Wireless LAN adapter Wi-Fi → IPv4 Address)
  // Example: "172.16.14.22"
  static const String wifiHost = "172.16.xxx.xxx"; // <-- replace only for Wi-Fi mode

  // ------------------------------------------------------------
  // Resolve the correct Ollama URL dynamically
  // ------------------------------------------------------------
  static String get ollamaUrl {
    if (useEmulator) {
      // Android emulator → host machine
      return 'http://10.0.2.2:11434/api/embeddings';
    }

    if (useUsbDevice) {
      // Physical phone over USB + adb reverse
      // Must run: adb reverse tcp:11434 tcp:11434
      return 'http://127.0.0.1:11434/api/embeddings';
    }

    // Physical phone over Wi-Fi
    return 'http://$wifiHost:11434/api/embeddings';
  }

  static const String _modelName = 'nomic-embed-text';

  // ------------------------------------------------------------
  // Generate embedding using Ollama
  // ------------------------------------------------------------
  Future<List<double>> generateEmbedding(String text) async {
    final response = await http.post(
      Uri.parse(ollamaUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': _modelName,
        'prompt': text,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Ollama embedding failed: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map || decoded['embedding'] == null) {
      throw Exception('Unexpected embedding response: ${response.body}');
    }

    return (decoded['embedding'] as List)
        .map<double>((e) => (e as num).toDouble())
        .toList();
  }

  // ------------------------------------------------------------
  // Save embedding to Supabase
  // ------------------------------------------------------------
  Future<void> saveEmbeddingToSupabase({
    required int progressId,
    required String userId,
    required List<double> embedding,
  }) async {
    await _client.from('user_progress_embeddings').insert({
      'user_id': userId,
      'progress_id': progressId,
      'embedding': embedding,
    });
  }
}
