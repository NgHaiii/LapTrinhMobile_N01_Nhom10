import 'package:flutter/material.dart';

import '../../../../model/travel_suggestion.dart';

class TravelSuggestionChip extends StatelessWidget {
  const TravelSuggestionChip({
    super.key,
    required this.suggestion,
    this.onTap,
  });

  final TravelSuggestionModel suggestion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 245,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _SuggestionImage(suggestion: suggestion),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _iconOf(suggestion.type),
                        size: 14,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _labelOf(suggestion.type),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    suggestion.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 14,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    suggestion.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (suggestion.durationText.isNotEmpty ||
                      suggestion.estimatedCost > 0) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (suggestion.durationText.isNotEmpty)
                          _MiniBadge(
                            icon: Icons.schedule_outlined,
                            text: suggestion.durationText,
                          ),
                        if (suggestion.estimatedCost > 0)
                          _MiniBadge(
                            icon: Icons.payments_outlined,
                            text: _formatMoney(suggestion.estimatedCost),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _labelOf(TravelSuggestionType type) {
    return switch (type) {
      TravelSuggestionType.place => 'Địa điểm',
      TravelSuggestionType.itinerary => 'Lịch trình',
      TravelSuggestionType.hotel => 'Lưu trú',
      TravelSuggestionType.food => 'Ẩm thực',
      TravelSuggestionType.activity => 'Hoạt động',
    };
  }

  static IconData _iconOf(TravelSuggestionType type) {
    return switch (type) {
      TravelSuggestionType.place => Icons.place_outlined,
      TravelSuggestionType.itinerary => Icons.route_outlined,
      TravelSuggestionType.hotel => Icons.hotel_outlined,
      TravelSuggestionType.food => Icons.restaurant_outlined,
      TravelSuggestionType.activity => Icons.local_activity_outlined,
    };
  }

  static String _formatMoney(num value) {
    if (value <= 0) return 'Miễn phí';

    final rounded = value.round();
    final text = rounded.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]}.',
        );

    return '$textđ';
  }
}

class _SuggestionImage extends StatelessWidget {
  const _SuggestionImage({required this.suggestion});

  final TravelSuggestionModel suggestion;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox.square(
        dimension: 78,
        child: suggestion.imageUrl.isEmpty
            ? ColoredBox(
                color: colors.primaryContainer,
                child: Icon(
                  TravelSuggestionChip._iconOf(suggestion.type),
                  color: colors.onPrimaryContainer,
                  size: 34,
                ),
              )
            : Image.network(
                suggestion.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return ColoredBox(
                    color: colors.primaryContainer,
                    child: Icon(
                      TravelSuggestionChip._iconOf(suggestion.type),
                      color: colors.onPrimaryContainer,
                      size: 34,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: colors.onPrimaryContainer),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}