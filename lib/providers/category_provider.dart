import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_category.dart';

class CategoryState {
  final List<ScanCategory> categories;
  final int activeIndex;

  const CategoryState({
    required this.categories,
    required this.activeIndex,
  });

  ScanCategory get activeCategory =>
      categories[activeIndex.clamp(0, categories.length - 1)];

  CategoryState copyWith({List<ScanCategory>? categories, int? activeIndex}) {
    return CategoryState(
      categories: categories ?? this.categories,
      activeIndex: activeIndex ?? this.activeIndex,
    );
  }
}

final categoryProvider =
    NotifierProvider<CategoryNotifier, CategoryState>(() {
  return CategoryNotifier();
});

class CategoryNotifier extends Notifier<CategoryState> {
  static const String _categoriesKey = 'scan_categories_v1';
  static const String _activeIndexKey = 'scan_category_index';

  @override
  CategoryState build() {
    _loadState();
    return CategoryState(
      categories: ScanCategory.defaults,
      activeIndex: 0,
    );
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final activeIndex = prefs.getInt(_activeIndexKey) ?? 0;
    final categoriesJson = prefs.getString(_categoriesKey);

    List<ScanCategory> categories = ScanCategory.defaults;
    if (categoriesJson != null) {
      try {
        final list = jsonDecode(categoriesJson) as List;
        final parsed = list
            .map((e) => ScanCategory.fromJson(e as Map<String, dynamic>))
            .toList();
        if (parsed.isNotEmpty) categories = parsed;
      } catch (_) {}
    }

    state = CategoryState(
      categories: categories,
      activeIndex: activeIndex.clamp(0, categories.length - 1),
    );
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_activeIndexKey, state.activeIndex);
    await prefs.setString(
      _categoriesKey,
      jsonEncode(state.categories.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> setActiveIndex(int index) async {
    state = state.copyWith(
      activeIndex: index.clamp(0, state.categories.length - 1),
    );
    await _saveState();
  }

  Future<void> nextCategory() async {
    final newIndex = (state.activeIndex + 1) % state.categories.length;
    await setActiveIndex(newIndex);
  }

  Future<void> prevCategory() async {
    final newIndex =
        (state.activeIndex - 1 + state.categories.length) %
        state.categories.length;
    await setActiveIndex(newIndex);
  }

  Future<void> addCategory(ScanCategory category) async {
    state = state.copyWith(categories: [...state.categories, category]);
    await _saveState();
  }

  Future<void> updateCategory(int index, ScanCategory category) async {
    final cats = List<ScanCategory>.from(state.categories);
    cats[index] = category;
    state = state.copyWith(categories: cats);
    await _saveState();
  }

  /// Appends tags the AI invented during identification to the category's
  /// tag list, skipping ones it already has (case-insensitive).
  Future<void> addTagsToCategory(String categoryId, List<String> newTags) async {
    final cats = List<ScanCategory>.from(state.categories);
    final idx = cats.indexWhere((c) => c.id == categoryId);
    if (idx == -1) return;

    final existing = cats[idx].validTags;
    final seen = existing.map((t) => t.toLowerCase()).toSet();
    final additions = <String>[];
    for (final tag in newTags) {
      final trimmed = tag.trim();
      if (trimmed.isNotEmpty && seen.add(trimmed.toLowerCase())) {
        additions.add(trimmed);
      }
    }
    if (additions.isEmpty) return;

    cats[idx] = cats[idx].copyWith(validTags: [...existing, ...additions]);
    state = state.copyWith(categories: cats);
    await _saveState();
  }

  Future<void> removeCategory(int index) async {
    if (state.categories.length <= 1) return;
    final cats = List<ScanCategory>.from(state.categories);
    cats.removeAt(index);
    final newIndex =
        state.activeIndex >= cats.length
            ? cats.length - 1
            : state.activeIndex;
    state = CategoryState(categories: cats, activeIndex: newIndex);
    await _saveState();
  }

  Future<void> resetToDefaults() async {
    state = CategoryState(
      categories: ScanCategory.defaults,
      activeIndex: 0,
    );
    await _saveState();
  }
}
