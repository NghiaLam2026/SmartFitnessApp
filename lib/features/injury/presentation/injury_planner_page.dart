import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../exercises/domain/exercise_models.dart';
import '../../exercises/infrastructure/exercises_repository.dart';

final _exRepoProvider = Provider<ExercisesRepository>((ref) => SupabaseExercisesRepository());

final _exercisesProvider = FutureProvider.autoDispose.family<List<Exercise>, String>((ref, area) async {
  if (area.isEmpty) return <Exercise>[];
  return ref
      .read(_exRepoProvider)
      .fetchExercises(muscle: area)
      .timeout(const Duration(seconds: 12));
});

class InjuryPlannerPage extends ConsumerStatefulWidget {
  const InjuryPlannerPage({super.key});

  @override
  ConsumerState<InjuryPlannerPage> createState() => _InjuryPlannerPageState();
}

class _InjuryPlannerPageState extends ConsumerState<InjuryPlannerPage> {
  String? _bodyArea; // selected leaf body area used for query
  // Simplified: no goal/equipment for now
  BodyGroup? _group; // selected group

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = (_bodyArea == null || _bodyArea!.isEmpty)
        ? const AsyncValue<List<Exercise>>.data(<Exercise>[]) // don't query until an area is chosen
        : ref.watch(_exercisesProvider(_bodyArea!));
    return Scaffold(
      appBar: AppBar(title: const Text('Injury Prevention')),
      body: Column(
        children: [
          _Filters(
            group: _group,
            onGroup: (g){ setState(()=> _group = g); },
            selectedArea: _bodyArea,
            onArea: (a){ setState(()=> _bodyArea = a); },
          ),
          const Divider(height: 1),
          Expanded(
            child: (_bodyArea == null)
                ? const Center(child: Text('Select a body area to see exercises'))
                : exercisesAsync.when(
              data: (list){
                if (list.isEmpty) {
                  return const Center(child: Text('No exercises found for this area.'));
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i){
                    final ex = list[i];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(ex.muscle ?? '—'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: (){
                            context.push('/home/exercise/${ex.id}');
                          },
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorRetry(
                message: 'Unable to load exercises. Check connection and retry.\n\nError: $e',
                onRetry: (){ if (_bodyArea != null && _bodyArea!.isNotEmpty) { final _ = ref.refresh(_exercisesProvider(_bodyArea!)); } },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum BodyGroup { upper, spineCore, lower}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.group,
    required this.selectedArea,
    required this.onGroup,
    required this.onArea,
  });
  final BodyGroup? group;
  final String? selectedArea;
  final ValueChanged<BodyGroup?> onGroup;
  final ValueChanged<String?> onArea;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupSelector(group: group, onGroup: onGroup),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(
              key: ValueKey(group),
              child: _SubAreaChips(group: group, selected: selectedArea, onArea: onArea),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// Segment chips for goal/equipment removed in simplified version

class _GroupSelector extends StatelessWidget {
  const _GroupSelector({required this.group, required this.onGroup});
  final BodyGroup? group;
  final ValueChanged<BodyGroup?> onGroup;

  @override
  Widget build(BuildContext context) {
    Widget chip(BodyGroup g, String label, IconData icon) {
      final bool sel = g == group;
      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(label)],
        ),
        selected: sel,
        onSelected: (_) => onGroup(sel ? null : g),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: -8,
      children: [
        chip(BodyGroup.upper, 'Upper Body', Icons.fitness_center_rounded),
        chip(BodyGroup.spineCore, 'Spine & Core', Icons.accessibility_new_rounded),
        chip(BodyGroup.lower, 'Lower Body', Icons.directions_run_rounded),
      ],
    );
  }
}

class _SubAreaChips extends StatelessWidget {
  const _SubAreaChips({required this.group, required this.selected, required this.onArea});
  final BodyGroup? group;
  final String? selected;
  final ValueChanged<String?> onArea;

  List<String> _areasFor(BodyGroup g) {
    switch (g) {
      case BodyGroup.upper:
        return const ['neck','shoulder','elbow','wrist','forearm','hand'];
      case BodyGroup.spineCore:
        return const ['thoracic spine','lumbar/lower back','core/abdominals'];
      case BodyGroup.lower:
        return const ['hip','glutes','knee','ankle','foot'];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (group == null) {
      return const SizedBox(height: 0);
    }
    final areas = _areasFor(group!);
    return Wrap(
      spacing: 8,
      runSpacing: -8,
      children: areas.map((a){
        final bool sel = a == selected;
        return ChoiceChip(
          label: Text(a),
          selected: sel,
          onSelected: (_) => onArea(sel ? null : a),
        );
      }).toList(),
    );
  }
}

// Old empty-state for protocols removed in exercises-first variant

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}