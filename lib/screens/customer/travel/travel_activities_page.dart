import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../model/saved_place.dart';
import '../../../model/travel_place.dart';
import '../../../services/saved_place_service.dart';
import '../../../services/travel_place_service.dart';
import 'ai_travel_chat_page.dart';
import 'travel_place_details_page.dart';
import 'widgets/travel_place_card.dart';

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

  void _openAiChat() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AiTravelChatPage(),
      ),
    );
  }

  Future<void> _toggleSaved(TravelPlaceModel place) async {
    try {
      final saved = await _savedService.toggleTravelPlace(place);

      if (!mounted) return;
      _message(saved ? 'Đã lưu địa điểm.' : 'Đã bỏ lưu địa điểm.');
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF9),
      appBar: AppBar(
        title: const Text('Hoạt động du lịch'),
        backgroundColor: const Color(0xFFF4FAF9),
        actions: [
          IconButton.filledTonal(
            tooltip: 'AI gợi ý du lịch',
            onPressed: _openAiChat,
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          _HeroCard(onAiTap: _openAiChat),
          const SizedBox(height: 16),
          SearchBar(
            controller: _searchController,
            hintText: 'Tìm địa điểm, tỉnh thành, hoạt động...',
            leading: const Icon(Icons.search_rounded),
            onChanged: (value) => setState(() => _search = value),
            trailing: [
              if (_search.isNotEmpty)
                IconButton(
                  tooltip: 'Xóa tìm kiếm',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _search = '');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _CategoryFilter(
            selected: _category,
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 20),
          Text(
            'Địa điểm nổi bật',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF102326),
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<TravelPlaceModel>>(
            stream: _service.watchPlaces(
              category: _category,
              keyword: _search,
              limit: 80,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return _EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Không thể tải địa điểm',
                  message: _cleanError(snapshot.error),
                );
              }

              final places = snapshot.data ?? [];

              if (places.isEmpty) {
                return const _EmptyState(
                  icon: Icons.travel_explore_rounded,
                  title: 'Chưa có địa điểm phù hợp',
                  message: 'Hãy thử từ khóa hoặc nhóm hoạt động khác.',
                );
              }

              if (userId.isEmpty) {
                return Column(
                  children: places
                      .map(
                        (place) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: TravelPlaceCard(
                            place: place,
                            onTap: () => _openPlace(place),
                          ),
                        ),
                      )
                      .toList(),
                );
              }

              return StreamBuilder<List<SavedPlaceModel>>(
                stream: _savedService.watchMySavedPlaces(
                  type: SavedPlaceType.travelPlace,
                ),
                builder: (context, savedSnapshot) {
                  final savedIds = (savedSnapshot.data ?? [])
                      .map((item) => item.placeId)
                      .toSet();

                  return Column(
                    children: places
                        .map(
                          (place) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: TravelPlaceCard(
                              place: place,
                              saved: savedIds.contains(place.id),
                              onTap: () => _openPlace(place),
                              onSaveTap: () => _toggleSaved(place),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onAiTap});

  final VoidCallback onAiTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF073B42),
            Color(0xFF087F8C),
            Color(0xFF42D8C8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF087F8C).withOpacity(0.24),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            top: -26,
            child: Icon(
              Icons.terrain_rounded,
              size: 132,
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Khám phá Việt Nam',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tìm địa điểm du lịch, hoạt động nổi bật và nhận gợi ý hành trình phù hợp.',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF087F8C),
                ),
                onPressed: onAiTap,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Hỏi AI gợi ý chuyến đi'),
              ),
            ],
          ),
        ],
      ),
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final label = category == null ? 'Tất cả' : category.label;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected == category,
              onSelected: (_) => onChanged(category),
            ),
          );
        }).toList(),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
      child: Column(
        children: [
          Icon(icon, size: 58, color: const Color(0xFF087F8C)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF102326),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF647A7D)),
          ),
        ],
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