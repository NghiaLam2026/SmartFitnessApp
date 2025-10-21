import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../recipes/application/recipes_providers.dart';
import '../domain/recipe_models.dart';

class RecipeDetailPage extends ConsumerWidget {
  const RecipeDetailPage({super.key, required this.recipeId});
  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(recipeDetailProvider(recipeId));
    final savedIdsAsync = ref.watch(savedRecipeIdsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recipe')),
      body: recipeAsync.when(
        data: (recipe) {
          if (recipe == null) return const _FallbackError();
          final saved = savedIdsAsync.maybeWhen(data: (s) => s.contains(recipe.id), orElse: () => false);
          return _RecipeDetailBody(recipe: recipe, saved: saved);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _FallbackError(),
      ),
      floatingActionButton: recipeAsync.maybeWhen(
        data: (recipe) {
          if (recipe == null) return const SizedBox.shrink();
          final isSaved = savedIdsAsync.maybeWhen(data: (s) => s.contains(recipe.id), orElse: () => false);
          return FloatingActionButton.extended(
            onPressed: () async {
              // Re-evaluate saved state at click time to avoid stale closures
              final nowSaved = await ref.read(toggleSavedRecipeProvider(recipe.id).future);
              // Ensure UI updates immediately
              ref.invalidate(savedRecipeIdsProvider);
              ref.invalidate(recipesListProvider);
              // Force rebuild of this FAB state by refreshing recipeAsync
              ref.invalidate(recipeDetailProvider(recipe.id));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(nowSaved ? 'Saved to favorites' : 'Removed from favorites')),
                );
              }
            },
            icon: Icon(
              ref.watch(savedRecipeIdsProvider).maybeWhen(
                    data: (s) => s.contains(recipe.id),
                    orElse: () => isSaved,
                  )
                  ? Icons.bookmark_remove_rounded
                  : Icons.bookmark_add_rounded,
            ),
            label: Text(
              ref.watch(savedRecipeIdsProvider).maybeWhen(
                    data: (s) => s.contains(recipe.id),
                    orElse: () => isSaved,
                  )
                  ? 'Unsave'
                  : 'Save',
            ),
          );
        },
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _RecipeDetailBody extends StatelessWidget {
  const _RecipeDetailBody({required this.recipe, required this.saved});
  final Recipe recipe;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Chip(label: Text(recipe.purpose.label)),
                        const SizedBox(width: 8),
                        if (!recipe.hasNutrition)
                          Chip(label: const Text('Incomplete nutrition'), avatar: const Icon(Icons.info_outline_rounded, size: 18)),
                      ],
                    ),
                  ],
                ),
              ),
              if (saved) const Icon(Icons.bookmark_rounded, color: Colors.amber)
            ],
          ),

          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded),
                  const SizedBox(width: 8),
                  Text(recipe.calories != null ? '${recipe.calories!.toStringAsFixed(recipe.calories! % 1 == 0 ? 0 : 0)} kcal' : '— kcal'),
                  const Spacer(),
                  _MacroBadge(label: 'P', value: recipe.macros.protein),
                  const SizedBox(width: 8),
                  _MacroBadge(label: 'C', value: recipe.macros.carbs),
                  const SizedBox(width: 8),
                  _MacroBadge(label: 'F', value: recipe.macros.fat),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text('Ingredients', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final ing in recipe.ingredients)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_ingredientLine(ing))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text('Instructions', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text((recipe.instructions?.isNotEmpty == true) ? recipe.instructions! : 'No instructions available.'),
            ),
          ),
        ],
      ),
    );
  }

  String _ingredientLine(IngredientItem ing) {
    final qty = ing.quantity != null ? ing.quantity!.toStringAsFixed(ing.quantity! % 1 == 0 ? 0 : 1) : '';
    final unit = (ing.unit != null && ing.unit!.isNotEmpty) ? ' ${ing.unit}' : '';
    final prefix = qty.isNotEmpty ? '$qty$unit • ' : '';
    return '$prefix${ing.name}';
  }
}

class _MacroBadge extends StatelessWidget {
  const _MacroBadge({required this.label, required this.value});
  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(999)),
      child: Text('$label ${value != null ? value!.toStringAsFixed(value! % 1 == 0 ? 0 : 0) : '—'}g'),
    );
  }
}

class _FallbackError extends StatelessWidget {
  const _FallbackError();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Unable to load recipes, Please try again later.'),
      ),
    );
  }
}


