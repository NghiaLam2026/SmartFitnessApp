import 'package:supabase_flutter/supabase_flutter.dart';
import 'embedding_service.dart';
import '../features/tracking/progress_repository.dart';


class BatchEmbeddingGenerator {
  final ProgressRepository progressRepo;
  final EmbeddingService embeddingService;
  final SupabaseClient client;

  BatchEmbeddingGenerator({
    required this.progressRepo,
    required this.embeddingService,
    required this.client,
  });

  /// Generates embeddings for all progress entries that do NOT have one yet.
  Future<void> generateAllMissingEmbeddings() async {
    print("🔄 Starting batch embedding generation...");

    final userId = client.auth.currentUser!.id;

    // 1️⃣ Get all existing progress logs
    final progressLogs = await progressRepo.getProgress();
    print("📌 Found ${progressLogs.length} total progress entries.");

    // 2️⃣ Get all progress_ids that ALREADY have embeddings
    final embeddedRows = await client
        .from('user_progress_embeddings')
        .select('progress_id');

    final existingEmbeddedIds = embeddedRows
        .map<int>((row) => row['progress_id'] as int)
        .toSet();

    print("📌 Found ${existingEmbeddedIds.length} entries with embeddings.");

    int generatedCount = 0;

    // 3️⃣ Loop through every progress log
    for (final row in progressLogs) {
      final progressId = row['progress_id'] as int;

      if (existingEmbeddedIds.contains(progressId)) {
        print("⏭️ Skipping $progressId (embedding already exists)");
        continue; // skip
      }

      print("✨ Generating embedding for progress_id $progressId ...");



      // build summary text (same format as your sync)
      final summary = """
Date: ${row['date_logged']}
Weight: ${row['weight']} kg
Steps: ${row['steps_count']}
Calories: ${row['calories_burned']}
""";

      // Generate embedding using Ollama
      final embedding = await embeddingService.generateEmbedding(summary);

      // Save embedding in Supabase
      await embeddingService.saveEmbeddingToSupabase(
        progressId: progressId,
        userId: userId,
        embedding: embedding,
      );

      print("✅ Saved embedding for $progressId");

      generatedCount++;
    }

    print("🎉 Batch complete! Generated $generatedCount new embeddings.");
    print("🔍 Rows returned from progressRepo: ${progressLogs.length}");

  }
}
