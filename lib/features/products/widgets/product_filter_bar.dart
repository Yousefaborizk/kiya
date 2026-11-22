import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart'; // مسار الثيم
import '../providers/product_category_provider.dart';
import '../providers/product_provider.dart';

class ProductFilterBar extends ConsumerWidget {
  const ProductFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langCode = context.locale.languageCode;
    final filter = ref.watch(productFilterProvider);
    final categoriesAsync = ref.watch(productCategoriesListProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // ── Category Filter ──────────────────────────
          categoriesAsync.when(
            data: (categories) => _FilterChip(
              label: 'category'.tr(),
              value: filter.categoryId,
              options: [
                MapEntry('all'.tr(), null),
                ...categories.map(
                  (c) => MapEntry(c.getLocalizedName(langCode), c.id),
                ),
              ],
              onChanged: (value) {
                ref.read(productFilterProvider.notifier).state = value == null
                    ? filter.copyWith(clearCategory: true)
                    : filter.copyWith(categoryId: value);
              },
            ),
            loading: () => const SizedBox(
              width: 150,
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // ── Clear Filters ────────────────────────────
          if (filter.categoryId != null || filter.search != null)
            TextButton.icon(
              onPressed: () {
                ref.read(productFilterProvider.notifier).state =
                    const ProductFilter();
              },
              icon: const Icon(Icons.clear, size: 16),
              label: Text('clear_filters'.tr()),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String? value;
  final List<MapEntry<String, String?>> options;
  final ValueChanged<String?> onChanged;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentLabel = options
        .firstWhere(
          (e) => e.value == value,
          orElse: () => options.first,
        )
        .key;

    return PopupMenuButton<String?>(
      tooltip: label,
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value != null
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value != null ? AppColors.primary : AppColors.borderLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: $currentLabel',
              style: TextStyle(
                color: value != null
                    ? AppColors.primary
                    : AppColors.textPrimaryLight,
                fontSize: 13,
                fontWeight: value != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
      itemBuilder: (context) => options
          .map(
            (e) => PopupMenuItem<String?>(
              value: e.value,
              child: Row(
                children: [
                  if (e.value == value)
                    const Icon(Icons.check, size: 18, color: AppColors.primary)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(e.key),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
