import 'package:flutter/material.dart';

import '../../../model/hotel_rating.dart';

class CustomerRatingSummary extends StatelessWidget {
  const CustomerRatingSummary({
    super.key,
    required this.averageRating,
    required this.reviewCount,
    required this.ratingDistribution,
    this.reviewedRoomCount,
  });

  factory CustomerRatingSummary.hotel({
    Key? key,
    required HotelRating rating,
  }) {
    return CustomerRatingSummary(
      key: key,
      averageRating: rating.averageRating,
      reviewCount: rating.reviewCount,
      ratingDistribution: rating.ratingDistribution,
      reviewedRoomCount: rating.reviewedRoomCount,
    );
  }

  factory CustomerRatingSummary.room({
    Key? key,
    required RoomRating rating,
  }) {
    return CustomerRatingSummary(
      key: key,
      averageRating: rating.averageRating,
      reviewCount: rating.reviewCount,
      ratingDistribution: rating.ratingDistribution,
    );
  }

  final double averageRating;
  final int reviewCount;
  final int? reviewedRoomCount;
  final Map<int, int> ratingDistribution;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (reviewCount == 0) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.star_border_rounded, size: 30),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Phòng chưa có đánh giá từ khách hàng.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final positiveCount =
        (ratingDistribution[4] ?? 0) +
        (ratingDistribution[5] ?? 0);

    final positivePercent =
        (positiveCount / reviewCount * 100).round();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 105,
                  child: Column(
                    children: [
                      Text(
                        averageRating.toStringAsFixed(1),
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      _Stars(
                        rating: averageRating,
                        size: 17,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$reviewCount lượt đánh giá',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      for (var star = 5; star >= 1; star--)
                        _RatingBar(
                          star: star,
                          count:
                              ratingDistribution[star] ?? 0,
                          total: reviewCount,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _InfoChip(
                  icon: Icons.thumb_up_alt_outlined,
                  label:
                      '$positivePercent% đánh giá tích cực',
                ),
                if (reviewedRoomCount != null)
                  _InfoChip(
                    icon: Icons.bed_outlined,
                    label:
                        '$reviewedRoomCount phòng đã được đánh giá',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({
    required this.star,
    required this.count,
    required this.total,
  });

  final int star;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : count / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 15,
            child: Text(
              '$star',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(
            Icons.star_rounded,
            size: 14,
            color: Colors.amber,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: LinearProgressIndicator(
              value: value,
              minHeight: 7,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 24,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({
    required this.rating,
    required this.size,
  });

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final position = index + 1;

        final icon = rating >= position
            ? Icons.star_rounded
            : rating >= position - 0.5
                ? Icons.star_half_rounded
                : Icons.star_border_rounded;

        return Icon(
          icon,
          size: size,
          color: Colors.amber.shade700,
        );
      }),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 7,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.primary),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}