import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/exercise_models.dart';
import '../infrastructure/exercises_repository.dart';

final _repoProvider = Provider<ExercisesRepository>((ref) => SupabaseExercisesRepository());

final _listProvider = FutureProvider.autoDispose.family<List<Exercise>, _Query>((ref, q) async {
  return ref.read(_repoProvider).fetchExercises(
        search: q.search,
        muscle: q.muscle,
        equipment: q.equipment,
      );
});

class _Query {
  final String? search;
  final String? muscle;
  final EquipmentYesNo equipment;
  const _Query({this.search, this.muscle, this.equipment = EquipmentYesNo.any});
}

class ExerciseLibraryPage extends ConsumerStatefulWidget {
  const ExerciseLibraryPage({super.key});
  @override
  ConsumerState<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends ConsumerState<ExerciseLibraryPage> {
  String? _search;
  String? _muscle;
  final EquipmentYesNo _equipment = EquipmentYesNo.any;

  @override
  Widget build(BuildContext context) {
    final q = _Query(search: _search, muscle: _muscle, equipment: _equipment);
    final listAsync = ref.watch(_listProvider(q));
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Library')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search exercises',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (v){ setState(()=> _search = v); },
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Body area',
                  onSelected: (v){ setState(()=> _muscle = v == 'Any' ? null : v); },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'Any', child: Text('Any area')),
                    PopupMenuItem(value: 'neck', child: Text('Neck')),
                    PopupMenuItem(value: 'shoulder', child: Text('Shoulder')),
                    PopupMenuItem(value: 'elbow', child: Text('Elbow')),
                    PopupMenuItem(value: 'wrist', child: Text('Wrist')),
                    PopupMenuItem(value: 'forearm', child: Text('Forearm')),
                    PopupMenuItem(value: 'hand', child: Text('Hand')),
                    PopupMenuItem(value: 'thoracic spine', child: Text('Thoracic spine')),
                    PopupMenuItem(value: 'lumbar/lower back', child: Text('Lower back')),
                    PopupMenuItem(value: 'core/abdominals', child: Text('Core')),
                    PopupMenuItem(value: 'hip', child: Text('Hip')),
                    PopupMenuItem(value: 'glutes', child: Text('Glutes')),
                    PopupMenuItem(value: 'knee', child: Text('Knee')),
                    PopupMenuItem(value: 'ankle', child: Text('Ankle')),
                    PopupMenuItem(value: 'foot', child: Text('Foot')),
                    PopupMenuItem(value: 'general mobility', child: Text('General mobility')),
                  ],
                  child: const Icon(Icons.tune_rounded),
                )
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: listAsync.when(
              data: (list){
                if (list.isEmpty) {
                  return const Center(child: Text('No exercises found'));
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i){
                    final e = list[i];
                    final initial = e.name.isNotEmpty ? e.name[0].toUpperCase() : '?';
                    final subtitle = '${e.muscle ?? '—'} • ${(e.equipment ?? 'none')}';
                    return ListTile(
                      leading: CircleAvatar(child: Text(initial)),
                      title: Text(e.name),
                      subtitle: Text(subtitle),
                      onTap: () => context.push('/home/exercise/${e.id}'),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          )
        ],
      ),
    );
  }
}


