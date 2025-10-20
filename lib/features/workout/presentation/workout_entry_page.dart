import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../workout/domain/models.dart';

class WorkoutEntryPage extends StatefulWidget {
  const WorkoutEntryPage({super.key});

  @override
  State<WorkoutEntryPage> createState() => _WorkoutEntryPageState();
}

class _WorkoutEntryPageState extends State<WorkoutEntryPage> {
  WorkoutDifficulty _selected = WorkoutDifficulty.easy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            Text('What would you like to do?', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.push('/home/workout/custom'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(Icons.build_rounded),
                            SizedBox(height: 8),
                            Text('Create your own'),
                            SizedBox(height: 4),
                            Text('Add exercises, sets, reps, and rest.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.push('/home/workout/ai', extra: _selected),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(Icons.smart_toy_rounded),
                            SizedBox(height: 8),
                            Text('AI Quick-Plan'),
                            SizedBox(height: 4),
                            Text('Personalized plan in seconds.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Choose difficulty', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _TierChip(
                  label: 'Easy',
                  selected: _selected == WorkoutDifficulty.easy,
                  onTap: () => setState(() => _selected = WorkoutDifficulty.easy),
                ),
                _TierChip(
                  label: 'Medium',
                  selected: _selected == WorkoutDifficulty.medium,
                  onTap: () => setState(() => _selected = WorkoutDifficulty.medium),
                ),
                _TierChip(
                  label: 'Hard',
                  selected: _selected == WorkoutDifficulty.hard,
                  onTap: () => setState(() => _selected = WorkoutDifficulty.hard),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('What do tiers mean?'),
                subtitle: const Text('Easy RPE 4–5, Medium 6–7, Hard 7.5–8.5. You can change anytime.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}


