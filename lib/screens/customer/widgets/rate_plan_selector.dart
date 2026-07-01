import 'package:flutter/material.dart';

import '../../../model/pricing_quote.dart';
import '../../../model/room_rate_plan.dart';

class CustomerRatePlanSelector extends StatelessWidget {
  const CustomerRatePlanSelector({
    super.key,
    required this.hourlyQuote,
    required this.plans,
    required this.comboQuotes,
    required this.selectedPlanId,
    required this.onSelected,
  });

  final PricingQuote hourlyQuote;
  final List<RoomRatePlan> plans;

  /// Key là RoomRatePlan.id.
  final Map<String, PricingQuote> comboQuotes;

  /// Null nghĩa là khách chọn tính giá theo giờ.
  final String? selectedPlanId;

  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final eligiblePlans = plans.where((plan) {
      return plan.enabled && comboQuotes.containsKey(plan.id);
    }).toList();

    final allAmounts = <double>[
      hourlyQuote.totalAmount,
      ...eligiblePlans.map(
        (plan) => comboQuotes[plan.id]!.totalAmount,
      ),
    ];

    final lowestAmount = allAmounts.reduce(
      (first, second) => first < second ? first : second,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chọn phương án giá',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Giá đã bao gồm phụ thu theo thời gian đã chọn.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _RateOption(
          title: 'Tính giá theo giờ',
          subtitle:
              '${hourlyQuote.durationLabel} · '
              'giờ đầu và các giờ tiếp theo',
          amount: hourlyQuote.totalAmount,
          hourlyAmount: hourlyQuote.totalAmount,
          recommended:
              hourlyQuote.totalAmount == lowestAmount,
          selected: selectedPlanId == null,
          onTap: () => onSelected(null),
        ),
        ...eligiblePlans.map((plan) {
          final quote = comboQuotes[plan.id]!;

          return Padding(
            padding: const EdgeInsets.only(top: 9),
            child: _RateOption(
              title: plan.name,
              subtitle:
                  '${plan.timeLabel} · '
                  '${plan.durationHours} giờ',
              amount: quote.totalAmount,
              hourlyAmount: hourlyQuote.totalAmount,
              recommended: quote.totalAmount == lowestAmount,
              selected: selectedPlanId == plan.id,
              onTap: () => onSelected(plan.id),
            ),
          );
        }),
        if (eligiblePlans.isEmpty) ...[
          const SizedBox(height: 9),
          Text(
            'Không có combo phù hợp với khung giờ đã chọn.',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _RateOption extends StatelessWidget {
  const _RateOption({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.hourlyAmount,
    required this.recommended,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final double amount;
  final double hourlyAmount;
  final bool recommended;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final saving = hourlyAmount - amount;

    return Material(
      color: selected
          ? colors.primaryContainer
          : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected
              ? colors.primary
              : colors.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (recommended)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.tertiaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              child: Text(
                                'Tốt nhất',
                                style: TextStyle(
                                  color: colors.onTertiaryContainer,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    if (saving > 0) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Tiết kiệm ${_money(saving)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _money(amount),
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 16,
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

String _money(double value) {
  final raw = value.round().toString();

  return '${raw.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  )}đ';
}