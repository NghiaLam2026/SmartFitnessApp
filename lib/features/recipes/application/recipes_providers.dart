import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/recipe_models.dart';
import '../infrastructure/recipes_repository.dart';

final recipesRepositoryProvider = Provider<RecipesRepository>((ref) {
  return SupabaseRecipesRepository();
});

class RecipesQuery {
  final String searchTerm;
  final RecipePurpose? purpose;
  final Set<DietaryFilter> dietaryFilters;
  final int limit;
  final int offset;

  const RecipesQuery({
    this.searchTerm = '',
    this.purpose,
    this.dietaryFilters = const {},
    this.limit = 50,
    this.offset = 0,
  });

  RecipesQuery copyWith({
    String? searchTerm,
    RecipePurpose? purpose,
    Set<DietaryFilter>? dietaryFilters,
    int? limit,
    int? offset,
  }) {
    return RecipesQuery(
      searchTerm: searchTerm ?? this.searchTerm,
      purpose: purpose ?? this.purpose,
      dietaryFilters: dietaryFilters ?? this.dietaryFilters,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }
}

final recipesQueryProvider = StateProvider<RecipesQuery>((ref) => const RecipesQuery());

final recipesListProvider = FutureProvider.autoDispose<List<Recipe>>((ref) async {
  final repo = ref.watch(recipesRepositoryProvider);
  final query = ref.watch(recipesQueryProvider);

  // Fetch from Supabase with server-side filters for purpose and text, then client-side dietary filtering
  final results = await repo.fetchRecipes(
    search: query.searchTerm.isNotEmpty ? query.searchTerm : null,
    purpose: query.purpose,
    limit: query.limit,
    offset: query.offset,
  );

  final filtered = results.where((r) => r.matchesDietary(query.dietaryFilters)).toList();
  if (filtered.isNotEmpty) return filtered;

  // Suggest similar when empty: drop dietary first; then drop search; finally drop purpose
  if (results.isNotEmpty) return results; // already a suggestion by ignoring dietary

  if (query.searchTerm.isNotEmpty || query.purpose != null) {
    final fallback = await repo.fetchRecipes(limit: 12);
    return fallback;
  }

  return <Recipe>[];
});

final savedRecipeIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return <String>{};
  final repo = ref.watch(recipesRepositoryProvider);
  return repo.fetchSavedRecipeIds(user.id);
});

final recipeDetailProvider = FutureProvider.family.autoDispose<Recipe?, String>((ref, recipeId) async {
  final repo = ref.watch(recipesRepositoryProvider);
  return repo.fetchRecipeById(recipeId);
});

final toggleSavedRecipeProvider = FutureProvider.family<bool, String>((ref, recipeId) async {
  final user = supabase.auth.currentUser;
  if (user == null) throw const AuthException('Not logged in');
  final repo = ref.read(recipesRepositoryProvider);
  final result = await repo.toggleSaved(user.id, recipeId);
  // refresh saved set
  ref.invalidate(savedRecipeIdsProvider);
  return result;
});


