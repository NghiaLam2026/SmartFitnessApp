import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/protocol_models.dart';
import '../infrastructure/injury_repository.dart';

final _injuryRepoProvider = Provider<InjuryRepository>((ref) => InjuryRepository());

final _protocolProvider = FutureProvider.family<Protocol?, String>((ref, id) async {
  final rows = await supabase
      .from('protocols')
      .select('id, name, type, body_area, description')
      .eq('id', id)
      .maybeSingle();
  if (rows == null) return null;
  return Protocol.fromMap(rows);
});

final _stepsProvider = FutureProvider.family<List<ProtocolStepModel>, String>((ref, id) async {
  return ref.read(_injuryRepoProvider).fetchSteps(id);
});

class InjuryDetailPage extends ConsumerWidget {
  const InjuryDetailPage({super.key, required this.protocolId});
  final String protocolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = supabase.auth.currentUser;
    final protoAsync = ref.watch(_protocolProvider(protocolId));
    final stepsAsync = ref.watch(_stepsProvider(protocolId));

    return Scaffold(
      appBar: AppBar(title: const Text('Routine')),
      body: protoAsync.when(
        data: (p){
          if (p == null) return const Center(child: Text('Not found'));
          return Column(
            children: [
              ListTile(
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${p.type.name.toUpperCase()} • ${p.bodyArea ?? 'full body'}'),
              ),
              if ((p.description ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(p.description!),
                ),
              const Divider(height: 1),
              Expanded(
                child: stepsAsync.when(
                  data: (steps){
                    if (steps.isEmpty) return const Center(child: Text('No steps'));
                    return ListView.separated(
                      itemCount: steps.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i){
                        final s = steps[i];
                        final details = <String>[
                          if (s.reps != null) '${s.reps} reps',
                          if (s.durationSec != null) '${s.durationSec}s',
                        ].join(' • ');
                        return ListTile(
                          leading: CircleAvatar(child: Text('${s.orderIndex}')),
                          title: Text(s.exerciseName),
                          subtitle: Text(details.isEmpty ? '—' : details),
                          trailing: s.exerciseId != null && s.exerciseId!.isNotEmpty 
                              ? const Icon(Icons.open_in_new_rounded, size: 20)
                              : null,
                          onTap: s.exerciseId != null && s.exerciseId!.isNotEmpty 
                              ? () {
                                  context.push('/home/exercise/${s.exerciseId!}');
                                }
                              : null,
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: user == null ? null : () async {
                          await ref.read(_injuryRepoProvider).assignToPlan(user.id, protocolId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to plan')));
                          }
                        },
                        icon: const Icon(Icons.playlist_add_rounded),
                        label: const Text('Add to Plan'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (){
                          context.push('/injury/player', extra: {'protocolId': protocolId});
                        },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Start Guided'),
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
      floatingActionButton: supabase.auth.currentUser == null ? null : FavoriteFAB(protocolId: protocolId),
    );
  }
}

class FavoriteFAB extends ConsumerStatefulWidget {
  const FavoriteFAB({super.key, required this.protocolId});
  final String protocolId;

  @override
  ConsumerState<FavoriteFAB> createState() => _FavoriteFABState();
}

class _FavoriteFABState extends ConsumerState<FavoriteFAB> {
  bool _fav = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final ids = await ref.read(_injuryRepoProvider).fetchFavoriteProtocolIds(user.id);
    if (!mounted) return;
    setState(()=> _fav = ids.contains(widget.protocolId));
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    if (user == null) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      onPressed: _loading ? null : () async {
        setState(()=> _loading = true);
        try {
          final next = await ref.read(_injuryRepoProvider).toggleFavorite(user.id, widget.protocolId);
          if (!mounted) return;
          setState(()=> _fav = next);
        } finally {
          if (mounted) setState(()=> _loading = false);
        }
      },
      icon: Icon(_fav ? Icons.favorite : Icons.favorite_border),
      label: Text(_fav ? 'Favorited' : 'Favorite'),
    );
  }
}
