import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../auth/application/auth_controller.dart';

final userInterestsProvider = FutureProvider.family<Map<String, dynamic>?, String?>((ref, userId) async {
  if (userId == null) return null;
  final data = await supabase
      .from('profiles')
      .select('interests')
      .eq('user_id', userId)
      .maybeSingle();
  return (data != null && data['interests'] is Map<String, dynamic>)
      ? (data['interests'] as Map<String, dynamic>)
      : null;
});

class InterestsPage extends ConsumerStatefulWidget {
  const InterestsPage({super.key});

  @override
  ConsumerState<InterestsPage> createState() => _InterestsPageState();
}

class _InterestsPageState extends ConsumerState<InterestsPage> {
  static const List<String> kAllTopics = <String>[
    'Nutrition',
    'Weight Loss',
    'Strength Training',
    'Cardio',
    'Yoga',
    'Mobility',
    'Mental Health',
    'Recovery',
    'Injury Prevention',
    'Running',
    'CrossFit',
    'Marathon',
  ];

  final Set<String> _selected = <String>{};
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = ref.read(authControllerProvider);
    final interestsAsync = ref.read(userInterestsProvider(auth.user?.id));
    interestsAsync.whenData((data) {
      final topics = (data?['topics'] is List)
          ? List<String>.from(data!['topics'] as List)
          : <String>[];
      _selected
        ..clear()
        ..addAll(topics);
      if (mounted) setState(() {});
    });
  }

  Future<void> _saveAndContinue() async {
    final auth = ref.read(authControllerProvider);
    final userId = auth.user?.id;
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      await supabase
          .from('profiles')
          .update({
            'interests': {
              'topics': _selected.toList(),
              'skipped': false,
            },
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      if (mounted) context.go('/home');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _skipForNow() async {
    final auth = ref.read(authControllerProvider);
    final userId = auth.user?.id;
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      // Mark skipped to avoid repeated prompts on next login
      await supabase
          .from('profiles')
          .update({
            'interests': {
              'topics': <String>[],
              'skipped': true,
            },
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      if (mounted) context.go('/home');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final interestsAsync = ref.watch(userInterestsProvider(auth.user?.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Interests'),
      ),
      body: SafeArea(
        child: interestsAsync.when(
          data: (_) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tell us what you care about',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'We\'ll personalize health articles on your dashboard based on these topics.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final topic in kAllTopics)
                          FilterChip(
                            selected: _selected.contains(topic),
                            onSelected: (s) {
                              setState(() {
                                if (s) {
                                  _selected.add(topic);
                                } else {
                                  _selected.remove(topic);
                                }
                              });
                            },
                            label: Text(topic),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _saveAndContinue,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Save and Continue'),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _saving ? null : _skipForNow,
                    child: const Text('Skip for now'),
                  ),
                ),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Something went wrong', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Please try again later.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


