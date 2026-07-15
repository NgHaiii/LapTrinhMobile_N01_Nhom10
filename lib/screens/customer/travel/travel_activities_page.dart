import 'package:flutter/material.dart';

import '../../../model/travel_place.dart';
import '../../../services/saved_place_service.dart';
import '../../../services/travel_place_service.dart';
import 'ai_travel_chat_page.dart';
import 'travel_place_details_page.dart';

class TravelActivitiesPage extends StatefulWidget {
  const TravelActivitiesPage({
    super.key,
    this.service,
    this.savedService,
  });

  final TravelPlaceService? service;
  final SavedPlaceService? savedService;

  @override
  State<TravelActivitiesPage> createState() => _TravelActivitiesPageState();
}

class _TravelActivitiesPageState extends State<TravelActivitiesPage> {
  final _searchController = TextEditingController();

  late final TravelPlaceService _service;
  late final SavedPlaceService _savedService;

  TravelPlaceCategory? _category;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? TravelPlaceService();
    _savedService = widget.savedService ?? SavedPlaceService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAiChat() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AiTravelChatPage(),
      ),
    );
  }

  void _openPlace(TravelPlaceModel place) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TravelPlaceDetailsPage(
          place: place,
          service: _service,
          savedService: _savedService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF8),
      appBar: AppBar(
        title: const Text('Hoạt động du lịch'),
        backgroundColor: const Color(0xFFF4FBF8),
        actions: [
          IconButton.filledTonal(
            tooltip: 'AI gợi ý du lịch',
            onPressed: _openAiChat,
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: StreamBuilder<List<TravelPlaceModel>>(
        stream: _service.watchPlaces(
          category: _category,
          keyword: _search,
          limit: 80,
        ),
        builder: (context, snapshot) {
          final places = snapshot.data ?? [];

          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TravelHero(onAiTap: _openAiChat),
                      const SizedBox(height: 18),
                      _SearchBox(
                        controller: _searchController,
                        value: _search,
                        onChanged: (value) {
                          setState(() => _search = value);
                        },
                        onClear: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      ),
                      const SizedBox(height: 14),
                      _CategoryFilter(
                        selected: _category,
                        onChanged: (value) {
                          setState(() => _category = value);
                        },
                      ),
                      const SizedBox(height: 22),
                      _SectionHeader(
                        title: 'Gợi ý nổi bật',
                        subtitle:
                            'Khám phá những điểm đến được chọn lọc cho chuyến đi tiếp theo.',
                        count: places.length,
                      ),
                    ],
                  ),
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Không thể tải địa điểm',
                    message: _cleanError(snapshot.error),
                  ),
                )
              else if (places.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.travel_explore_rounded,
                    title: 'Chưa có địa điểm phù hợp',
                    message: 'Hãy thử từ khóa hoặc nhóm hoạt động khác.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  sliver: SliverList.separated(
                    itemCount: places.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final place = places[index];

                      return _TravelPlaceCard(
                        place: place,
                        accentColor: _accentColor(index),
                        onTap: () => _openPlace(place),
                      );
                    },
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).bottom + 8,
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'travel_ai_fab',
        onPressed: _openAiChat,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Hỏi AI'),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
    );
  }
}

class _TravelHero extends StatelessWidget {
  const _TravelHero({
    required this.onAiTap,
  });

  final VoidCallback onAiTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 258,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF087F8C).withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/travel/Ha_Long/1.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFF087F8C),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF053A42).withValues(alpha: 0.88),
                    const Color(0xFF087F8C).withValues(alpha: 0.58),
                    const Color(0xFFFFB35C).withValues(alpha: 0.30),
                  ],
                ),
              ),
            ),
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                Icons.flight_takeoff_rounded,
                size: 132,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _GlassBadge(
                    icon: Icons.explore_rounded,
                    label: 'Khám phá Việt Nam',
                  ),
                  const Spacer(),
                  const Text(
                    'Hôm nay bạn muốn đi đâu?',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      height: 1.04,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Biển xanh, phố cổ, núi rừng và những hành trình đầy cảm hứng.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF087F8C),
                          minimumSize: const Size(0, 46),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: onAiTap,
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text(
                          'Hỏi AI gợi ý',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
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

class _GlassBadge extends StatelessWidget {
  const _GlassBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      controller: controller,
      hintText: 'Tìm biển, núi, phố cổ, địa điểm...',
      leading: const Icon(Icons.search_rounded),
      onChanged: onChanged,
      trailing: [
        if (value.trim().isNotEmpty)
          IconButton(
            tooltip: 'Xóa',
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
          ),
      ],
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.selected,
    required this.onChanged,
  });

  final TravelPlaceCategory? selected;
  final ValueChanged<TravelPlaceCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    final categories = [
      null,
      TravelPlaceCategory.beach,
      TravelPlaceCategory.mountain,
      TravelPlaceCategory.culture,
      TravelPlaceCategory.food,
      TravelPlaceCategory.entertainment,
      TravelPlaceCategory.nature,
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selectedNow = selected == category;
          final label = category == null ? 'Tất cả' : category.label;

          return ChoiceChip(
            selected: selectedNow,
            label: Text(label),
            onSelected: (_) => onChanged(category),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF102326),
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$count điểm',
          style: TextStyle(
            color: colors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _TravelPlaceCard extends StatelessWidget {
  const _TravelPlaceCard({
    required this.place,
    required this.accentColor,
    required this.onTap,
  });

  final TravelPlaceModel place;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final imagePath = place.primaryImage;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.10),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imagePath.isNotEmpty)
                      Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _ImageFallback(
                          color: accentColor,
                        ),
                      )
                    else
                      _ImageFallback(color: accentColor),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.16),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.58),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      top: 14,
                      child: _ImageChip(
                        icon: Icons.category_rounded,
                        label: place.category.label,
                      ),
                    ),
                    Positioned(
                      right: 14,
                      top: 14,
                      child: _ImageChip(
                        icon: Icons.star_rounded,
                        label: place.rating.toStringAsFixed(1),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Text(
                        place.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.place_rounded, color: colors.primary),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '${place.district}, ${place.province}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      place.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              _InfoPill(
                                icon: Icons.payments_outlined,
                                label: place.isFree
                                    ? 'Miễn phí'
                                    : '${place.ticketPrice.toStringAsFixed(0)}đ',
                              ),
                              _InfoPill(
                                icon: Icons.schedule_rounded,
                                label: place.openingHours.isEmpty
                                    ? 'Linh hoạt'
                                    : place.openingHours,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: accentColor.withValues(alpha: 0.18),
                          foregroundColor: accentColor,
                          child: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color.withValues(alpha: 0.14),
      child: Center(
        child: Icon(
          Icons.landscape_rounded,
          color: color,
          size: 58,
        ),
      ),
    );
  }
}

class _ImageChip extends StatelessWidget {
  const _ImageChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
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
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: Icon(icon, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF102326),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _accentColor(int index) {
  const colors = [
    Color(0xFF087F8C),
    Color(0xFF2A9D8F),
    Color(0xFFE76F51),
    Color(0xFFF4A261),
    Color(0xFF3A86FF),
    Color(0xFF7B61FF),
  ];

  return colors[index % colors.length];
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');
}