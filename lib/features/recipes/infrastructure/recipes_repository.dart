import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/recipe_models.dart';

abstract class RecipesRepository {
  Future<List<Recipe>> fetchRecipes({
    String? search,
    RecipePurpose? purpose,
    Set<DietaryFilter> dietaryFilters,
    int limit,
    int offset,
    Set<String>? onlyIds,
  });
  Future<Recipe?> fetchRecipeById(String id);
  Future<Set<String>> fetchSavedRecipeIds(String userId);
  Future<bool> toggleSaved(String userId, String recipeId);
  Future<List<Recipe>> fetchFavoriteRecipes({required String userId, String? search, int limit, int offset});
}

class SupabaseRecipesRepository implements RecipesRepository {
  final SupabaseClient _client;
  SupabaseRecipesRepository({SupabaseClient? client}) : _client = client ?? supabase;

  @override
  Future<List<Recipe>> fetchRecipes({
    String? search,
    RecipePurpose? purpose,
    Set<DietaryFilter> dietaryFilters = const {},
    int limit = 50,
    int offset = 0,
    Set<String>? onlyIds,
  }) async {
    if (onlyIds != null && onlyIds.isEmpty) {
      return <Recipe>[];
    }
    dynamic qb = _client.from('recipes').select('id, title, purpose, calories, macros, ingredients, instructions, img_url');
    if (onlyIds != null && onlyIds.isNotEmpty) qb = qb.in_('id', onlyIds.toList());
    if (purpose != null) qb = qb.eq('purpose', purpose.apiValue);
    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim();
      qb = qb.or('title.ilike.%$term%,instructions.ilike.%$term%');
    }

    // Apply server-side dietary flags (AND semantics)
    if (dietaryFilters.isNotEmpty) {
      if (dietaryFilters.contains(DietaryFilter.vegan)) qb = qb.eq('is_vegan', true);
      if (dietaryFilters.contains(DietaryFilter.vegetarian)) qb = qb.eq('is_vegetarian', true);
      if (dietaryFilters.contains(DietaryFilter.glutenFree)) qb = qb.eq('is_gluten_free', true);
      if (dietaryFilters.contains(DietaryFilter.dairyFree)) qb = qb.eq('is_dairy_free', true);
      if (dietaryFilters.contains(DietaryFilter.nutFree)) qb = qb.eq('is_nut_free', true);
    }

    qb = qb.order('title');
    if (limit > 0) qb = qb.range(offset, offset + limit - 1);
    try {
      final rows = await qb;
      final List data = rows as List;
      return data.whereType<Map<String, dynamic>>().map(Recipe.fromMap).toList();
    } catch (_) {
      // Fallback for some environments where in_ on uuid may fail encoding
      if (onlyIds != null && onlyIds.isNotEmpty) {
        final orExpr = onlyIds.map((id) => 'id.eq.$id').join(',');
        final alt = await _client
            .from('recipes')
            .select('id, title, purpose, calories, macros, ingredients, instructions, img_url')
            .or(orExpr)
            .order('title')
            .range(offset, offset + limit - 1);
        final List data = alt as List;
        return data.whereType<Map<String, dynamic>>().map(Recipe.fromMap).toList();
      }
      rethrow;
    }
  }

  @override
  Future<List<Recipe>> fetchFavoriteRecipes({required String userId, String? search, int limit = 50, int offset = 0}) async {
    dynamic qb = _client
        .from('recipes')
        .select('id, title, purpose, calories, macros, ingredients, instructions, img_url, user_saved_recipes!inner (user_id)')
        .eq('user_saved_recipes.user_id', userId);
    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim();
      qb = qb.or('title.ilike.%$term%,instructions.ilike.%$term%');
    }
    qb = qb.order('title');
    if (limit > 0) qb = qb.range(offset, offset + limit - 1);
    final rows = await qb;
    final List data = rows as List;
    return data.whereType<Map<String, dynamic>>().map((m) => Recipe.fromMap(m)).toList();
  }

  @override
  Future<Recipe?> fetchRecipeById(String id) async {
    final row = await _client
        .from('recipes')
        .select('id, title, purpose, calories, macros, ingredients, instructions, img_url')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Recipe.fromMap(row);
  }

  @override
  Future<Set<String>> fetchSavedRecipeIds(String userId) async {
    final rows = await _client.from('user_saved_recipes').select('recipe_id').eq('user_id', userId);
    final List data = rows as List;
    return data.map((e) => e['recipe_id'] as String?).whereType<String>().toSet();
  }

  @override
  Future<bool> toggleSaved(String userId, String recipeId) async {
    final exists = await _client
        .from('user_saved_recipes')
        .select('user_id, recipe_id')
        .eq('user_id', userId)
        .eq('recipe_id', recipeId)
        .maybeSingle();
    if (exists != null) {
      await _client.from('user_saved_recipes').delete().eq('user_id', userId).eq('recipe_id', recipeId);
      return false;
    } else {
      await _client.from('user_saved_recipes').upsert({'user_id': userId, 'recipe_id': recipeId});
      return true;
    }
  }
}


