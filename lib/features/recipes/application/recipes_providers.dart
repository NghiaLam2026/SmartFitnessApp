import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
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
  final bool favoritesOnly;
  final Set<DietaryFilter> dietaryFilters;
  final int limit;
  final int offset;

  const RecipesQuery({
    this.searchTerm = '',
    this.purpose,
    this.favoritesOnly = false,
    this.dietaryFilters = const {},
    this.limit = 50,
    this.offset = 0,
  });

  RecipesQuery copyWith({
    String? searchTerm,
    RecipePurpose? purpose,
    bool clearPurpose = false,
    bool? favoritesOnly,
    Set<DietaryFilter>? dietaryFilters,
    int? limit,
    int? offset,
  }) {
    return RecipesQuery(
      searchTerm: searchTerm ?? this.searchTerm,
      purpose: clearPurpose ? null : (purpose ?? this.purpose),
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      dietaryFilters: dietaryFilters ?? this.dietaryFilters,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }
}

final recipesQueryProvider = StateProvider<RecipesQuery>((ref) => const RecipesQuery());

final recipesListProvider = FutureProvider.autoDispose<List<Recipe>>((ref) async {
  final repo = ref.watch(recipesRepositoryProvider);
  final q = ref.watch(recipesQueryProvider);
  await ref.watch(savedRecipeIdsProvider.future);

  if (q.favoritesOnly) {
    final user = supabase.auth.currentUser;
    if (user == null) return <Recipe>[];
    final results = await repo.fetchFavoriteRecipes(
      userId: user.id,
      search: q.searchTerm.isNotEmpty ? q.searchTerm : null,
      limit: q.limit,
      offset: q.offset,
    );
    return results;
  }

  final results = await repo.fetchRecipes(
    search: q.searchTerm.isNotEmpty ? q.searchTerm : null,
    purpose: q.purpose,
    dietaryFilters: q.dietaryFilters,
    limit: q.limit,
    offset: q.offset,
  );
  return results;
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

final toggleSavedRecipeProvider = FutureProvider.family.autoDispose<bool, String>((ref, recipeId) async {
  final user = supabase.auth.currentUser;
  if (user == null) throw const AuthException('Not logged in');
  final repo = ref.read(recipesRepositoryProvider);
  final result = await repo.toggleSaved(user.id, recipeId);
  // refresh saved set
  ref.invalidate(savedRecipeIdsProvider);
  return result;
});


