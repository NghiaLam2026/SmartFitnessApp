import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../recipes/application/recipes_providers.dart';
import '../domain/recipe_models.dart';
import 'package:go_router/go_router.dart';

class RecipeLibraryPage extends ConsumerStatefulWidget {
  const RecipeLibraryPage({super.key});

  @override
  ConsumerState<RecipeLibraryPage> createState() => _RecipeLibraryPageState();
}

class _RecipeLibraryPageState extends ConsumerState<RecipeLibraryPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(recipesQueryProvider);
    final listAsync = ref.watch(recipesListProvider);
    final savedIdsAsync = ref.watch(savedRecipeIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search recipes...'
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        ref.read(recipesQueryProvider.notifier).state = query.copyWith(searchTerm: value.trim());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      ref.read(recipesQueryProvider.notifier).state = const RecipesQuery();
                      _searchController.clear();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Reset',
                  ),
                ],
              ),
            ),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _PurposeChip(
                    label: 'All',
                    selected: query.purpose == null,
                    onSelected: () => ref.read(recipesQueryProvider.notifier).state = query.copyWith(purpose: null),
                  ),
                  const SizedBox(width: 8),
                  for (final p in RecipePurpose.values) ...[
                    _PurposeChip(
                      label: p.label,
                      selected: query.purpose == p,
                      onSelected: () => ref.read(recipesQueryProvider.notifier).state = query.copyWith(purpose: p),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: -8,
                children: [
                  for (final f in DietaryFilter.values)
                    FilterChip(
                      label: Text(_dietaryLabel(f)),
                      selected: query.dietaryFilters.contains(f),
                      onSelected: (sel) {
                        final newSet = Set<DietaryFilter>.from(query.dietaryFilters);
                        if (sel) {
                          newSet.add(f);
                        } else {
                          newSet.remove(f);
                        }
                        ref.read(recipesQueryProvider.notifier).state = query.copyWith(dietaryFilters: newSet);
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: listAsync.when(
                data: (recipes) {
                  final saved = savedIdsAsync.maybeWhen(data: (s) => s, orElse: () => <String>{});
                  if (recipes.isEmpty) {
                    return _EmptyOrError(
                      title: 'No recipes found',
                      subtitle: query.searchTerm.isNotEmpty || query.purpose != null || query.dietaryFilters.isNotEmpty
                          ? 'We found no exact matches. Here are some suggestions:'
                          : 'Try adjusting your filters or search.',
                      showSuggestions: true,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemBuilder: (_, i) {
                      final r = recipes[i];
                      final isSaved = saved.contains(r.id);
                      return _RecipeCard(
                        recipe: r,
                        saved: isSaved,
                        onTap: () => context.push('/home/recipes/detail', extra: r.id),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: recipes.length,
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => const _EmptyOrError(
                  title: 'Unable to load recipes',
                  subtitle: 'Please try again later.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dietaryLabel(DietaryFilter f) {
    switch (f) {
      case DietaryFilter.vegan:
        return 'Vegan';
      case DietaryFilter.vegetarian:
        return 'Vegetarian';
      case DietaryFilter.glutenFree:
        return 'Gluten-free';
      case DietaryFilter.dairyFree:
        return 'Dairy-free';
      case DietaryFilter.nutFree:
        return 'Nut-free';
    }
  }
}

class _PurposeChip extends StatelessWidget {
  const _PurposeChip({required this.label, required this.selected, required this.onSelected});
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, required this.saved, required this.onTap});
  final Recipe recipe;
  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recipe.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (saved) const Icon(Icons.bookmark_rounded, color: Colors.amber)
                ],
              ),
              const SizedBox(height: 4),
              Text(
                recipe.purpose.label,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(recipe.calories != null ? '${recipe.calories!.toStringAsFixed(recipe.calories! % 1 == 0 ? 0 : 0)} kcal' : '— kcal'),
                  const SizedBox(width: 12),
                  const Icon(Icons.restaurant_menu_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text('${recipe.ingredients.length} ingredients'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyOrError extends StatelessWidget {
  const _EmptyOrError({required this.title, required this.subtitle, this.showSuggestions = false});
  final String title;
  final String subtitle;
  final bool showSuggestions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_rounded, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
            if (showSuggestions) ...[
              const SizedBox(height: 12),
              Text('Showing similar recipes', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
            ],
          ],
        ),
      ),
    );
  }
}


