import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../domain/mood_repository.dart';
import '../infrastructure/meditation_repository.dart';

import 'meditation_detail_page.dart';

enum MeditationCategory { calm, focus, sleep }


class MeditationRoutine {
  final String id;
  final String title;
  final String subtitle;
  /// Display label, e.g. "5 min"
  final String duration;
  final MeditationCategory category;
  /// Text shown as instructions / description.
  final String description;
  /// Optional URL to a video (YouTube or Supabase Storage).
  final String? videoUrl;

  const MeditationRoutine({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.category,
    required this.description,
    this.videoUrl,
  });

  factory MeditationRoutine.fromMap(Map<String, dynamic> map) {
    final rawCategory = (map['category'] as String?)?.toLowerCase() ?? 'calm';

    // Convert text category to enum
    MeditationCategory category;
    switch (rawCategory) {
      case 'focus':
        category = MeditationCategory.focus;
        break;
      case 'sleep':
        category = MeditationCategory.sleep;
        break;
      default:
        category = MeditationCategory.calm;
    }

    // Build the duration label from duration_min
    final durationMin = map['duration_min'];
    final durationLabel = durationMin == null
        ? ''
        : '${durationMin.toString()} min';

    // Prefer 'instructions' column; fall back to 'description'
    final descriptionText =
        (map['instructions'] as String?)?.trim() ??
            (map['description'] as String?)?.trim() ??
            '';

    return MeditationRoutine(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?)?.trim() ?? 'Untitled Session',
      subtitle: (map['subtitle'] as String?)?.trim() ?? '',
      duration: durationLabel,
      category: category,
      description: descriptionText,
      videoUrl: (map['video_url'] as String?)?.trim(),
    );
  }
}





class MeditationPage extends StatefulWidget {
  const MeditationPage({super.key});

  @override
  State<MeditationPage> createState() => _MeditationPageState();
}

class _MeditationPageState extends State<MeditationPage> {
  MeditationCategory _selectedCategory = MeditationCategory.calm;
  late final MeditationRepository _repository;
  List<MeditationRoutine> _allMeditations = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = MeditationRepository();
    _loadMeditations();
  }

  Future<void> _loadMeditations() async {
    try {
      final routines = await _repository.fetchMeditations();
      if (!mounted) return;
      setState(() {
        _allMeditations = routines;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Failed to load meditations';
      });
    }
  }

  Future<void> _startSessionWithMood(
      BuildContext context,
      MeditationRoutine routine,
      ) async {
    final moodLabel = await _showPreSessionMoodSheet(context);

    if (moodLabel != null) {
      MoodRepository.instance
          .setMood(DateTime.now(), MoodSessionType.before, moodLabel);
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MeditationDetailPage(routine: routine),
      ),
    );
  }

  Future<String?> _showPreSessionMoodSheet(BuildContext context) {
    final theme = Theme.of(context);

    return showModalBottomSheet<String>(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              runSpacing: 8,
              children: [
                Text(
                  'How do you feel before this session?',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                _buildMoodOption(context, '😊 Great'),
                _buildMoodOption(context, '🙂 Good'),
                _buildMoodOption(context, '😐 Neutral'),
                _buildMoodOption(context, '😕 Low'),
                _buildMoodOption(context, '😞 Drained'),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Skip for now'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoodOption(BuildContext context, String label) {
    return ListTile(
      title: Text(label),
      onTap: () => Navigator.of(context).pop(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 1) Handle loading / error first
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meditation')),
        body: Center(child: Text(_errorMessage!)),
      );
    }

    // 2) Then filter routines by selected category
    final routines = _allMeditations
        .where((m) => m.category == _selectedCategory)
        .toList();

    // 3) Finally build the UI
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meditation'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MeditationFilters(
            selectedCategory: _selectedCategory,
            onCategoryChanged: (category) {
              setState(() => _selectedCategory = category);
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Select a session to see instructions and video.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: routines.isEmpty
                ? const Center(
              child:
              Text('No sessions available for this category yet.'),
            )
                : ListView.builder(
              itemCount: routines.length,
              itemBuilder: (context, index) {
                final routine = routines[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: _MeditationRoutineCard(
                    routine: routine,
                    onTap: () => _startSessionWithMood(context, routine),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                // adjust this route string to whatever you use for the calendar
                onPressed: () => context.push('/home/mood'),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Open Mood Calendar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _MeditationFilters extends StatelessWidget {
  const _MeditationFilters({
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  final MeditationCategory selectedCategory;
  final ValueChanged<MeditationCategory> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: SegmentedButton<MeditationCategory>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: MeditationCategory.calm,
            icon: Icon(Icons.self_improvement_outlined),
            label: Text('Calm'),
          ),
          ButtonSegment(
            value: MeditationCategory.focus,
            icon: Icon(Icons.center_focus_strong_outlined),
            label: Text('Focus'),
          ),
          ButtonSegment(
            value: MeditationCategory.sleep,
            icon: Icon(Icons.bedtime_outlined),
            label: Text('Sleep'),
          ),
        ],
        selected: {selectedCategory},
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) {
            onCategoryChanged(selection.first);
          }
        },
      ),
    );
  }
}

class _MeditationRoutineCard extends StatelessWidget {
  const _MeditationRoutineCard({
    required this.routine,
    required this.onTap,
  });

  final MeditationRoutine routine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 16,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.spa_rounded),
          ),
          title: Text(
            routine.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                routine.subtitle,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  routine.duration,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}
