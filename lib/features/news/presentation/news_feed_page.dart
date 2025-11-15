import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../application/news_providers.dart';
import '../domain/news_models.dart';

class NewsFeedPage extends ConsumerWidget {
  const NewsFeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTopic = ref.watch(selectedNewsTopicProvider);
    final viewingFavorites = ref.watch(viewingFavoritesProvider);
    final articlesAsync = ref.watch(newsArticlesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health News Feed'),
        actions: [
          if (selectedTopic != null && !viewingFavorites)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh articles',
              onPressed: () {
                // Force refresh by setting flag and invalidating
                ref.read(forceRefreshProvider.notifier).state = true;
                ref.invalidate(newsArticlesProvider);
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Topic selector and Favorites button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _TopicDropdown(
                      selectedTopic: viewingFavorites ? null : selectedTopic,
                      onTopicSelected: (topic) {
                        ref.read(viewingFavoritesProvider.notifier).state = false;
                        // Clear force refresh when switching topics
                        ref.read(forceRefreshProvider.notifier).state = false;
                        ref.read(selectedNewsTopicProvider.notifier).state = topic;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  _FavoritesButton(
                    isSelected: viewingFavorites,
                    onTap: () {
                      final newValue = !viewingFavorites;
                      ref.read(viewingFavoritesProvider.notifier).state = newValue;
                      // Clear force refresh when switching views
                      ref.read(forceRefreshProvider.notifier).state = false;
                      if (newValue) {
                        ref.read(selectedNewsTopicProvider.notifier).state = null;
                      }
                    },
                  ),
                ],
              ),
            ),

            // Articles list
            Expanded(
              child: viewingFavorites
                  ? articlesAsync.when(
                      data: (articles) {
                        if (articles.isEmpty) {
                          return _EmptyState(
                            message: 'No favorited articles yet',
                            subtitle: 'Tap on an article and select "Save to Favorites" to add articles here',
                            icon: Icons.favorite_border_rounded,
                          );
                        }
                        return RefreshIndicator(
                          onRefresh: () async {
                            try {
                              ref.invalidate(newsArticlesProvider);
                              await ref.read(newsArticlesProvider.future);
                            } catch (e) {
                              // Error is handled by the provider's error state
                            }
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemBuilder: (_, i) {
                              final article = articles[i];
                              return _ArticleCard(
                                article: article,
                                onTap: () {
                                  _showArticleOptions(context, ref, article);
                                },
                              );
                            },
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemCount: articles.length,
                          ),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, st) => _EmptyState(
                        message: 'Error loading favorites: ${e.toString()}',
                        icon: Icons.error_outline_rounded,
                      ),
                    )
                  : selectedTopic == null && !viewingFavorites
                      ? _EmptyState(
                          message: 'Pick a topic from the dropdown above to see news articles',
                          icon: Icons.article_rounded,
                        )
                      : articlesAsync.when(
                      data: (articles) {
                        if (articles.isEmpty) {
                          return _EmptyState(
                            message: selectedTopic != null
                                ? 'No articles found for ${selectedTopic!.label}'
                                : 'No articles found',
                            icon: Icons.search_off_rounded,
                            showRefresh: true,
                            onRefresh: () {
                              ref.read(forceRefreshProvider.notifier).state = true;
                              ref.invalidate(newsArticlesProvider);
                            },
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () async {
                            try {
                              // Force refresh on pull-to-refresh
                              ref.read(forceRefreshProvider.notifier).state = true;
                              ref.invalidate(newsArticlesProvider);
                              await ref.read(newsArticlesProvider.future);
                            } catch (e) {
                              // Error is handled by the provider's error state
                              // Just ensure refresh indicator completes
                            }
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemBuilder: (_, i) {
                              final article = articles[i];
                              return _ArticleCard(
                                article: article,
                                onTap: () {
                                  _showArticleOptions(context, ref, article);
                                },
                              );
                            },
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemCount: articles.length,
                          ),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, st) => _EmptyState(
                        message: 'Error loading articles: ${e.toString()}',
                        icon: Icons.error_outline_rounded,
                        showRefresh: true,
                        onRefresh: () {
                          ref.read(forceRefreshProvider.notifier).state = true;
                          ref.invalidate(newsArticlesProvider);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesButton extends StatelessWidget {
  const _FavoritesButton({
    required this.isSelected,
    required this.onTap,
  });

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Favorites',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicDropdown extends StatelessWidget {
  const _TopicDropdown({
    required this.selectedTopic,
    required this.onTopicSelected,
  });

  final NewsTopic? selectedTopic;
  final ValueChanged<NewsTopic> onTopicSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<NewsTopic>(
      value: selectedTopic,
      decoration: InputDecoration(
        labelText: 'Select Health Topic',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: const Icon(Icons.category_rounded),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
      ),
      items: NewsTopic.values.map((topic) {
        return DropdownMenuItem<NewsTopic>(
          value: topic,
          child: Text(topic.label),
        );
      }).toList(),
      onChanged: (topic) {
        if (topic != null) {
          onTopicSelected(topic);
        }
      },
      hint: const Text('Choose a topic...'),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.article,
    required this.onTap,
  });

  final Article article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
              SizedBox(
                height: 200,
                width: double.infinity,
                child: Image.network(
                  article.imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.image_not_supported_rounded,
                      size: 48,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            // Content section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (article.description != null && article.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      article.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (article.sourceName != null) ...[
                        Icon(
                          Icons.source_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          article.sourceName!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (article.publishedAt != null) ...[
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(article.publishedAt!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}

/// Shows a bottom sheet with article options (Save to Favorite, Read)
void _showArticleOptions(BuildContext context, WidgetRef ref, Article article) {
  final isFavorited = isArticleFavorited(ref, article);
  
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _ArticleOptionsSheet(
      article: article,
      isFavorited: isFavorited,
      onFavorite: () async {
        try {
          await toggleFavorite(ref, article);
          if (context.mounted) {
            Navigator.of(context).pop();
            // Invalidate favorites list to update the view if currently viewing favorites
            ref.invalidate(newsArticlesProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isFavorited ? 'Removed from favorites' : 'Saved to favorites',
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${e.toString()}'),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      onRead: () async {
        Navigator.of(context).pop();
        final uri = Uri.tryParse(article.url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not open article URL'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
    ),
  );
}

class _ArticleOptionsSheet extends StatelessWidget {
  const _ArticleOptionsSheet({
    required this.article,
    required this.isFavorited,
    required this.onFavorite,
    required this.onRead,
  });

  final Article article;
  final bool isFavorited;
  final VoidCallback onFavorite;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Article preview
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (article.sourceName != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.source_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          article.sourceName!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Divider
            Divider(
              height: 1,
              thickness: 1,
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
            // Options
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _OptionTile(
                    icon: isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    title: isFavorited ? 'Remove from Favorites' : 'Save to Favorites',
                    subtitle: isFavorited
                        ? 'Remove this article from your favorites'
                        : 'Save this article to your favorites',
                    color: isFavorited ? Colors.red : theme.colorScheme.primary,
                    onTap: onFavorite,
                  ),
                  const SizedBox(height: 4),
                  _OptionTile(
                    icon: Icons.open_in_new_rounded,
                    title: 'Read Article',
                    subtitle: 'Open article in your browser',
                    color: theme.colorScheme.primary,
                    onTap: onRead,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.icon,
    this.subtitle,
    this.showRefresh = false,
    this.onRefresh,
  });

  final String message;
  final String? subtitle;
  final IconData icon;
  final bool showRefresh;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: theme.colorScheme.primary.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                message,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (showRefresh && onRefresh != null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}