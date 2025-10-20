import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_client.dart';
import '../infrastructure/workout_repository.dart';

final myWorkoutsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return <Map<String, dynamic>>[];
  final rows = await supabase
      .from('workouts')
      .select('id, title, scheduled_at, status')
      .eq('user_id', user.id)
      .order('scheduled_at', ascending: true)
      .order('id', ascending: false);
  return (rows as List<dynamic>).cast<Map<String, dynamic>>();
});

class MyPlanPage extends ConsumerWidget {
  const MyPlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final workoutsAsync = ref.watch(myWorkoutsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Plan')),
      body: SafeArea(
        child: workoutsAsync.when(
          data: (rows) {
            if (rows.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 48),
                      const SizedBox(height: 12),
                      Text('No workouts yet', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Create a workout or generate a plan to see it here.'),
                    ],
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final w = rows[i];
                final DateTime? sched = w['scheduled_at'] != null ? DateTime.tryParse(w['scheduled_at'] as String) : null;
                final subtitle = sched != null ? 'Scheduled ${_relative(sched)} • ${w['status']}' : (w['status'] as String? ?? 'planned');
                return Dismissible(
                  key: ValueKey<String>(w['id'] as String),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: Colors.red,
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete workout?'),
                            content: const Text('This will remove the workout and its sets.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
                            ],
                          ),
                        ) ??
                        false;
                  },
                  onDismissed: (_) async {
                    final repo = ref.read(workoutRepositoryProvider);
                    await repo.deleteWorkout(w['id'] as String);
                    ref.invalidate(myWorkoutsProvider);
                  },
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.fitness_center_rounded),
                      title: Text((w['title'] as String?)?.trim().isNotEmpty == true ? (w['title'] as String) : 'Workout'),
                      subtitle: Text(subtitle),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => WorkoutDetailPage(workoutId: w['id'] as String)))
                          .then((_) => ref.invalidate(myWorkoutsProvider)),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Failed to load workouts')),
        ),
      ),
    );
  }

  String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays.abs() >= 7) {
      return '${dt.month}/${dt.day}';
    }
    if (diff.isNegative) {
      final d = diff.abs();
      if (d.inDays >= 1) return 'in ${d.inDays}d';
      if (d.inHours >= 1) return 'in ${d.inHours}h';
      return 'soon';
    } else {
      if (diff.inDays >= 1) return '${diff.inDays}d ago';
      if (diff.inHours >= 1) return '${diff.inHours}h ago';
      return '${diff.inMinutes}m ago';
    }
  }
}

class WorkoutDetailPage extends ConsumerWidget {
  const WorkoutDetailPage({super.key, required this.workoutId});
  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setsAsync = ref.watch(_workoutSetsProvider(workoutId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete workout?'),
                      content: const Text('This will remove the workout and its sets.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
                      ],
                    ),
                  ) ??
                  false;
              if (!confirm) return;
              final repo = ref.read(workoutRepositoryProvider);
              await repo.deleteWorkout(workoutId);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          )
        ],
      ),
      body: SafeArea(
        child: setsAsync.when(
          data: (sets) {
            if (sets.isEmpty) return const Center(child: Text('No sets'));
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                for (final s in sets)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.checklist_rtl_rounded),
                      title: Text(s['exercise_name'] as String? ?? 'Exercise'),
                      subtitle: Text('x${s['target_reps'] ?? '-'}' + (s['target_weight'] != null ? ' • ${(s['target_weight'] as num).toStringAsFixed(((s['target_weight'] as num) % 1 == 0) ? 0 : 1)} kg' : '')), 
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Failed to load workout')),
        ),
      ),
    );
  }
}

final _workoutSetsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, workoutId) async {
  final rows = await supabase
      .from('workout_sets')
      .select('id, target_reps, target_rpe, target_weight, exercises(name)')
      .eq('workout_id', workoutId)
      .order('order_index', ascending: true);
  return (rows as List<dynamic>)
      .map((r) => <String, dynamic>{
            'id': r['id'],
            'target_reps': r['target_reps'],
            'target_rpe': r['target_rpe'],
            'target_weight': r['target_weight'],
            'exercise_name': (r['exercises'] as Map<String, dynamic>?)?['name'],
          })
      .toList();
});


