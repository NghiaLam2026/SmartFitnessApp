import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'progress_repository.dart';
import 'package:smart_fitness_app/features/tracking/badges/domain/badge_service.dart';
import 'package:smart_fitness_app/features/tracking/badges/badge_repository.dart';
import '../../../core/supabase/supabase_client.dart';
import 'package:smart_fitness_app/ai/embedding_service.dart';
import 'package:smart_fitness_app/ai/batch_embedding.dart';


class HealthTrackerScreen extends StatefulWidget {
  const HealthTrackerScreen({super.key});

  @override
  State<HealthTrackerScreen> createState() => _HealthTrackerScreenState();

}

enum AppState {
  DATA_NOT_FETCHED,
  FETCHING_DATA,
  NO_DATA,
  STEPS_READY,
  AUTH_NOT_GRANTED,
  AUTHORIZED,
  PERMISSIONS_REVOKED,
  PERMISSIONS_NOT_REVOKED,
  PERMISSIONS_REVOKING,
  HEALTH_CONNECT_STATUS,
}

class _HealthTrackerScreenState extends State<HealthTrackerScreen> {
  final Health _health = Health();
  final ProgressRepository _progressRepo = ProgressRepository();
  final BadgeRepository _badgeRepo = BadgeRepository();
  final EmbeddingService _embedService = EmbeddingService();
  late final BadgeService _badgeService = BadgeService(badgeRepo: _badgeRepo);


  // Health data
  final List<HealthDataPoint> _healthData = [];
  int _totalSteps = 0;

  // Manual / computed values
  double? _latestWeight;      // user-entered weight (kg)
  double? _caloriesBurned;    // computed from steps + weight
  final TextEditingController _weightController = TextEditingController();

  bool _isFetching = false;
  bool _isSyncing = false; // keep for the Sync button
  AppState _state = AppState.DATA_NOT_FETCHED;

  void _showBadgePopup(BuildContext context, Map<String, dynamic> badge) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'New Badge Unlocked!',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              badge['icon_url'],
              height: 120,
              width: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            Text(
              badge['badge_name'],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (badge['description'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  badge['description'],
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeHealth();
      await _loadExistingProgress();
    });
  }

  Future<void> _initializeHealth() async {
    setState(() => _state = AppState.FETCHING_DATA);

    await _health.configure();

    // request necessary runtime permissions
    await Permission.activityRecognition.request();
    await Permission.location.request();

    // health data types you want (only steps)
    final types = [HealthDataType.STEPS];
    final permissions = [HealthDataAccess.READ];

    // ask for authorization
    bool authorized =
    await _health.requestAuthorization(types, permissions: permissions);

    setState(() {
      _state = authorized ? AppState.AUTHORIZED : AppState.AUTH_NOT_GRANTED;
    });
  }

  Future<void> _loadExistingProgress() async {
    final data = await _progressRepo.getProgress();

    if (data.isNotEmpty) {
      final latest = data.first; // newest, because getProgress orders desc


      setState(() {
        _latestWeight = (latest['weight'] as num?)?.toDouble();
        _totalSteps = latest['steps_count'] ?? 0;
        _caloriesBurned = (latest['calories_burned'] as num?)?.toDouble();

        // Also restore weight text field
        if (_latestWeight != null) {
          _weightController.text = _latestWeight!.toString();
        }
      });
    }
  }


  // Simple formula to estimate calories from steps + weight (kg)
  double _calculateCaloriesFromSteps(int steps, double weightKg) {
    const double stepLengthMeters = 0.762; // avg adult step length
    final double distanceKm = (steps * stepLengthMeters) / 1000.0;
    // 0.57 is an empirical coefficient for walking energy cost
    return 0.57 * distanceKm * weightKg;
  }

  // safely fetches step count data from Health Connect
  // and updates the UI state accordingly
  Future<void> _fetchSteps() async {
    int? steps;

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    setState(() {
      _isFetching = true;
      _state = AppState.FETCHING_DATA;
    });

    // ensure android runtime permission for activity recognition
    try {
      if (await Permission.activityRecognition.isDenied) {
        await Permission.activityRecognition.request();
      }
    } catch (e) {
      debugPrint('Runtime permission request failed: $e');
    }

    try {
      await _health.configure();
    } catch (e) {
      debugPrint('Error configuring health plugin: $e');
      setState(() {
        _state = AppState.DATA_NOT_FETCHED;
        _isFetching = false;
      });
      return;
    }

    // verify Health Connect SDK availability
    final status = await _health.getHealthConnectSdkStatus();
    if (status != HealthConnectSdkStatus.sdkAvailable) {
      debugPrint('Health Connect not installed or unavailable (Status: $status)');
      setState(() {
        _state = AppState.DATA_NOT_FETCHED;
        _isFetching = false;
      });
      return;
    }

    // check / request permission for steps
    bool? hasPermission = await _health.hasPermissions(
      [HealthDataType.STEPS],
      permissions: [HealthDataAccess.READ],
    );

    if (hasPermission != true) {
      bool granted = false;
      try {
        granted = await _health.requestAuthorization(
          [HealthDataType.STEPS],
          permissions: [HealthDataAccess.READ],
        );
      } catch (e) {
        debugPrint('Error requesting authorization: $e');
      }

      if (!granted) {
        debugPrint('Step permission not granted by user.');
        setState(() {
          _state = AppState.DATA_NOT_FETCHED;
          _isFetching = false;
        });
        return;
      }
    }

    // fetch steps
    try {
      steps = await _health.getTotalStepsInInterval(midnight, now);
      debugPrint('Total steps today: $steps');
    } catch (error) {
      debugPrint("Exception in getTotalStepsInInterval: $error");
    }

    // compute calories if we have weight
    double? calories;
    if (steps != null && _latestWeight != null) {
      calories = _calculateCaloriesFromSteps(steps, _latestWeight!);
    }

    setState(() {
      _totalSteps = steps ?? 0;
      _caloriesBurned = calories;

      _state = (steps == null) ? AppState.NO_DATA : AppState.STEPS_READY;
      _isFetching = false;
    });
  }

