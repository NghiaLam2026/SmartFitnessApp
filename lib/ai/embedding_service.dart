import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/supabase_client.dart';


class EmbeddingService {
  final SupabaseClient _client;

  EmbeddingService({SupabaseClient? client}) : _client = client ?? supabase;

  //DEVICE MOVIE
  static const bool useEmulator = true;
  static const bool useUsbDevice = false;
  static const bool useWifiDevice = false;

  static const String wifiHost = "172.16.xxx.xxx"; //replace only for wifi mode

  static String get ollamaUrl{
    if (useEmulator){
      return 'http://10.0.2.2:11434/api/embeddings';
    }
    if (useUsbDevice){
      return 'http://127.0.0.1:11434/api/embeddings';
    }
    //Physical phone over wifi
    return 'http://$wifiHost:11434/api/embeddings';
  }
  static const String _modelName = 'nomic-embed-text';

  //generate embedding using ollama
  Future<List<double>> generateEmbedding(String text) async{
    final response = await http.post(
      Uri.parse(ollamaUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': _modelName,
        'prompt': text,
      }),
    );
    if (response.statusCode != 200){
      throw Exception(
        'Ollama embedding failed: ${response.statusCode} ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);

    if(decoded is! Map || decoded['embedding'] == null){
      throw Exception('Unexpected embedding response: ${response.body}');
    }

    return (decoded['embedding'] as List)
        .map<double>((e)=> (e as num).toDouble())
        .toList();
  }
  //Save embedding to supabase
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

