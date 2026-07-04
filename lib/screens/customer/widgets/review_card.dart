import 'package:flutter/material.dart';

import '../../../model/review.dart';

class CustomerReviewCard extends StatelessWidget {
  const CustomerReviewCard({
    super.key,
    required this.review,
    this.showHotelName = false,
    this.footer,
  });

  final ReviewModel review;
  final bool showHotelName;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  child: Text(
                    _firstCharacter(review.customerName),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (showHotelName)
                        Text(
                          review.hotelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      Text(
                        '${review.roomType} · '
                        'Phòng ${review.roomNumber}',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _date(
                    review.updatedAt ?? review.createdAt,
                  ),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                _ReviewStars(rating: review.rating),
                const SizedBox(width: 7),
                Text(
                  '${review.rating}/5',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                if (!review.isPublished)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      child: Text(
                        'Đã ẩn',
                        style: TextStyle(
                          color: colors.onErrorContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: const TextStyle(height: 1.45),
            ),
            if (review.hasProviderReply) ...[
              const SizedBox(height: 13),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 19,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 7),
                          const Text(
                            'Phản hồi từ nhà cung cấp',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          if (review.repliedAt != null)
                            Text(
                              _date(review.repliedAt),
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        review.providerReply,
                        style: const TextStyle(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (footer != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewStars extends StatelessWidget {
  const _ReviewStars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating
              ? Icons.star_rounded
              : Icons.star_border_rounded,
          size: 19,
          color: Colors.amber.shade700,
        );
      }),
    );
  }
}

String _firstCharacter(String value) {
  final result = value.trim();

  if (result.isEmpty) return 'K';
  return result.substring(0, 1).toUpperCase();
}

String _date(DateTime? value) {
  if (value == null) return '';

  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');

  return '$day/$month/${value.year}';
}