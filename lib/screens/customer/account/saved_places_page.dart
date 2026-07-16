import 'package:flutter/material.dart';

import '../../../model/hotel.dart';
import '../../../model/saved_place.dart';
import '../../../model/travel_place.dart';
import '../../../services/customer_service.dart';
import '../../../services/saved_place_service.dart';
import '../../../services/travel_place_service.dart';
import '../hotels/hotel_details_screen.dart';
import '../travel/travel_place_details_page.dart';

class SavedPlacesPage extends StatefulWidget {
  const SavedPlacesPage({super.key});

  @override
  State<SavedPlacesPage> createState() => _SavedPlacesPageState();
}

class _SavedPlacesPageState extends State<SavedPlacesPage> {
  final SavedPlaceService _savedPlaceService = SavedPlaceService();
  final TravelPlaceService _travelPlaceService = TravelPlaceService();
  final CustomerService _customerService = CustomerService();

  SavedPlaceType? _selectedType;
  bool _opening = false;

  Future<void> _openSavedPlace(SavedPlaceModel savedPlace) async {
    if (_opening) return;

    setState(() => _opening = true);

    try {
      if (savedPlace.type == SavedPlaceType.travelPlace) {
        await _openTravelPlace(savedPlace);
      } else {
        await _openHotel(savedPlace);
      }
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  Future<void> _openTravelPlace(SavedPlaceModel savedPlace) async {
    final place = await _travelPlaceService.getPlace(savedPlace.placeId);

    if (!mounted) return;

    if (place == null) {
      _message('Không tìm thấy thông tin chi tiết của địa điểm này.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TravelPlaceDetailsPage(
          place: place,
          service: _travelPlaceService,
          savedService: _savedPlaceService,
        ),
      ),
    );
  }

  Future<void> _openHotel(SavedPlaceModel savedPlace) async {
    final hotel = await _customerService.watchHotel(savedPlace.placeId).first;

    if (!mounted) return;

    if (hotel == null) {
      _message('Không tìm thấy thông tin chi tiết của khách sạn này.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HotelDetailsScreen(
          service: _customerService,
          hotel: hotel,
        ),
      ),
    );
  }

  Future<void> _removeSavedPlace(SavedPlaceModel place) async {
    try {
      await _savedPlaceService.removeSavedPlace(
        placeId: place.placeId,
        type: place.type,
      );

      if (!mounted) return;

      _message('Đã bỏ lưu địa điểm.');
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF9),
      appBar: AppBar(
        title: const Text('Địa điểm đã lưu'),
        backgroundColor: const Color(0xFFF4FAF9),
      ),
      body: Stack(
        children: [
          Column(
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
                        setState(
                          () => _selectedType = SavedPlaceType.travelPlace,
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<SavedPlaceModel>>(
                  stream: _savedPlaceService.watchMySavedPlaces(
                    type: _selectedType,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
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
                          onTap: () => _openSavedPlace(place),
                          onRemove: () => _removeSavedPlace(place),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          if (_opening)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.08),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
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
    required this.onTap,
    required this.onRemove,
  });

  final SavedPlaceModel place;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
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
                    child: _SavedPlaceImage(place: place),
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
                            place.type.label,
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
                        place.fullAddress.isEmpty
                            ? 'Chưa cập nhật địa chỉ'
                            : place.fullAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (place.rating > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFE76F51),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              place.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Color(0xFFE76F51),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Xem chi tiết',
                      onPressed: onTap,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                    const SizedBox(height: 6),
                    IconButton(
                      tooltip: 'Bỏ lưu',
                      onPressed: onRemove,
                      icon: const Icon(Icons.favorite_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedPlaceImage extends StatelessWidget {
  const _SavedPlaceImage({required this.place});

  final SavedPlaceModel place;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final imageUrl = place.imageUrl.trim();

    if (imageUrl.isEmpty) {
      return _ImageFallback(place: place);
    }

    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return _ImageFallback(place: place);
        },
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return _ImageFallback(place: place);
      },
      loadingBuilder: (context, child, event) {
        if (event == null) return child;

        return ColoredBox(
          color: colors.primaryContainer,
          child: const Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.place});

  final SavedPlaceModel place;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');
}
