import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/news_models.dart';

/// Simple repository that only fetches articles from NewsAPI via backend
abstract class NewsRepository {
  /// Fetch articles from NewsAPI for a given topic
  Future<List<Article>> fetchArticles(NewsTopic topic);
  
  /// Add an article to favorites
  Future<void> addFavorite(String articleUrl);
  
  /// Remove an article from favorites
  Future<void> removeFavorite(String articleUrl);
  
  /// Load all favorited article URLs for the current user
  Future<Set<String>> loadFavorites();
}

class SimpleNewsRepository implements NewsRepository {
  final Dio _dio;
  final String _backendUrl;

  SimpleNewsRepository({
    Dio? dio,
    String? backendUrl,
  })  : _dio = dio ?? Dio(),
        _backendUrl = backendUrl ?? AppConstants.aiWorkoutBackendUrl;

  @override
  Future<List<Article>> fetchArticles(NewsTopic topic) async {
    try {
      final searchQuery = topic.searchQuery;
      if (searchQuery.isEmpty) {
        throw Exception('Invalid topic: search query is empty');
      }

      // Call backend endpoint to fetch from NewsAPI
      final response = await _dio.get(
        '$_backendUrl/fetch-news',
        queryParameters: {
          'topic': searchQuery,
          'topicLabel': topic.label.toLowerCase(),
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final articlesData = data['articles'] as List? ?? [];
        
        if (articlesData.isEmpty && data['error'] != null) {
          throw Exception('NewsAPI error: ${data['error']} - ${data['message'] ?? 'Unknown error'}');
        }
        
        // Convert API response to Article objects
        final List<Article> articles = [];
        for (final articleData in articlesData) {
          try {
            final articleMap = articleData as Map<String, dynamic>;
            final article = Article.fromNewsApi(articleMap, topic.label);
            // Validate article has required fields
            if (article.url.isNotEmpty && article.title.isNotEmpty) {
              articles.add(article);
            }
          } catch (e) {
            print('Error parsing article: $e');
            // Continue with next article
          }
        }

        // Return articles (can be empty if none parsed successfully)
        return articles;
      } else {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage = errorData?['error'] as String? ?? 'Unknown error';
        final detailMessage = errorData?['message'] as String?;
        throw Exception('Failed to fetch news (${response.statusCode}): $errorMessage${detailMessage != null ? ' - $detailMessage' : ''}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) {
        throw Exception('Could not connect to backend. Please ensure the backend is running.');
      }
      if (e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.sendTimeout) {
        throw Exception('Request timed out. Please try again.');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> addFavorite(String articleUrl) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      await supabase.from('article_favorites').insert({
        'user_id': user.id,
        'article_url': articleUrl,
      });
    } on PostgrestException catch (e) {
      // Handle unique constraint violation (already favorited)
      if (e.code == '23505') {
        // Already favorited, ignore
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> removeFavorite(String articleUrl) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    await supabase
        .from('article_favorites')
        .delete()
        .eq('user_id', user.id)
        .eq('article_url', articleUrl);
  }

  @override
  Future<Set<String>> loadFavorites() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return <String>{};
    }

    try {
      final response = await supabase
          .from('article_favorites')
          .select('article_url')
          .eq('user_id', user.id);

      final favorites = <String>{};
      for (final row in response) {
        final url = row['article_url'] as String?;
        if (url != null) {
          favorites.add(url);
        }
      }
      return favorites;
    } catch (e) {
      print('Error loading favorites: $e');
      return <String>{};
    }
  }
}
