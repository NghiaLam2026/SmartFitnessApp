import 'package:flutter/foundation.dart';

/// Represents a health topic for news filtering
/// Focused on fitness app themes: training, nutrition, and wellness
enum NewsTopic {
  fitness,
  nutrition,
  weightLoss,
  muscleBuilding,
}

extension NewsTopicExtension on NewsTopic {
  String get label {
    switch (this) {
      case NewsTopic.fitness:
        return 'Fitness';
      case NewsTopic.nutrition:
        return 'Nutrition';
      case NewsTopic.weightLoss:
        return 'Weight Loss';
      case NewsTopic.muscleBuilding:
        return 'Muscle Building';
    }
  }

  /// Search query for NewsAPI
  String get searchQuery {
    switch (this) {
      case NewsTopic.fitness:
        return 'fitness exercise workout training';
      case NewsTopic.nutrition:
        return 'nutrition diet healthy eating meal prep';
      case NewsTopic.weightLoss:
        return 'weight loss fat loss diet fitness';
      case NewsTopic.muscleBuilding:
        return 'muscle building strength training hypertrophy';
    }
  }
}

/// Represents a news article
@immutable
class Article {
  final String id;
  final String? sourceName;
  final String title;
  final String? description;
  final String url;
  final String? imageUrl;
  final DateTime? publishedAt;
  final List<String> topics;
  final DateTime createdAt;

  const Article({
    required this.id,
    this.sourceName,
    required this.title,
    this.description,
    required this.url,
    this.imageUrl,
    this.publishedAt,
    this.topics = const [],
    required this.createdAt,
  });

  /// Create Article from NewsAPI response
  /// Uses URL hash as ID since we're not storing articles in database
  factory Article.fromNewsApi(Map<String, dynamic> map, String topic) {
    final source = map['source'] as Map<String, dynamic>?;
    final sourceName = source?['name'] as String?;
    final url = (map['url'] as String?) ?? '';
    
    // Use URL hash as ID (simple and unique enough for display purposes)
    final articleId = url.isNotEmpty 
        ? url.hashCode.toString() 
        : DateTime.now().millisecondsSinceEpoch.toString();
    
    return Article(
      id: articleId,
      sourceName: sourceName,
      title: (map['title'] as String?)?.trim() ?? 'Untitled',
      description: (map['description'] as String?)?.trim(),
      url: url,
      imageUrl: (map['urlToImage'] as String?)?.trim(),
      publishedAt: map['publishedAt'] != null
          ? DateTime.tryParse(map['publishedAt'] as String)
          : null,
      topics: [topic],
      createdAt: DateTime.now(),
    );
  }
}