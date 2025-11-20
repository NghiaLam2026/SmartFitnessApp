import 'package:supabase_flutter/supabase_flutter.dart';
import 'embedding_service.dart';
import '../features/tracking/progress_repository.dart';


class BatchEmbeddingGenerator{
  final ProgressRepository progressRepo;
  final EmbeddingService embeddingService;
  final SupabaseClient client;

  BatchEmbeddingGenerator({
    required this.progressRepo,
    required this.embeddingService,
    required this.client,
  });
  Future<void> generateAllMissingEmbeddings() async{
    print("Starting batch embedding generation...");

    final userId = client.auth.currentUser!.id;

    final progressLogs = await progressRepo.getProgress();
    print("Found ${progressLogs.length} total progress entries.");

    final embeddedRows = await client
        .from('user_progress_embeddings')
        .select('progress_id');

    final existingEmbeddedIds = embeddedRows
        .map<int>((row)=> row['progress_id'] as int)
        .toSet();
    print("Found ${existingEmbeddedIds.length} entries with embeddings.");

    int generatedCount = 0;

    for (final row in progressLogs){
      final progressId = row['progress_id'] as int;

      if (existingEmbeddedIds.contains(progressId)){
        print("Skipping $progressId (embedding already exists)");
        continue;
      }
      print("Generating embedding for progress_id $progressId...");

      final summary = """
Date: ${row['date_logged']}
Weight: ${row['weight']} kg
Steps: ${row['steps_count']}
Calories: ${row['calories_burned']}
""";
      final embedding = await embeddingService.generateEmbedding(summary);

      await embeddingService.saveEmbeddingToSupabase(
        progressId: progressId,
        userId: userId,
        embedding: embedding,
      );
      print("saved embedding for $progressId");

      generatedCount++;
    }
    print("batch completed");
  }
}
