import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/news_models.dart';
import '../infrastructure/news_repository.dart';

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return SimpleNewsRepository();
});

/// Provider for the currently selected news topic
/// null = no topic selected, special value for favorites view
final selectedNewsTopicProvider = StateProvider<NewsTopic?>((ref) => null);

/// Provider to track if we're viewing favorites
final viewingFavoritesProvider = StateProvider<bool>((ref) => false);

/// Cache provider that stores articles by topic
/// Key: topic enum value name, Value: list of articles
final newsArticlesCacheProvider = StateProvider<Map<String, List<Article>>>((ref) => {});

/// Provider to track if we should force refresh (bypass cache)
final forceRefreshProvider = StateProvider<bool>((ref) => false);

/// Provider for favorited articles - filters cached articles by favorite URLs
final favoriteArticlesListProvider = Provider.autoDispose<List<Article>>((ref) {
  final favorites = ref.watch(favoriteArticlesProvider);
  final cache = ref.watch(newsArticlesCacheProvider);
  
  if (favorites.isEmpty) return [];
  
  // Collect all articles from cache and filter by favorite URLs
  final allCachedArticles = <Article>[];
  for (final articles in cache.values) {
    allCachedArticles.addAll(articles);
  }
  
  // Filter to only favorited articles
  return allCachedArticles.where((article) => favorites.contains(article.url)).toList();
});

/// Provider for articles - checks cache first, only fetches from API if not cached or forced refresh
/// Also handles favorites view
final newsArticlesProvider = FutureProvider.autoDispose<List<Article>>((ref) async {
  final viewingFavorites = ref.watch(viewingFavoritesProvider);
  
  // If viewing favorites, return favorited articles
  if (viewingFavorites) {
    return ref.read(favoriteArticlesListProvider);
  }
  
  final selectedTopic = ref.watch(selectedNewsTopicProvider);
  if (selectedTopic == null) return [];

  final cache = ref.watch(newsArticlesCacheProvider);
  // Use read() instead of watch() to prevent rebuild loops
  final forceRefresh = ref.read(forceRefreshProvider);
  final topicKey = selectedTopic.name; // Use enum name as cache key

  // Check cache first (unless forcing refresh)
  if (!forceRefresh && cache.containsKey(topicKey) && cache[topicKey]!.isNotEmpty) {
    return cache[topicKey]!;
  }

  // Reset force refresh flag AFTER the provider build phase to avoid Riverpod assertion
  // Use microtask to defer the state change
  if (forceRefresh) {
    Future.microtask(() {
      ref.read(forceRefreshProvider.notifier).state = false;
    });
  }

  // Fetch from API
  try {
    final repo = ref.watch(newsRepositoryProvider);
    final articles = await repo.fetchArticles(selectedTopic);

    // Store in cache
    final updatedCache = Map<String, List<Article>>.from(cache);
    updatedCache[topicKey] = articles;
    ref.read(newsArticlesCacheProvider.notifier).state = updatedCache;

    return articles;
  } catch (e) {
    // If fetch fails and we have cached data, return cached data
    if (cache.containsKey(topicKey) && cache[topicKey]!.isNotEmpty) {
      return cache[topicKey]!;
    }
    // Otherwise rethrow the error
    rethrow;
  }
});

/// Provider for favorite article IDs (stored by article URL for uniqueness)
/// Loads from database on initialization
final favoriteArticlesProvider = StateNotifierProvider<FavoriteArticlesNotifier, Set<String>>((ref) {
  return FavoriteArticlesNotifier(ref);
});

class FavoriteArticlesNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;
  bool _initialized = false;

  FavoriteArticlesNotifier(this._ref) : super(<String>{}) {
    // Load favorites asynchronously without blocking
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    if (_initialized) return;
    _initialized = true;
    
    try {
      final repo = _ref.read(newsRepositoryProvider);
      final favorites = await repo.loadFavorites();
      if (mounted) {
        state = favorites;
      }
    } catch (e) {
      print('Error loading favorites: $e');
      // Keep empty set on error
    }
  }

  Future<void> toggleFavorite(Article article) async {
    final repo = _ref.read(newsRepositoryProvider);
    final isFavorited = state.contains(article.url);
    
    try {
      if (isFavorited) {
        await repo.removeFavorite(article.url);
        final updated = Set<String>.from(state);
        updated.remove(article.url);
        state = updated;
      } else {
        await repo.addFavorite(article.url);
        final updated = Set<String>.from(state);
        updated.add(article.url);
        state = updated;
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      rethrow;
    }
  }
}

/// Toggle favorite status for an article
Future<void> toggleFavorite(WidgetRef ref, Article article) async {
  await ref.read(favoriteArticlesProvider.notifier).toggleFavorite(article);
}

/// Check if an article is favorited
bool isArticleFavorited(WidgetRef ref, Article article) {
  try {
    final favorites = ref.read(favoriteArticlesProvider);
    return favorites.contains(article.url);
  } catch (e) {
    // Handle type mismatch during hot reload - return false as safe default
    print('Error checking favorite status: $e');
    return false;
  }
}
