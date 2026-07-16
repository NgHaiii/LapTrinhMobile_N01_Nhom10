import 'package:flutter/material.dart';

import '../../../model/hotel.dart';
import '../../../model/hotel_rating.dart';
import '../../../services/recommendation_service.dart';
import 'hotel_card.dart';

class RecommendedHotelsSection extends StatefulWidget {
  const RecommendedHotelsSection({
    super.key,
    required this.service,
    required this.onHotelTap,
    this.province = '',
    this.district = '',
    this.limit = 3,
  });

  final RecommendationService service;
  final ValueChanged<HotelModel> onHotelTap;
  final String province;
  final String district;
  final int limit;

  @override
  State<RecommendedHotelsSection> createState() =>
      _RecommendedHotelsSectionState();
}

class _RecommendedHotelsSectionState
    extends State<RecommendedHotelsSection> {
  late Stream<List<HotelRecommendation>> _recommendationsStream;

  @override
  void initState() {
    super.initState();
    _recommendationsStream = _createStream();
  }

  @override
  void didUpdateWidget(covariant RecommendedHotelsSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.service != widget.service ||
        oldWidget.province != widget.province ||
        oldWidget.district != widget.district ||
        oldWidget.limit != widget.limit) {
      _recommendationsStream = _createStream();
    }
  }

  Stream<List<HotelRecommendation>> _createStream() {
    return widget.service.watchRecommendedHotels(
      province: widget.province,
      district: widget.district,
      limit: widget.limit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HotelRecommendation>>(
      stream: _recommendationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final recommendations = snapshot.data ?? [];

        if (recommendations.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(),
            const SizedBox(height: 12),
            ...recommendations.map(
              (recommendation) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RecommendationInfo(
                      rating: recommendation.rating,
                    ),
                    const SizedBox(height: 7),
                    CustomerHotelCard(
                      hotel: recommendation.hotel,
                      onTap: () => widget.onHotelTap(
                        recommendation.hotel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: const Icon(Icons.auto_awesome_outlined),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đề xuất cho bạn',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(
                'Dựa trên đánh giá thực tế của các phòng.',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecommendationInfo extends StatelessWidget {
  const _RecommendationInfo({
    required this.rating,
  });

  final HotelRating rating;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        _InfoChip(
          icon: Icons.star_rounded,
          label: rating.reviewCount == 0
              ? 'Nơi lưu trú mới'
              : '${rating.averageRating.toStringAsFixed(1)} sao',
        ),
        if (rating.reviewCount > 0)
          _InfoChip(
            icon: Icons.rate_review_outlined,
            label: '${rating.reviewCount} đánh giá',
          ),
        if (rating.reviewedRoomCount > 0)
          _InfoChip(
            icon: Icons.bed_outlined,
            label: '${rating.reviewedRoomCount} phòng',
          ),
        if (rating.positiveRatio >= 0.8)
          _InfoChip(
            icon: Icons.thumb_up_alt_outlined,
            label: 'Được yêu thích',
            color: colors.primary,
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = color ?? colors.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
