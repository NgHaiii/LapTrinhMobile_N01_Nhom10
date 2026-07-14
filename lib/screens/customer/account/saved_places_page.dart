import 'package:flutter/material.dart';

import '../../../model/saved_place.dart';
import '../../../services/saved_place_service.dart';

class SavedPlacesPage extends StatefulWidget {
  const SavedPlacesPage({super.key});

  @override
  State<SavedPlacesPage> createState() => _SavedPlacesPageState();
}

class _SavedPlacesPageState extends State<SavedPlacesPage> {
  final SavedPlaceService _service = SavedPlaceService();

  SavedPlaceType? _selectedType;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF9),
      appBar: AppBar(
        title: const Text('Địa điểm đã lưu'),
        backgroundColor: const Color(0xFFF4FAF9),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'Tất cả',
                  selected: _selectedType == null,
                  onTap: () => setState(() => _selectedType = null),
                ),
                _FilterChip(
                  label: 'Khách sạn',
                  selected: _selectedType == SavedPlaceType.hotel,
                  onTap: () {
                    setState(() => _selectedType = SavedPlaceType.hotel);
                  },
                ),
                _FilterChip(
                  label: 'Địa điểm du lịch',
                  selected: _selectedType == SavedPlaceType.travelPlace,
                  onTap: () {
                    setState(() => _selectedType = SavedPlaceType.travelPlace);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<SavedPlaceModel>>(
              stream: _service.watchMySavedPlaces(type: _selectedType),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Không thể tải địa điểm',
                    message: snapshot.error.toString(),
                  );
                }

                final places = snapshot.data ?? [];

                if (places.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'Chưa có địa điểm đã lưu',
                    message:
                        'Bạn có thể lưu khách sạn hoặc địa điểm du lịch yêu thích để xem lại sau.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: places.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final place = places[index];

                    return _SavedPlaceCard(
                      place: place,
                      onRemove: () async {
                        await _service.removeSavedPlace(
                          placeId: place.placeId,
                          type: place.type,
                        );

                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Đã bỏ lưu địa điểm.'),
                            ),
                          );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedPlaceCard extends StatelessWidget {
  const _SavedPlaceCard({
    required this.place,
    required this.onRemove,
  });

  final SavedPlaceModel place;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox.square(
                dimension: 76,
                child: place.imageUrl.isEmpty
                    ? ColoredBox(
                        color: colors.primaryContainer,
                        child: Icon(
                          place.type == SavedPlaceType.hotel
                              ? Icons.hotel_rounded
                              : Icons.place_rounded,
                          color: colors.onPrimaryContainer,
                          size: 34,
                        ),
                      )
                    : Image.network(
                        place.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return ColoredBox(
                            color: colors.primaryContainer,
                            child: Icon(
                              place.type == SavedPlaceType.hotel
                                  ? Icons.hotel_rounded
                                  : Icons.place_rounded,
                              color: colors.onPrimaryContainer,
                              size: 34,
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF102326),
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        place.type == SavedPlaceType.hotel
                            ? Icons.hotel_outlined
                            : Icons.explore_outlined,
                        size: 15,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        place.type == SavedPlaceType.hotel
                            ? 'Khách sạn'
                            : 'Địa điểm du lịch',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    place.address.isEmpty
                        ? '${place.district}, ${place.province}'
                        : place.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Bỏ lưu',
              onPressed: onRemove,
              icon: const Icon(Icons.favorite_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) => onTap(),
        selectedColor: colors.primaryContainer,
        labelStyle: TextStyle(
          color: selected ? colors.onPrimaryContainer : colors.onSurface,
          fontWeight: FontWeight.w800,
        ),
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
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: colors.primary),
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
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}