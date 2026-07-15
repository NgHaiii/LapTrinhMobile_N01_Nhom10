import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../model/saved_place.dart';
import '../../../model/travel_place.dart';
import '../../../services/saved_place_service.dart';
import '../../../services/travel_place_service.dart';
import '../nearby_hotels_page.dart';
import 'widgets/travel_place_hero.dart';

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
  late final SavedPlaceService _savedService;

  bool _saved = false;
  bool _loadingSaved = true;

  @override
  void initState() {
    super.initState();
    _savedService = widget.savedService ?? SavedPlaceService();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      setState(() => _loadingSaved = false);
      return;
    }

    try {
      final saved = await _savedService.isSaved(
        placeId: widget.place.id,
        type: SavedPlaceType.travelPlace,
      );

      if (!mounted) return;

      setState(() {
        _saved = saved;
        _loadingSaved = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSaved = false);
    }
  }

  Future<void> _toggleSaved() async {
    if (_loadingSaved) return;

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
    final fallbackQuery = place.fullAddress.isEmpty
        ? '${place.name}, ${place.province}'
        : '${place.name}, ${place.fullAddress}';

    final uri = place.hasLocation
        ? Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${place.latitude},${place.longitude}',
          )
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(fallbackQuery)}',
          );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!mounted) return;

    if (!opened) {
      _message('Không thể mở Google Maps.');
    }
  }

  void _openNearbyHotels() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NearbyHotelsPage(
          place: widget.place,
        ),
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF8),
      body: CustomScrollView(
        slivers: [
          TravelPlaceHero(
            place: place,
            isSaved: _saved,
            onToggleSaved: _loadingSaved ? () {} : _toggleSaved,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _QuickSummary(place: place, onOpenMap: _openMap),
                  const SizedBox(height: 18),
                  _SectionCard(
                    title: 'Vì sao nên đến đây?',
                    icon: Icons.auto_awesome_rounded,
                    child: Text(
                      place.description.isEmpty
                          ? 'TravelHub đang cập nhật thêm thông tin cho địa điểm này.'
                          : place.description,
                      style: const TextStyle(
                        color: Color(0xFF3B5155),
                        fontSize: 15,
                        height: 1.55,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Gợi ý trải nghiệm',
                    icon: Icons.route_rounded,
                    child: _ExperienceList(place: place),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Thông tin tham quan',
                    icon: Icons.info_outline_rounded,
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.place_outlined,
                          label: 'Địa chỉ',
                          value: place.fullAddress.isEmpty
                              ? 'Đang cập nhật'
                              : place.fullAddress,
                          onTap: _openMap,
                        ),
                        const Divider(height: 18),
                        _InfoRow(
                          icon: Icons.schedule_rounded,
                          label: 'Giờ hoạt động',
                          value: place.openingHours.isEmpty
                              ? 'Linh hoạt / đang cập nhật'
                              : place.openingHours,
                        ),
                        const Divider(height: 18),
                        _InfoRow(
                          icon: Icons.confirmation_number_outlined,
                          label: 'Giá vé',
                          value: place.isFree
                              ? 'Miễn phí / đang cập nhật'
                              : '${place.ticketPrice.round()}đ',
                        ),
                        const Divider(height: 18),
                        _InfoRow(
                          icon: Icons.star_rounded,
                          label: 'Đánh giá',
                          value: place.rating <= 0
                              ? 'Chưa có đánh giá'
                              : '${place.rating.toStringAsFixed(1)} / 5 từ ${place.reviewCount} lượt',
                        ),
                      ],
                    ),
                  ),
                  if (place.tags.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'Phù hợp với',
                      icon: Icons.local_offer_outlined,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: place.tags.map((tag) {
                          return Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.tag_rounded, size: 16),
                            label: Text(tag),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _openNearbyHotels,
                          icon: const Icon(Icons.hotel_rounded),
                          label: const Text(
                            'Đặt phòng gần đây',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openMap,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text(
                            'Chỉ đường',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loadingSaved ? null : _toggleSaved,
                      icon: Icon(
                        _saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                      ),
                      label: Text(_saved ? 'Đã lưu địa điểm' : 'Lưu địa điểm'),
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

class _QuickSummary extends StatelessWidget {
  const _QuickSummary({
    required this.place,
    required this.onOpenMap,
  });

  final TravelPlaceModel place;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFEAFBF8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD5E9E8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF087F8C).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _SummaryItem(
              icon: Icons.category_rounded,
              label: 'Loại hình',
              value: place.category.label,
            ),
            const _SummaryDivider(),
            _SummaryItem(
              icon: Icons.star_rounded,
              label: 'Điểm',
              value: place.rating <= 0 ? '--' : place.rating.toStringAsFixed(1),
            ),
            const _SummaryDivider(),
            Expanded(
              child: InkWell(
                onTap: onOpenMap,
                borderRadius: BorderRadius.circular(16),
                child: _SummaryItem(
                  icon: Icons.navigation_outlined,
                  label: 'Khu vực',
                  value: place.province,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFDDF8F5),
            foregroundColor: const Color(0xFF087F8C),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7F82),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF102326),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: const Color(0xFFD5E9E8),
    );
  }
}

class _ExperienceList extends StatelessWidget {
  const _ExperienceList({required this.place});

  final TravelPlaceModel place;

  @override
  Widget build(BuildContext context) {
    final items = _experiencesFor(place);

    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFFDDF8F5),
                foregroundColor: Color(0xFF087F8C),
                child: Icon(Icons.check_rounded, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    color: Color(0xFF3B5155),
                    height: 1.38,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  List<String> _experiencesFor(TravelPlaceModel place) {
    return switch (place.category) {
      TravelPlaceCategory.beach => [
          'Tắm biển, ngắm bình minh hoặc hoàng hôn tại các bãi biển nổi bật.',
          'Thưởng thức hải sản địa phương và khám phá các quán ăn ven biển.',
          'Kết hợp nghỉ dưỡng, chụp ảnh và các hoạt động vui chơi ngoài trời.',
        ],
      TravelPlaceCategory.mountain => [
          'Săn mây, ngắm núi và tận hưởng không khí mát lành vào sáng sớm.',
          'Khám phá bản làng, cung đường đèo hoặc các điểm nhìn toàn cảnh.',
          'Chuẩn bị giày thoải mái và áo khoác nhẹ để hành trình dễ chịu hơn.',
        ],
      TravelPlaceCategory.culture => [
          'Đi bộ chậm để cảm nhận kiến trúc, lịch sử và nhịp sống địa phương.',
          'Thử các món đặc sản nổi tiếng quanh khu trung tâm.',
          'Ghé vào buổi chiều tối để có ánh sáng đẹp và không khí sống động hơn.',
        ],
      TravelPlaceCategory.nature => [
          'Dành thời gian đi thuyền, ngắm cảnh và chụp ảnh phong cảnh.',
          'Đi vào sáng sớm hoặc chiều muộn để tránh nắng và có ánh sáng đẹp.',
          'Kết hợp thêm các điểm gần đó để có lịch trình trọn vẹn hơn.',
        ],
      _ => [
          'Khám phá điểm nổi bật, chụp ảnh và thưởng thức không khí địa phương.',
          'Lưu địa điểm để dễ lên lịch trình cho chuyến đi.',
          'Hỏi AI TravelHub để được gợi ý lịch trình phù hợp hơn.',
        ],
    };
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD7E5E7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFFE0F8F5),
                  foregroundColor: const Color(0xFF087F8C),
                  child: Icon(icon, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF102326),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            child,
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
                maxLines: 3,
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
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
  }
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');
}