  // Stub for sync button – keep your real implementation here if you had one
  Future<void> _syncToSupabase() async {
    if (_latestWeight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your weight before syncing.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      // 0️⃣ Create dateLogged BEFORE using it.
      // ⬅️ NEW: UPSERT INSTEAD OF INSERT
      final res = await _progressRepo.upsertTodayProgress(
        weight: _latestWeight!,
        caloriesBurned: (_caloriesBurned ?? 0).round(),
        stepsCount: _totalSteps,
      );

// progressId now comes from the upsert result
      final progressId = res['progress_id'] as int;
      final dateLogged = res['date_logged'];


      // 2️⃣ Build summary text (with date!)
      final summary = """
Date: $dateLogged
Weight: $_latestWeight kg
Steps: $_totalSteps
Calories: ${(_caloriesBurned ?? 0).round()}
""";

      // 3️⃣ Get embedding from Ollama
      final embedding = await _embedService.generateEmbedding(summary);

      // 4️⃣ Save embedding into user_progress_embeddings
      await _embedService.saveEmbeddingToSupabase(
        progressId: progressId,
        userId: supabase.auth.currentUser!.id,
        embedding: embedding,
      );

      // 5️⃣ Badge logic
      await _badgeService.checkAllProgressBadges(
        stepsToday: _totalSteps,
        caloriesToday: (_caloriesBurned ?? 0).round(),
      );

      final newBadge = await _badgeRepo.getLatestBadge();
      if (newBadge != null && mounted) {
        _showBadgePopup(context, newBadge);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Synced to Supabase!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint("Sync error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }






  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Health Tracker'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STATUS
            Text(
              'Status: $_state',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // STEPS CARD
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.directions_walk,
                        size: 36, color: Colors.blueAccent),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Steps Today',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$_totalSteps steps',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // WEIGHT CARD (user input)
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.monitor_weight,
                        size: 36, color: Colors.blueAccent),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Weight (kg)',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 44,
                            child: TextField(
                              controller: _weightController,
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: const InputDecoration(
                                hintText: 'Enter your weight in kg',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (value) {
                                final parsed = double.tryParse(value);
                                setState(() {
                                  _latestWeight = parsed;
                                  if (parsed != null && _totalSteps > 0) {
                                    _caloriesBurned = _calculateCaloriesFromSteps(
                                      _totalSteps,
                                      parsed,
                                    );
                                  } else {
                                    _caloriesBurned = null;
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _latestWeight != null
                                ? 'Current: ${_latestWeight!.toStringAsFixed(1)} kg'
                                : 'Current: N/A',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // CALORIES CARD (computed)
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                        size: 36, color: Colors.blueAccent),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calories Burned (computed)',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _caloriesBurned != null
                              ? '${_caloriesBurned!.toStringAsFixed(1)} kcal'
                              : 'N/A',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ACTION BUTTONS – Fetch + Sync
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.directions_walk),
                    onPressed: _isFetching ? null : _fetchSteps,
                    label:
                    Text(_isFetching ? 'Fetching...' : 'Fetch Steps + Recalc'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cloud_upload),
                    onPressed: _isSyncing ? null : _syncToSupabase,
                    label:
                    Text(_isSyncing ? 'Syncing...' : 'Sync to Supabase'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primary),
                      foregroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 🔥 Add this
            ElevatedButton(
              onPressed: () async {
                final batchGen = BatchEmbeddingGenerator(
                  progressRepo: ProgressRepository(),
                  embeddingService: EmbeddingService(),
                  client: supabase,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Generating embeddings…")),
                );

                await batchGen.generateAllMissingEmbeddings();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Batch embeddings generated!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text("Generate All Embeddings"),
            ),
            const SizedBox(height: 16),


            // Optional raw data list (still here, even if empty for now)
            Expanded(
              child: ListView.builder(
                itemCount: _healthData.length,
                itemBuilder: (context, index) {
                  final point = _healthData[index];
                  final value = point.value;
                  final numeric = value is NumericHealthValue
                      ? value.numericValue
                      : value.toString();
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    elevation: 2,
                    child: ListTile(
                      title: Text(
                          '${point.typeString}: $numeric ${point.unitString}'),
                      subtitle: Text(
                        '${point.dateFrom} -> ${point.dateTo}\n'
                            'Source: ${point.sourceName}\n'
                            'Recording Method: ${point.recordingMethod}',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


