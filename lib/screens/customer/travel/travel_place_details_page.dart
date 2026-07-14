import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../model/saved_place.dart';
import '../../../model/travel_place.dart';
import '../../../services/saved_place_service.dart';
import '../../../services/travel_place_service.dart';

class TravelPlaceDetailsPage extends StatefulWidget {
  const TravelPlaceDetailsPage({
    super.key,
    required this.place,
    this.service,
    this.savedService,
  });

  final TravelPlaceModel place;
  final TravelPlaceService? service;
  final SavedPlaceService? savedService;

  @override
  State<TravelPlaceDetailsPage> createState() => _TravelPlaceDetailsPageState();
}

class _TravelPlaceDetailsPageState extends State<TravelPlaceDetailsPage> {
  late final TravelPlaceService _service;
  late final SavedPlaceService _savedService;

  int _imageIndex = 0;
  bool _saved = false;
  bool _loadingSaved = true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? TravelPlaceService();
    _savedService = widget.savedService ?? SavedPlaceService();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      setState(() => _loadingSaved = false);
      return;
    }

    final saved = await _savedService.isSaved(
      placeId: widget.place.id,
      type: SavedPlaceType.travelPlace,
    );

    if (!mounted) return;
    setState(() {
      _saved = saved;
      _loadingSaved = false;
    });
  }

  Future<void> _toggleSaved() async {
    try {
      final saved = await _savedService.toggleTravelPlace(widget.place);

      if (!mounted) return;
      setState(() => _saved = saved);
      _message(saved ? 'Đã lưu địa điểm.' : 'Đã bỏ lưu địa điểm.');
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    }
  }

  Future<void> _openMap() async {
    final place = widget.place;
    final query = Uri.encodeComponent(place.fullAddress.isEmpty
        ? '${place.name}, ${place.province}'
        : place.fullAddress);

    final uri = place.hasLocation
        ? Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${place.latitude},${place.longitude}',
          )
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!mounted) return;

    if (!opened) {
      _message('Không thể mở bản đồ.');
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final images = place.images;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF9),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 310,
            pinned: true,
            actions: [
              IconButton.filledTonal(
                tooltip: _saved ? 'Bỏ lưu' : 'Lưu địa điểm',
                onPressed: _loadingSaved ? null : _toggleSaved,
                icon: Icon(
                  _saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
              ),
              const SizedBox(width: 10),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (images.isEmpty)
                    const ColoredBox(
                      color: Color(0xFFD7F7FA),
                      child: Icon(
                        Icons.terrain_rounded,
                        color: Color(0xFF087F8C),
                        size: 72,
                      ),
                    )
                  else
                    PageView.builder(
                      itemCount: images.length,
                      onPageChanged: (value) {
                        setState(() => _imageIndex = value);
                      },
                      itemBuilder: (context, index) {
                        return Image.network(
                          images[index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return const ColoredBox(
                              color: Color(0xFFD7F7FA),
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: Color(0xFF087F8C),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.12),
                          Colors.transparent,
                          Colors.black.withOpacity(0.55),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CategoryBadge(label: place.category.label),
                        const SizedBox(height: 10),
                        Text(
                          place.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (images.length > 1) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: List.generate(images.length, (index) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: index == _imageIndex ? 24 : 7,
                                height: 7,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: index == _imageIndex
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.45),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              );
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoCard(place: place, onOpenMap: _openMap),
                  const SizedBox(height: 18),
                  const _SectionTitle(title: 'Giới thiệu'),
                  const SizedBox(height: 8),
                  Text(
                    place.description.isEmpty
                        ? 'Địa điểm này đang được TravelHub cập nhật thêm thông tin.'
                        : place.description,
                    style: const TextStyle(
                      color: Color(0xFF3B5155),
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                  if (place.tags.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: place.tags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              avatar: const Icon(Icons.tag_rounded, size: 16),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _openMap,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Mở chỉ đường Google Maps'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.place,
    required this.onOpenMap,
  });

  final TravelPlaceModel place;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD7E5E7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Địa chỉ',
              value: place.fullAddress.isEmpty
                  ? 'Đang cập nhật'
                  : place.fullAddress,
              onTap: onOpenMap,
            ),
            const Divider(),
            _InfoRow(
              icon: Icons.schedule_rounded,
              label: 'Giờ mở cửa',
              value:
                  place.openingHours.isEmpty ? 'Đang cập nhật' : place.openingHours,
            ),
            const Divider(),
            _InfoRow(
              icon: Icons.confirmation_number_outlined,
              label: 'Giá vé',
              value: place.ticketPrice <= 0
                  ? 'Miễn phí / Đang cập nhật'
                  : '${place.ticketPrice.round()}đ',
            ),
            const Divider(),
            _InfoRow(
              icon: Icons.star_rounded,
              label: 'Đánh giá',
              value: place.rating <= 0
                  ? 'Chưa có đánh giá'
                  : '${place.rating.toStringAsFixed(1)} (${place.reviewCount} lượt)',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFF0F7F6),
          foregroundColor: const Color(0xFF087F8C),
          child: Icon(icon),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF647A7D),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF102326),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null) const Icon(Icons.chevron_right_rounded),
      ],
    );

    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: content,
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: content,
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF102326),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xFF102326),
            fontWeight: FontWeight.w900,
          ),
    );
  }
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');
}