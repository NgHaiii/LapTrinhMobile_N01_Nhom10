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
      const _CategoryItem(
        TravelPlaceCategory.beach,
        'Biển đảo',
        Icons.beach_access_outlined,
      ),
      const _CategoryItem(
        TravelPlaceCategory.mountain,
        'Núi rừng',
        Icons.landscape_outlined,
      ),
      const _CategoryItem(
        TravelPlaceCategory.culture,
        'Văn hóa',
        Icons.temple_buddhist_outlined,
      ),
      const _CategoryItem(
        TravelPlaceCategory.nature,
        'Thiên nhiên',
        Icons.park_outlined,
      ),
      const _CategoryItem(
        TravelPlaceCategory.food,
        'Ẩm thực',
        Icons.restaurant_outlined,
      ),
      const _CategoryItem(
        TravelPlaceCategory.entertainment,
        'Vui chơi',
        Icons.attractions_outlined,
      ),
    ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
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
      ),
    );
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

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [
                      Color(0xFF087F8C),
                      Color(0xFF17BEBB),
                    ],
                  )
                : null,
            color: selected ? null : colors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.transparent : colors.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? const Color(0xFF087F8C).withValues(alpha: 0.24)
                    : Colors.black.withValues(alpha: 0.035),
                blurRadius: selected ? 18 : 10,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_rounded : icon,
                size: 17,
                color: selected ? Colors.white : colors.primary,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : colors.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
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