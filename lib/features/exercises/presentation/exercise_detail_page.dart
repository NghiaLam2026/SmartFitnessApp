import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../domain/exercise_models.dart';
import '../infrastructure/exercises_repository.dart';

final _repoProvider = Provider<ExercisesRepository>((ref) => SupabaseExercisesRepository());
final _exerciseProvider = FutureProvider.family<Exercise?, String>((ref, id) async {
  return ref.read(_repoProvider).fetchExerciseById(id);
});

class ExerciseDetailPage extends ConsumerStatefulWidget {
  const ExerciseDetailPage({super.key, required this.exerciseId});
  final String exerciseId;

  @override
  ConsumerState<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends ConsumerState<ExerciseDetailPage> {
  VideoPlayerController? _videoController;
  YoutubePlayerController? _youtubeController;
  bool _isVideoInitialized = false;
  bool _isLoadingVideo = false;
  String? _errorMessage;
  bool _isYouTube = false;
  String? _initializedVideoUrl;

  bool _isYouTubeUrl(String url) {
    return url.contains('youtube.com') || url.contains('youtu.be');
  }

  String? _extractYouTubeVideoId(String url) {
    // Handle different YouTube URL formats
    if (url.contains('youtube.com/watch?v=')) {
      final regExp = RegExp(r'youtube\.com/watch\?v=([^&]+)');
      final match = regExp.firstMatch(url);
      return match?.group(1);
    } else if (url.contains('youtube.com/embed/')) {
      final regExp = RegExp(r'youtube\.com/embed/([^?]+)');
      final match = regExp.firstMatch(url);
      return match?.group(1);
    } else if (url.contains('youtu.be/')) {
      final regExp = RegExp(r'youtu\.be/([^?]+)');
      final match = regExp.firstMatch(url);
      return match?.group(1);
    } else if (url.contains('youtube.com/')) {
      final regExp = RegExp(r'youtube\.com/.*[?&]v=([^&]+)');
      final match = regExp.firstMatch(url);
      return match?.group(1);
    }
    return null;
  }

  void _initializeVideo(String url) {
    // Prevent re-initialization of the same video
    if (_initializedVideoUrl == url) return;
    
    if (_isYouTubeUrl(url)) {
      final videoId = _extractYouTubeVideoId(url);
      if (videoId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid YouTube URL')),
        );
        return;
      }
      
      _videoController?.dispose();
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          hideControls: false,
          loop: false,
          controlsVisibleAtStart: false,
        ),
      );
      
      setState(() {
        _isVideoInitialized = true;
        _isYouTube = true;
        _initializedVideoUrl = url;
      });
      return;
    }

    // For non-YouTube URLs, use video_player
    setState(() {
      _isLoadingVideo = true;
    });

    try {
      _youtubeController?.dispose();
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      
      controller.initialize().then((_) {
        if (mounted) {
          setState(() {
            _videoController = controller;
            _isVideoInitialized = true;
            _isLoadingVideo = false;
            _isYouTube = false;
            _initializedVideoUrl = url;
          });
          _videoController?.play();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load video: $e')),
        );
        setState(() {
          _isLoadingVideo = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_exerciseProvider(widget.exerciseId));
    
    // Initialize video once when exercise data is first loaded
    async.whenData((e) {
      if (e != null && !_isVideoInitialized && e.videoUrl != null && e.videoUrl!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isVideoInitialized) {
            _initializeVideo(e.videoUrl!);
          }
        });
      }
    });
    
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise')), 
      body: async.when(
        data: (e){
          if (e == null) return const Center(child: Text('Not found'));
          
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(e.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final theme = Theme.of(context);
                  final muscleText = e.muscle ?? '—';
                  final equipmentText = e.equipment ?? 'none';
                  final subtitleText = '$muscleText • $equipmentText';
                  return Text(
                    subtitleText,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                  );
                },
              ),
              const SizedBox(height: 16),
              if ((e.thumbnailUrl ?? '').isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    e.thumbnailUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 180,
                        color: Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 180,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              if ((e.instructions ?? '').isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Instructions', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(e.instructions!),
                      ],
                    ),
                  ),
                ),
              ],
              if ((e.videoUrl ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Video Tutorial', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      if (_isVideoInitialized && _isYouTube && _youtubeController != null)
                        YoutubePlayer(
                          controller: _youtubeController!,
                          showVideoProgressIndicator: true,
                          progressIndicatorColor: Theme.of(context).colorScheme.primary,
                          progressColors: ProgressBarColors(
                            playedColor: Theme.of(context).colorScheme.primary,
                            handleColor: Theme.of(context).colorScheme.primary,
                            bufferedColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                            backgroundColor: Colors.grey.withOpacity(0.3),
                          ),
                          onReady: () {
                            setState(() {});
                          },
                        )
                      else if (_isVideoInitialized && !_isYouTube && _videoController != null && _videoController!.value.isInitialized)
                        Column(
                          children: [
                            AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(_videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                                    onPressed: () {
                                      setState(() {
                                        if (_videoController!.value.isPlaying) {
                                          _videoController!.pause();
                                        } else {
                                          _videoController!.play();
                                        }
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.replay),
                                    onPressed: () {
                                      _videoController!.seekTo(Duration.zero);
                                      _videoController!.pause();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else if (_isLoadingVideo)
                        Column(
                          children: [
                            Container(
                              height: 200,
                              color: Colors.grey[900],
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                          ],
                        )
                      else if (_errorMessage != null)
                        Column(
                          children: [
                            Container(
                              height: 200,
                              color: Colors.grey[900],
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.white, size: 48),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(color: Colors.white),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        // Show loading placeholder while video is initializing
                        Container(
                          height: 200,
                          color: Colors.grey[900],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}


