import 'package:flutter/material.dart';

import '../../../../model/travel_place.dart';

class TravelCategoryFilter extends StatelessWidget {
  const TravelCategoryFilter({
    super.key,
    required this.selectedCategory,
    required this.onChanged,
  });

  final TravelPlaceCategory? selectedCategory;
  final ValueChanged<TravelPlaceCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <_CategoryItem>[
      const _CategoryItem(null, 'Tất cả', Icons.explore_outlined),
      ...TravelPlaceCategory.values.map(
        (category) => _CategoryItem(
          category,
          _labelOf(category),
          _iconOf(category),
        ),
      ),
    ];

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = item.category == selectedCategory;

          return _CategoryChip(
            label: item.label,
            icon: item.icon,
            selected: selected,
            onTap: () => onChanged(item.category),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: items.length,
      ),
    );
  }

  static String _labelOf(TravelPlaceCategory category) {
    return switch (category) {
      TravelPlaceCategory.beach => 'Biển đảo',
      TravelPlaceCategory.mountain => 'Núi rừng',
      TravelPlaceCategory.culture => 'Văn hóa',
      TravelPlaceCategory.food => 'Ẩm thực',
      TravelPlaceCategory.entertainment => 'Giải trí',
      TravelPlaceCategory.shopping => 'Mua sắm',
      TravelPlaceCategory.nature => 'Thiên nhiên',
      TravelPlaceCategory.other => 'Khác',
    };
  }

  static IconData _iconOf(TravelPlaceCategory category) {
    return switch (category) {
      TravelPlaceCategory.beach => Icons.beach_access_outlined,
      TravelPlaceCategory.mountain => Icons.landscape_outlined,
      TravelPlaceCategory.culture => Icons.temple_buddhist_outlined,
      TravelPlaceCategory.food => Icons.restaurant_outlined,
      TravelPlaceCategory.entertainment => Icons.attractions_outlined,
      TravelPlaceCategory.shopping => Icons.local_mall_outlined,
      TravelPlaceCategory.nature => Icons.park_outlined,
      TravelPlaceCategory.other => Icons.place_outlined,
    };
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? colors.onPrimary : colors.primary,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? colors.onPrimary : colors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryItem {
  const _CategoryItem(this.category, this.label, this.icon);

  final TravelPlaceCategory? category;
  final String label;
  final IconData icon;
}