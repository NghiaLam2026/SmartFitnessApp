import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_fitness_app/features/tracking/badges/badge_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../../core/supabase/supabase_client.dart';
import 'ai_coach_chat_screen.dart';

final profileProvider = FutureProvider.family<Map<String, dynamic>?, String?>((
  ref,
  userId,
) async {
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

    // Cache string operations to avoid repeated computation
    final emailParts = auth.user?.email?.split('@');
    final fallbackName = (emailParts != null && emailParts.isNotEmpty)
        ? emailParts.first
        : 'Friend';
    final greetingName = (name != null && name.isNotEmpty)
        ? name
        : fallbackName;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Smart Fitness'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await context.push('/profile');
              ref.invalidate(profileProvider(auth.user?.id));
            },
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
          ),
          IconButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(context),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.refresh(profileProvider(auth.user?.id).future),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                  child: _Header(greetingName: greetingName),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  child: _QuickActions(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: _Highlights(),
                ),
              ),
            ],
          ),
        ),
      ),
      //Add this
      floatingActionButton: FloatingActionButton(
        onPressed: (){
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AiCoachChatScreen()),
          );
        },
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.greetingName});
  final String greetingName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good to see you,',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.w400,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          greetingName,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        _ActionCard(
          title: 'My Workouts',
          subtitle: 'View and manage your workout plans',
          icon: Icons.flash_on_rounded,
          color: theme.colorScheme.primary,
          onTap: () => context.push('/home/workouts'),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          title: 'Recipes',
          subtitle: 'Discover healthy meal ideas',
          icon: Icons.restaurant_menu_rounded,
          color: Colors.orange,
          onTap: () => context.push('/home/recipes'),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          title: 'Injury Prevention',
          subtitle: 'Learn how to stay injury-free',
          icon: Icons.health_and_safety_rounded,
          color: Colors.green,
          onTap: () => context.push('/home/injury'),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          title: 'Scheduler',
          subtitle: 'Plan your fitness schedule',
          icon: Icons.calendar_today_rounded,
          color: Colors.blue,
          onTap: () => context.push('/home/scheduler'),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          title: 'Health News',
          subtitle: 'Stay updated with fitness news',
          icon: Icons.article_rounded,
          color: Colors.purple,
          onTap: () => context.push('/home/news'),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          title: 'Events',
          subtitle: 'Find local events near you',
          icon: Icons.event_rounded,
          color: const Color.fromARGB(255, 171, 176, 39),
          onTap: () => context.push('/home/events'),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          title: 'Meditation',
          subtitle: 'Help improve your mental wellness',
          icon: Icons.event_rounded,
          color: const Color.fromARGB(255, 219, 42, 180),
          onTap: () => context.push('/home/meditation'),
        ),
        const SizedBox(height: 12),

      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
                size: 24,
              ),
            ],
          ),
        ),
      ),
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
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _HighlightCard(
                title: 'Today\'s Goal',
                subtitle: 'Complete 1 workout',
                icon: Icons.flag_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              _HighlightCard(
                title: 'Streak',
                subtitle: '3 days',
                icon: Icons.local_fire_department_rounded,
                color: Colors.orange,
              ),
              const SizedBox(width: 12),
              _HighlightCard(
                title: 'Step Tracker',
                subtitle: 'Track your daily steps',
                icon: Icons.directions_walk_rounded,
                color: Colors.blue,
                onTap: () => context.push('/home/activity-tracker'),
              ),
              const SizedBox(width: 12),
              _HighlightCard(
                title: 'Mood Calendar',
                subtitle: 'Check your Mood',
                icon: Icons.mood_rounded,
                color: Colors.deepPurple,
                onTap: () => context.push('/home/mood'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: card,
        ),
      );
    }

    return card;
  }
}

class _BadgeRow extends StatelessWidget{
  const _BadgeRow({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context){
    final badgeRepo = BadgeRepository();

    return FutureBuilder(
      future: badgeRepo.getAllBadges(),
      builder: (context, snapshot){
        //while loading badges
        if (snapshot.connectionState == ConnectionState.waiting){
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        //No badges yet
        if (!snapshot.hasData || (snapshot.data as List).isEmpty){
          return const SizedBox(
            height: 80,
            child: Center(
              child: Text(
                "No Badges yet - keep going!",
                style: TextStyle(fontSize: 16),
              ),
            ),
          );
        }
        final badges = snapshot.data as List<Map<String, dynamic>>;
        //Build badge list
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "My Badges",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: badges.length,
                separatorBuilder:  (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, i){
                  final badge = badges[i];
                  return Column(
                    children: [
                      //Badge image
                      Image.network(badge["icon_url"],
                      height: 55,
                      width: 55,
                      fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 4),
                      //Badge name
                      Text(
                        badge["badge_name"],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            )
          ],
        );
      },
    );
  }
}
