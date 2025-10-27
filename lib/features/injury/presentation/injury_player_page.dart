import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../domain/protocol_models.dart';
import '../infrastructure/injury_repository.dart';
import '../../exercises/domain/exercise_models.dart';
import '../../exercises/infrastructure/exercises_repository.dart';

final _repoProvider = Provider<InjuryRepository>((ref) => InjuryRepository());
final _stepsProvider = FutureProvider.family<List<ProtocolStepModel>, String>((ref, id) async {
  return ref.read(_repoProvider).fetchSteps(id);
});

final _exRepoProvider = Provider<ExercisesRepository>((ref) => SupabaseExercisesRepository());

final _exerciseProvider = FutureProvider.autoDispose.family<Exercise?, String?>((ref, id) async {
  if (id == null || id.isEmpty) return null;
  return ref.read(_exRepoProvider).fetchExerciseById(id);
});

class InjuryPlayerPage extends ConsumerStatefulWidget {
  const InjuryPlayerPage({super.key, required this.protocolId});
  final String protocolId;

  @override
  ConsumerState<InjuryPlayerPage> createState() => _InjuryPlayerPageState();
}

class _InjuryPlayerPageState extends ConsumerState<InjuryPlayerPage> {
  int _index = 0;
  int _remaining = 0;
  Timer? _timer;
  bool _running = false;
  VideoPlayerController? _videoController;
  String? _currentVideoUrl;

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _remaining = seconds;
      _running = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        setState(()=> _running = false);
      }
      setState(()=> _remaining -= 1);
    });
  }

  void _initializeVideo(String url) {
    if (_currentVideoUrl == url) return; // Already playing this video
    
    _videoController?.dispose();
    setState(() {
      _currentVideoUrl = url;
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _videoController?.play();
          }
        });
    });
  }

  Future<bool> _confirmExit() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context){
        return AlertDialog(
          title: const Text('Exit routine?'),
          content: const Text('Do you want to resume later or discard progress?'),
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(context, false), child: const Text('Resume')),
            FilledButton(onPressed: ()=> Navigator.pop(context, true), child: const Text('Discard')),
          ],
        );
      }
    );
    return res ?? false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stepsAsync = ref.watch(_stepsProvider(widget.protocolId));
    return WillPopScope(
      onWillPop: () async {
        final discard = await _confirmExit();
        return discard;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Guided Routine'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final discard = await _confirmExit();
              if (discard && context.mounted) context.pop();
            },
          ),
        ),
        body: stepsAsync.when(
          data: (steps){
            if (steps.isEmpty) return const Center(child: Text('No steps'));
            final step = steps[_index.clamp(0, steps.length - 1)];
            final total = steps.length;
            final isLast = _index >= total - 1;
            final exerciseAsync = ref.watch(_exerciseProvider(step.exerciseId));
            
            return Column(
              children: [
                LinearProgressIndicator(value: (_index + 1) / total),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.self_improvement_rounded, size: 96, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 12),
                        Text(step.exerciseName, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(_running ? '$_remaining s' : (step.durationSec != null ? '${step.durationSec}s' : (step.reps != null ? '${step.reps} reps' : ''))),
                        if ((step.notes ?? '').isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(step.notes!),
                          )
                        ],
                        if (step.exerciseId != null && step.exerciseId!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          exerciseAsync.when(
                            data: (exercise) {
                              if (exercise == null) return const SizedBox.shrink();
                              final hasVideo = exercise.videoUrl != null && exercise.videoUrl!.isNotEmpty;
                              
                              if (hasVideo && exercise.videoUrl == _currentVideoUrl && _videoController != null && _videoController!.value.isInitialized) {
                                // Show embedded video player
                                return Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: AspectRatio(
                                        aspectRatio: _videoController!.value.aspectRatio,
                                        child: VideoPlayer(_videoController!),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        if (_videoController!.value.isPlaying) {
                                          _videoController!.pause();
                                        } else {
                                          _videoController!.play();
                                        }
                                      },
                                      icon: Icon(_videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                                      label: Text(_videoController!.value.isPlaying ? 'Pause' : 'Play'),
                                    ),
                                  ],
                                );
                              } else if (hasVideo) {
                                // Show play button to initialize video
                                return Column(
                                  children: [
                                    Container(
                                      height: 200,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[900],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Icon(Icons.play_circle_outline_rounded, 
                                          size: 64, 
                                          color: Colors.white.withOpacity(0.8)),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        _initializeVideo(exercise.videoUrl!);
                                      },
                                      icon: const Icon(Icons.play_circle_outline_rounded),
                                      label: const Text('Load Video'),
                                    ),
                                  ],
                                );
                              }
                              
                              return const SizedBox.shrink();
                            },
                            loading: () => Column(
                              children: [
                                Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(child: CircularProgressIndicator()),
                                ),
                              ],
                            ),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () {
                              context.push('/home/exercise/${step.exerciseId!}');
                            },
                            icon: const Icon(Icons.info_outline_rounded),
                            label: const Text('View Details'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _running || step.durationSec == null ? null : (){ _startTimer(step.durationSec!); },
                          icon: const Icon(Icons.timer_rounded),
                          label: const Text('Start Timer'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: (){
                            if (!isLast) {
                              // Clean up video when moving to next step
                              _videoController?.dispose();
                              _videoController = null;
                              _currentVideoUrl = null;
                              
                              setState(()=> _index += 1);
                              final next = steps[_index];
                              if (next.durationSec != null) {
                                // auto-prepare timer readout
                                setState(()=> _remaining = next.durationSec!);
                              } else {
                                setState(()=> _remaining = 0);
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Routine complete!')));
                              context.pop();
                            }
                          },
                          icon: Icon(isLast ? Icons.check_rounded : Icons.skip_next_rounded),
                          label: Text(isLast ? 'Finish' : 'Next'),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}


