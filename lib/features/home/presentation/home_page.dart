import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/application/auth_controller.dart';
import '../../../core/supabase/supabase_client.dart';
import 'package:url_launcher/url_launcher.dart';

final articlesProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, userId) async {
  if (userId == null) return <Map<String, dynamic>>[];
  // Fetch user interests
  final profile = await supabase
      .from('profiles')
      .select('interests, zip_code')
      .eq('user_id', userId)
      .maybeSingle();

  final interests = profile?['interests'];
  final List<String> topics = (interests is Map<String, dynamic> && interests['topics'] is List)
      ? List<String>.from(interests['topics'] as List)
      : <String>[];

  // Build query for articles table using overlap of topics
  final query = supabase.from('articles').select('id, title, url, source_id, published_at, topics, summary').order('published_at', ascending: false);
  List<dynamic> rows;
  if (topics.isEmpty) {
    // No interests chosen: show latest overall
    rows = await query.limit(10);
  } else {
    // Use @> or && semantics; Supabase PostgREST supports Postgres operators via query params
    // We'll use 'overlaps' (&&) by applying .contains on text[] requires rpc; instead filter client-side after fetching a recent window
    final recent = await query.limit(50);
    rows = (recent as List<dynamic>).where((r) {
      final t = (r['topics'] is List) ? List<String>.from(r['topics'] as List) : <String>[];
      return t.any((x) => topics.contains(x));
    }).take(10).toList();
  }
  return rows.cast<Map<String, dynamic>>();
});

final profileProvider = FutureProvider.family<Map<String, dynamic>?, String?>((ref, userId) async {
  if (userId == null) return null;
  final data = await supabase
      .from('profiles')
      .select('display_name, zip_code, interests')
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
    final articlesAsync = ref.watch(articlesProvider(auth.user?.id));

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
            onPressed: () => context.push('/interests'),
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Interests',
          ),
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
              const SizedBox(height: 16),
              _ArticlesSection(articlesAsync: articlesAsync),
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
            children: const [
              _HighlightCard(title: 'Today\'s Goal', subtitle: 'Complete 1 workout', icon: Icons.flag_rounded),
              SizedBox(width: 12),
              _HighlightCard(title: 'Streak', subtitle: '3 days', icon: Icons.local_fire_department_rounded),
              SizedBox(width: 12),
              _HighlightCard(title: 'Steps', subtitle: '8,450', icon: Icons.directions_walk_rounded),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArticlesSection extends ConsumerWidget {
  const _ArticlesSection({required this.articlesAsync});
  final AsyncValue<List<Map<String, dynamic>>> articlesAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your News Feed', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        articlesAsync.when(
          data: (articles) {
            if (articles.isEmpty) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('No articles yet'),
                  subtitle: const Text('Pick interests to personalize your news feed.'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => context.push('/interests'),
                ),
              );
            }
            return Column(
              children: [
                for (final a in articles.take(10)) _ArticleTile(article: a),
              ],
            );
          },
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({required this.article});
  final Map<String, dynamic> article;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String title = (article['title'] as String?) ?? 'Untitled';
    final String url = (article['url'] as String?) ?? '';
    final DateTime? publishedAt = article['published_at'] != null
        ? DateTime.tryParse(article['published_at'] as String)
        : null;
    final String subtitle = publishedAt != null
        ? 'Published ${_formatRelative(publishedAt)}'
        : 'Tap to read';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.public),
        title: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
        onTap: () async {
          if (url.isEmpty) return;
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
    );
  }

  String _formatRelative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
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