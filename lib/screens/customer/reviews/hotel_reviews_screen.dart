import 'package:flutter/material.dart';

import '../../../model/hotel_rating.dart';
import '../../../model/review.dart';
import '../../../services/review_service.dart';

class HotelReviewsScreen extends StatefulWidget {
  const HotelReviewsScreen({
    super.key,
    required this.service,
    required this.hotelId,
    required this.hotelName,
    this.initialRoomId,
  });

  final ReviewService service;
  final String hotelId;
  final String hotelName;
  final String? initialRoomId;

  @override
  State<HotelReviewsScreen> createState() => _HotelReviewsScreenState();
}

class _HotelReviewsScreenState extends State<HotelReviewsScreen> {
  String? _selectedRoomId;
  int? _selectedRating;

  @override
  void initState() {
    super.initState();
    _selectedRoomId = widget.initialRoomId?.trim();

    if (_selectedRoomId?.isEmpty == true) {
      _selectedRoomId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đánh giá phòng')),
      body: StreamBuilder<List<ReviewModel>>(
        stream: widget.service.watchHotelRoomReviews(
          widget.hotelId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _EmptyReviews(
              icon: Icons.cloud_off_outlined,
              title: 'Không thể tải đánh giá',
              message: _cleanError(snapshot.error),
            );
          }

          final allReviews = snapshot.data ?? [];

          if (allReviews.isEmpty) {
            return const _EmptyReviews(
              icon: Icons.rate_review_outlined,
              title: 'Chưa có đánh giá',
              message:
                  'Các đánh giá phòng đã hoàn thành sẽ xuất hiện tại đây.',
            );
          }

          final hotelRating = HotelRating.calculate(
            hotelId: widget.hotelId,
            reviews: allReviews,
          );

          final rooms = _roomOptions(allReviews);

          final filteredReviews = allReviews.where((review) {
            final matchesRoom = _selectedRoomId == null ||
                review.roomId == _selectedRoomId;

            final matchesRating = _selectedRating == null ||
                review.rating == _selectedRating;

            return matchesRoom && matchesRating;
          }).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _RatingOverview(
                    hotelName: widget.hotelName,
                    rating: hotelRating,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildFilters(
                  context,
                  rooms,
                  allReviews,
                ),
              ),
              if (filteredReviews.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyReviews(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'Không có đánh giá phù hợp',
                    message: 'Hãy thử chọn phòng hoặc mức sao khác.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: filteredReviews.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _ReviewCard(
                        review: filteredReviews[index],
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilters(
    BuildContext context,
    Map<String, String> rooms,
    List<ReviewModel> reviews,
  ) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant),
          bottom: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _selectedRoomId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Lọc theo phòng',
                prefixIcon: Icon(Icons.bed_outlined),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tất cả phòng'),
                ),
                ...rooms.entries.map(
                  (entry) => DropdownMenuItem<String?>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedRoomId = value);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _RatingFilterChip(
                    label: 'Tất cả',
                    count: reviews.length,
                    selected: _selectedRating == null,
                    onSelected: () {
                      setState(() => _selectedRating = null);
                    },
                  ),
                  for (var rating = 5; rating >= 1; rating--)
                    _RatingFilterChip(
                      label: '$rating sao',
                      count: reviews
                          .where((review) => review.rating == rating)
                          .length,
                      selected: _selectedRating == rating,
                      onSelected: () {
                        setState(() => _selectedRating = rating);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingOverview extends StatelessWidget {
  const _RatingOverview({
    required this.hotelName,
    required this.rating,
  });

  final String hotelName;
  final HotelRating rating;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hotelName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          'Điểm tổng hợp từ đánh giá các phòng',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 100,
              child: Column(
                children: [
                  Text(
                    rating.averageRating.toStringAsFixed(1),
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  _StarDisplay(
                    rating: rating.averageRating,
                    size: 18,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${rating.reviewCount} lượt',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
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
                    _DistributionRow(
                      star: star,
                      count: rating.ratingDistribution[star] ?? 0,
                      total: rating.reviewCount,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SummaryChip(
              icon: Icons.bed_outlined,
              text: '${rating.reviewedRoomCount} phòng đã được đánh giá',
            ),
            _SummaryChip(
              icon: Icons.thumb_up_alt_outlined,
              text:
                  '${(rating.positiveRatio * 100).round()}% đánh giá tích cực',
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ReviewModel review;

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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                  _date(review.updatedAt ?? review.createdAt),
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
                _StarDisplay(
                  rating: review.rating.toDouble(),
                  size: 19,
                ),
                const SizedBox(width: 7),
                Text(
                  '${review.rating}/5',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
          ],
        ),
      ),
    );
  }
}

class _StarDisplay extends StatelessWidget {
  const _StarDisplay({
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

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
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
            width: 18,
            child: Text(
              '$star',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(
            Icons.star_rounded,
            size: 15,
            color: Colors.amber,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: LinearProgressIndicator(
              value: value,
              minHeight: 7,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          const SizedBox(width: 7),
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

class _RatingFilterChip extends StatelessWidget {
  const _RatingFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$label · $count'),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
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
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: colors.outlineVariant),
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
              text,
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

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: colors.primary),
            const SizedBox(height: 13),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, String> _roomOptions(
  List<ReviewModel> reviews,
) {
  final result = <String, String>{};

  for (final review in reviews) {
    if (review.roomId.isEmpty) continue;

    final label = [
      if (review.roomNumber.isNotEmpty)
        'Phòng ${review.roomNumber}',
      if (review.roomType.isNotEmpty) review.roomType,
    ].join(' · ');

    result[review.roomId] = label.isEmpty
        ? 'Phòng đã đánh giá'
        : label;
  }

  final entries = result.entries.toList()
    ..sort((first, second) {
      return first.value.compareTo(second.value);
    });

  return Map.fromEntries(entries);
}

String _firstCharacter(String value) {
  final normalized = value.trim();

  if (normalized.isEmpty) return 'K';
  return normalized.substring(0, 1).toUpperCase();
}

String _date(DateTime? value) {
  if (value == null) return '';

  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');

  return '$day/$month/${value.year}';
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}