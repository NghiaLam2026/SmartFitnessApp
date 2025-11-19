import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'meditation_page.dart';

class MeditationDetailPage extends StatefulWidget {
  const MeditationDetailPage({super.key, required this.routine});

  final MeditationRoutine routine;

  @override
  State<MeditationDetailPage> createState() => _MeditationDetailPageState();
}

class _MeditationDetailPageState extends State<MeditationDetailPage> {
  YoutubePlayerController? _ytController;
  late final Stopwatch _stopwatch;

  bool get _hasVideoUrl =>
      widget.routine.videoUrl != null &&
      widget.routine.videoUrl!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    if (_hasVideoUrl) {
      final id = _extractYoutubeId(widget.routine.videoUrl!.trim());
      if (id != null) {
        _ytController = YoutubePlayerController(
          initialVideoId: 'inpok4MKVLM', // Box breathing video
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            enableCaption: true,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
    }
    _ytController?.dispose();
    super.dispose();
  }

  /// Extract YouTube video ID from:
  ///  - https://www.youtube.com/watch?v=VIDEO_ID
  ///  - https://youtu.be/VIDEO_ID
  String? _extractYoutubeId(String url) {
    try {
      final uri = Uri.parse(url);

      // Standard watch URL
      if ((uri.host.contains('youtube.com') ||
              uri.host.contains('youtube-nocookie.com')) &&
          uri.path == '/watch') {
        return uri.queryParameters['v'];
      }

      // Short youtu.be URL
      if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.last;
      }

      // Fallback to package helper (handles more formats)
      return YoutubePlayer.convertUrlToId(url);
    } catch (_) {
      return YoutubePlayer.convertUrlToId(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routine = widget.routine;

    return WillPopScope(
      onWillPop: () async {
        _popWithElapsed();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Meditation'),
          leading: BackButton(onPressed: _popWithElapsed),
        ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: title / subtitle / duration
            Text(
              routine.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            if (routine.subtitle.isNotEmpty)
              Text(
                routine.subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 4),
            if (routine.duration.isNotEmpty)
              Text(
                routine.duration,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 16),

            // Instructions card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.colorScheme.surfaceContainerHighest,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      routine.description.isNotEmpty
                          ? routine.description
                          : 'Instructions coming soon.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            // Video Tutorial card
            if (_hasVideoUrl) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Video Tutorial',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_ytController != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: YoutubePlayer(
                              controller: _ytController!,
                              showVideoProgressIndicator: true,
                              progressIndicatorColor: theme.colorScheme.primary,
                            ),
                          ),
                        )
                      else
                        // Fallback if URL is not a valid YouTube link
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: theme.colorScheme.primaryContainer,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Unable to embed this video. You can still watch it using the link below.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.routine.videoUrl!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  void _popWithElapsed() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(_stopwatch.elapsed);
    }
  }
}
