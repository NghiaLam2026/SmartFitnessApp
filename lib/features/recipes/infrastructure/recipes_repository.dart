import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/recipe_models.dart';

abstract class RecipesRepository {
  Future<List<Recipe>> fetchRecipes({String? search, RecipePurpose? purpose, int limit = 50, int offset = 0});
  Future<Recipe?> fetchRecipeById(String id);
  Future<Set<String>> fetchSavedRecipeIds(String userId);
  Future<bool> toggleSaved(String userId, String recipeId);
  Future<bool> isSaved(String userId, String recipeId);
}

class SupabaseRecipesRepository implements RecipesRepository {
  final SupabaseClient _client;
  SupabaseRecipesRepository({SupabaseClient? client}) : _client = client ?? supabase;

  @override
  Future<List<Recipe>> fetchRecipes({String? search, RecipePurpose? purpose, int limit = 50, int offset = 0}) async {
    // Start with select so that filter methods are available
    var filter = _client
        .from('recipes')
        .select('id, title, purpose, calories, macros, ingredients, instructions');

    if (purpose != null) {
      filter = filter.eq('purpose', purpose.apiValue);
    }
    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim();
      filter = filter.or('title.ilike.%$term%,instructions.ilike.%$term%');
    }

    var transformed = filter.order('title');

    if (limit > 0) {
      final end = (offset + limit - 1);
      transformed = transformed.range(offset, end);
    }

    final rows = await transformed; // throws on error
    final List data = rows as List;
    return data
        .whereType<Map<String, dynamic>>()
        .map((m) => Recipe.fromMap(m))
        .toList();
  }

  @override
  Future<Recipe?> fetchRecipeById(String id) async {
    final result = await _client
        .from('recipes')
        .select('id, title, purpose, calories, macros, ingredients, instructions')
        .eq('id', id)
        .maybeSingle();
    if (result == null) return null;
    return Recipe.fromMap(result);
  }

  @override
  Future<Set<String>> fetchSavedRecipeIds(String userId) async {
    final rows = await _client
        .from('user_saved_recipes')
        .select('recipe_id')
        .eq('user_id', userId);
    final List data = rows as List;
    return data
        .map((e) => (e['recipe_id'] as String?))
        .whereType<String>()
        .toSet();
  }

  @override
  Future<bool> isSaved(String userId, String recipeId) async {
    final row = await _client
        .from('user_saved_recipes')
        .select('user_id, recipe_id')
        .eq('user_id', userId)
        .eq('recipe_id', recipeId)
        .maybeSingle();
    return row != null;
  }

  @override
  Future<bool> toggleSaved(String userId, String recipeId) async {
    final saved = await isSaved(userId, recipeId);
    if (saved) {
      await _client
          .from('user_saved_recipes')
          .delete()
          .eq('user_id', userId)
          .eq('recipe_id', recipeId);
      return false;
    } else {
      await _client
          .from('user_saved_recipes')
          .upsert({'user_id': userId, 'recipe_id': recipeId});
      return true;
    }
  }
}


