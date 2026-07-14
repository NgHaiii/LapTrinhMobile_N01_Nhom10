import 'package:flutter/material.dart';

import '../../../../model/voucher.dart';

class VoucherFilterBar extends StatelessWidget {
  const VoucherFilterBar({
    super.key,
    required this.selectedTarget,
    required this.onChanged,
  });

  final VoucherTarget? selectedTarget;
  final ValueChanged<VoucherTarget?> onChanged;

  @override
  Widget build(BuildContext context) {
    final filters = <_VoucherFilterItem>[
      const _VoucherFilterItem(
        label: 'Tất cả',
        icon: Icons.grid_view_rounded,
        target: null,
      ),
      const _VoucherFilterItem(
        label: 'Đặt phòng',
        icon: Icons.hotel_outlined,
        target: VoucherTarget.booking,
      ),
      const _VoucherFilterItem(
        label: 'Du lịch',
        icon: Icons.explore_outlined,
        target: VoucherTarget.travelActivity,
      ),
      const _VoucherFilterItem(
        label: 'Áp dụng tất cả',
        icon: Icons.auto_awesome_outlined,
        target: VoucherTarget.all,
      ),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = filters[index];

          return _FilterChip(
            label: item.label,
            icon: item.icon,
            selected: selectedTarget == item.target,
            onTap: () => onChanged(item.target),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.2),
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
              size: 16,
              color: selected ? colors.onPrimary : colors.primary,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? colors.onPrimary : colors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoucherFilterItem {
  const _VoucherFilterItem({
    required this.label,
    required this.icon,
    required this.target,
  });

  final String label;
  final IconData icon;
  final VoucherTarget? target;
}