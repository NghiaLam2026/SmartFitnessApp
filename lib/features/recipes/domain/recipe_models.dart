import 'package:flutter/foundation.dart';

@immutable
class IngredientItem {
  final String name;
  final double? quantity;
  final String? unit;

  const IngredientItem({required this.name, this.quantity, this.unit});

  factory IngredientItem.fromMap(Map<String, dynamic> map) {
    final qtyRaw = map['qty'];
    double? qty;
    if (qtyRaw is num) qty = qtyRaw.toDouble();
    if (qtyRaw is String) qty = double.tryParse(qtyRaw);
    return IngredientItem(
      name: (map['name'] as String?)?.trim() ?? 'Unknown',
      quantity: qty,
      unit: (map['unit'] as String?)?.trim(),
    );
  }
}

enum RecipePurpose { bulking, cutting, maintenance }

extension RecipePurposeApi on RecipePurpose {
  String get apiValue {
    switch (this) {
      case RecipePurpose.bulking:
        return 'bulking';
      case RecipePurpose.cutting:
        return 'cutting';
      case RecipePurpose.maintenance:
        return 'maintenance';
    }
  }

  String get label {
    switch (this) {
      case RecipePurpose.bulking:
        return 'Bulking';
      case RecipePurpose.cutting:
        return 'Cutting';
      case RecipePurpose.maintenance:
        return 'Maintenance';
    }
  }

  static RecipePurpose? from(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'bulking':
        return RecipePurpose.bulking;
      case 'cutting':
        return RecipePurpose.cutting;
      case 'maintenance':
        return RecipePurpose.maintenance;
      default:
        return null;
    }
  }
}

@immutable
class RecipeMacros {
  final double? protein;
  final double? carbs;
  final double? fat;

  const RecipeMacros({this.protein, this.carbs, this.fat});

  bool get isComplete => protein != null && carbs != null && fat != null;

  factory RecipeMacros.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const RecipeMacros();
    double? _toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }
    // Accept both lowercase keys and uppercase keys like {"Protein": 39, "Carbs": 61, "Fat": 77}
    final protein = _toDouble(map['protein'] ?? map['Protein']);
    final carbs = _toDouble(map['carbs'] ?? map['Carbs']);
    final fat = _toDouble(map['fat'] ?? map['Fat']);
    return RecipeMacros(protein: protein, carbs: carbs, fat: fat);
  }
}

enum DietaryFilter { vegan, vegetarian, glutenFree, dairyFree, nutFree }

@immutable
class Recipe {
  final String id;
  final String title;
  final RecipePurpose purpose;
  final double? calories;
  final RecipeMacros macros;
  final List<IngredientItem> ingredients;
  final String? instructions;

  const Recipe({
    required this.id,
    required this.title,
    required this.purpose,
    required this.calories,
    required this.macros,
    required this.ingredients,
    required this.instructions,
  });

  bool get hasNutrition => calories != null && macros.isComplete;

  factory Recipe.fromMap(Map<String, dynamic> map) {
    final rawIngredients = map['ingredients'];
    final List<IngredientItem> ing;
    if (rawIngredients is List) {
      ing = rawIngredients
          .whereType<Map<String, dynamic>>()
          .map((e) => IngredientItem.fromMap(e))
          .toList();
    } else {
      ing = const <IngredientItem>[];
    }

    double? cal;
    final calRaw = map['calories'];
    if (calRaw is num) cal = calRaw.toDouble();
    if (calRaw is String) cal = double.tryParse(calRaw);

    return Recipe(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?)?.trim() ?? 'Untitled',
      purpose: RecipePurposeApi.from(map['purpose']) ?? RecipePurpose.maintenance,
      calories: cal,
      macros: RecipeMacros.fromMap(map['macros'] as Map<String, dynamic>?),
      ingredients: ing,
      instructions: (map['instructions'] as String?)?.trim(),
    );
  }

  bool matchesDietary(Set<DietaryFilter> filters) {
    if (filters.isEmpty) return true;
    final names = ingredients.map((e) => e.name.toLowerCase()).toList();
    bool anyContains(List<String> banned) => names.any((n) => banned.any((b) => n.contains(b)));
    for (final f in filters) {
      switch (f) {
        case DietaryFilter.vegan:
          if (anyContains(['chicken','beef','pork','fish','egg','milk','cheese','yogurt','butter','honey'])) return false;
          break;
        case DietaryFilter.vegetarian:
          if (anyContains(['chicken','beef','pork','fish'])) return false;
          break;
        case DietaryFilter.glutenFree:
          if (anyContains(['wheat','barley','rye','malt','pasta','bread','flour'])) return false;
          break;
        case DietaryFilter.dairyFree:
          if (anyContains(['milk','cheese','butter','yogurt','cream','whey'])) return false;
          break;
        case DietaryFilter.nutFree:
          if (anyContains(['almond','peanut','walnut','cashew','pecan','hazelnut','pistachio'])) return false;
          break;
      }
    }
    return true;
  }
}


