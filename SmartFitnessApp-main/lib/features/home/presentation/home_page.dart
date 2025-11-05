import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/application/auth_controller.dart';
import '../../../core/supabase/supabase_client.dart';
import 'package:smart_fitness_app/features/tracking/mock_test_tracker_screen.dart';

final profileProvider = FutureProvider.family<Map<String, dynamic>?, String?>((ref, userId) async {
  if (userId == null) return null;
  final data = await supabase
      .from('profiles')
      .select('display_name, zip_code')
      .eq('user_id', userId)
      .maybeSingle();
  return data;
});

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final profileAsync = ref.watch(profileProvider(auth.user?.id));

    final name = profileAsync.maybeWhen(
      data: (p) => (p?['display_name'] as String?)?.trim(),
      orElse: () => null,
    );

    final fallbackName = auth.user?.email?.split('@').first ?? 'Friend';
    final greetingName = (name != null && name.isNotEmpty) ? name : fallbackName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Fitness'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(context),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          )
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(profileProvider(auth.user?.id).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              _Header(greetingName: greetingName, profileAsync: profileAsync),
              const SizedBox(height: 16),
              _QuickActions(),
              const SizedBox(height: 16),
              _Highlights(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.greetingName, required this.profileAsync});
  final String greetingName;
  final AsyncValue<Map<String, dynamic>?> profileAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good to see you,',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          greetingName,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        profileAsync.when(
          data: (p) {
            final hasName = (p?['display_name'] as String?)?.trim().isNotEmpty == true;
            if (hasName) return const SizedBox.shrink();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('Complete your profile'),
                subtitle: const Text('Add your name and ZIP to personalize workouts and news.'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => context.push('/signup'),
              ),
            );
          },
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.flash_on_rounded),
            label: const Text('Start Workout'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            label: const Text('My Plan'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _Highlights extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Highlights',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children:  [ //here i made changes - viviana
              const _HighlightCard(title: 'Today\'s Goal', subtitle: 'complete 1 workout', icon: Icons.flag_rounded),
              const SizedBox(width: 12),
              const _HighlightCard(title: 'Streak', subtitle: '3 days', icon: Icons.local_fire_department_rounded),
              const SizedBox(width:12),
              //new tappable step trcker card
              GestureDetector(
                onTap: (){
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HealthTrackerScreen(),
                    )
                  );
                },
                child: const _HighlightCard(title: 'Step Tracker', subtitle: 'Track your daily steps', icon: Icons.directions_walk_rounded),
              )
            ],
          ),
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.title, required this.subtitle, required this.icon});
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const Spacer(),
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
            ],
          ),
        ),
      ),
    );
  }
}


