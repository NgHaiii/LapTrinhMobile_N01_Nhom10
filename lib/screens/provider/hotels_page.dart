import 'package:flutter/material.dart';

import '../../model/hotel.dart';
import '../../services/provider_service.dart';
import '../../widgets/cloudinary_image_field.dart';

class ProviderHotelsPage extends StatefulWidget {
  const ProviderHotelsPage({super.key, required this.service});

  final ProviderService service;

  @override
  State<ProviderHotelsPage> createState() => _ProviderHotelsPageState();
}

class _ProviderHotelsPageState extends State<ProviderHotelsPage> {
  final _searchController = TextEditingController();
  String _search = '';

  Future<void> _showForm([HotelModel? hotel]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _HotelFormView(service: widget.service, hotel: hotel),
      ),
    );

    if (!mounted || saved != true) return;

    _message(
      hotel == null
          ? 'Đã thêm khách sạn thành công.'
          : 'Đã cập nhật khách sạn.',
    );
  }

  Future<void> _delete(HotelModel hotel) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.delete_outline),
          title: const Text('Xóa khách sạn?'),
          content: Text(
            'Tất cả phòng thuộc "${hotel.name}" cũng sẽ bị xóa. '
            'Thao tác này không thể hoàn tác.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (accepted != true) return;

    try {
      await widget.service.deleteHotel(hotel);
      _message('Đã xóa khách sạn.');
    } catch (error) {
      _message(error.toString());
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message
                .replaceFirst('Bad state: ', '')
                .replaceFirst('Exception: ', ''),
          ),
        ),
      );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HotelModel>>(
      stream: widget.service.watchHotels(),
      builder: (context, snapshot) {
        final keyword = _search.trim().toLowerCase();

        final hotels = (snapshot.data ?? []).where((hotel) {
          return hotel.name.toLowerCase().contains(keyword) ||
              hotel.address.toLowerCase().contains(keyword) ||
              hotel.province.toLowerCase().contains(keyword) ||
              hotel.district.toLowerCase().contains(keyword) ||
              hotel.category.toLowerCase().contains(keyword);
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Tìm tên, khu vực, loại hình...',
                    leading: const Icon(Icons.search_rounded),
                    onChanged: (value) {
                      setState(() => _search = value);
                    },
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
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: 'Thêm khách sạn',
                  onPressed: () => _showForm(),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (snapshot.hasError)
              _EmptyHotels(
                title: 'Không thể tải dữ liệu',
                message: snapshot.error.toString(),
              )
            else if (hotels.isEmpty)
              _EmptyHotels(
                title: keyword.isEmpty
                    ? 'Chưa có khách sạn'
                    : 'Không tìm thấy khách sạn',
                message: keyword.isEmpty
                    ? 'Nhấn nút + để thêm khách sạn đầu tiên.'
                    : 'Hãy thử tìm bằng từ khóa khác.',
              )
            else
              ...hotels.map(
                (hotel) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _HotelCard(
                    hotel: hotel,
                    onEdit: () => _showForm(hotel),
                    onDelete: () => _delete(hotel),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HotelCard extends StatelessWidget {
  const _HotelCard({
    required this.hotel,
    required this.onEdit,
    required this.onDelete,
  });

  final HotelModel hotel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final images = _hotelImages(hotel);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _HotelImageCarousel(images: images),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hotel.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              hotel.fullAddress,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _HotelInfoChip(
                            icon: Icons.category_outlined,
                            label: hotel.category,
                          ),
                          _HotelInfoChip(
                            icon: Icons.map_outlined,
                            label: hotel.district.isEmpty
                                ? hotel.province
                                : hotel.district,
                          ),
                          _HotelInfoChip(
                            icon: Icons.payments_outlined,
                            label: hotel.minPrice > 0
                                ? 'Từ ${_formatMoney(hotel.minPrice)}'
                                : 'Chưa có phòng',
                          ),
                          _HotelInfoChip(
                            icon: Icons.photo_library_outlined,
                            label: '${images.length} ảnh',
                          ),
                          if (hotel.rating > 0)
                            _HotelInfoChip(
                              icon: Icons.star_rounded,
                              label: hotel.rating.toStringAsFixed(1),
                              foreground: Colors.orange.shade800,
                            ),
                        ],
                      ),
                      if (hotel.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 11),
                        Text(
                          hotel.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Tùy chọn',
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Chỉnh sửa'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline),
                        title: Text('Xóa khách sạn'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HotelImageCarousel extends StatefulWidget {
  const _HotelImageCarousel({required this.images});

  final List<String> images;

  @override
  State<_HotelImageCarousel> createState() => _HotelImageCarouselState();
}

class _HotelImageCarouselState extends State<_HotelImageCarousel> {
  int _currentIndex = 0;

  @override
  void didUpdateWidget(covariant _HotelImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.images.isEmpty) {
      _currentIndex = 0;
    } else if (_currentIndex >= widget.images.length) {
      _currentIndex = widget.images.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final images = widget.images;

    if (images.isEmpty) {
      return ColoredBox(
        color: colors.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.apartment_outlined,
            size: 56,
            color: colors.onSurfaceVariant,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: images.length,
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
          },
          itemBuilder: (context, index) {
            return Image.network(
              images[index],
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;

                return ColoredBox(
                  color: colors.surfaceContainerHighest,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (_, __, ___) {
                return ColoredBox(
                  color: colors.surfaceContainerHighest,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 48,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                );
              },
            );
          },
        ),
        if (images.length > 1)
          Positioned(
            top: 12,
            right: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_currentIndex + 1}/${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (images.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Text(
                    'Vuốt để xem ảnh',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HotelInfoChip extends StatelessWidget {
  const _HotelInfoChip({
    required this.icon,
    required this.label,
    this.foreground,
  });

  final IconData icon;
  final String label;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = foreground ?? colors.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
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

class _HotelFormView extends StatefulWidget {
  const _HotelFormView({required this.service, this.hotel});

  final ProviderService service;
  final HotelModel? hotel;

  @override
  State<_HotelFormView> createState() => _HotelFormViewState();
}

class _HotelFormViewState extends State<_HotelFormView> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _provinceController;
  late final TextEditingController _districtController;
  late final TextEditingController _addressController;
  late final TextEditingController _descriptionController;

  late String _category;
  late List<String> _uploadedImageUrls;

  bool _saving = false;

  bool get _editing => widget.hotel != null;

  @override
  void initState() {
    super.initState();

    final hotel = widget.hotel;

    _nameController = TextEditingController(text: hotel?.name ?? '');
    _provinceController = TextEditingController(text: hotel?.province ?? '');
    _districtController = TextEditingController(text: hotel?.district ?? '');
    _addressController = TextEditingController(text: hotel?.address ?? '');
    _descriptionController = TextEditingController(
      text: hotel?.description ?? '',
    );

    _category = hotel?.category ?? 'Khách sạn';

    _uploadedImageUrls = hotel == null ? <String>[] : _hotelImages(hotel);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) {
      return;
    }

    if (_uploadedImageUrls.isEmpty) {
      _message('Vui lòng đăng ít nhất một ảnh khách sạn.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      final hotel = widget.hotel;

      final images = _uploadedImageUrls
          .map((url) => url.trim())
          .where((url) => url.isNotEmpty)
          .toSet()
          .toList();

      if (images.isEmpty) {
        throw StateError('Vui lòng đăng ít nhất một ảnh khách sạn.');
      }

      if (hotel == null) {
        await widget.service.addHotel(
          name: _nameController.text.trim(),
          province: _provinceController.text.trim(),
          district: _districtController.text.trim(),
          address: _addressController.text.trim(),
          description: _descriptionController.text.trim(),
          images: images,
          category: _category,
        );
      } else {
        await widget.service.updateHotel(
          HotelModel(
            id: hotel.id,
            providerId: hotel.providerId,
            name: _nameController.text.trim(),
            province: _provinceController.text.trim(),
            district: _districtController.text.trim(),
            address: _addressController.text.trim(),
            description: _descriptionController.text.trim(),
            imageUrl: images.first,
            images: images,
            category: _category,
            status: hotel.status,
            rating: hotel.rating,
            minPrice: hotel.minPrice,
            createdAt: hotel.createdAt,
          ),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() => _saving = false);
      _message(error.toString());
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message
                .replaceFirst('Bad state: ', '')
                .replaceFirst('Exception: ', ''),
          ),
        ),
      );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Không được để trống';
    }

    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _provinceController.dispose();
    _districtController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Chỉnh sửa khách sạn' : 'Thêm khách sạn'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Text(
                    'Thông tin khách sạn',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cung cấp đúng khu vực và hình ảnh để khách hàng dễ tìm kiếm.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 22),
                  CloudinaryMultiImageField(
                    initialUrls: _uploadedImageUrls,
                    label: 'Hình ảnh khách sạn',
                    folder: 'hotel_images/${widget.service.providerId}',
                    tag: 'hotel',
                    onChanged: (urls) {
                      _uploadedImageUrls = List<String>.from(urls);
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Thông tin cơ bản',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Tên khách sạn',
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Loại hình lưu trú',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Khách sạn',
                        child: Text('Khách sạn'),
                      ),
                      DropdownMenuItem(value: 'Căn hộ', child: Text('Căn hộ')),
                      DropdownMenuItem(
                        value: 'Biệt thự',
                        child: Text('Biệt thự'),
                      ),
                      DropdownMenuItem(
                        value: 'Homestay',
                        child: Text('Homestay'),
                      ),
                      DropdownMenuItem(value: 'Resort', child: Text('Resort')),
                      DropdownMenuItem(
                        value: 'Nhà nghỉ',
                        child: Text('Nhà nghỉ'),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _category = value;
                              });
                            }
                          },
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Khu vực',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Khách hàng sẽ tìm theo tỉnh/thành phố trước, sau đó đến quận/huyện.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _provinceController,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Tỉnh/Thành phố',
                      hintText: 'Ví dụ: Hà Nội',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _districtController,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Quận/Huyện',
                      hintText: 'Ví dụ: Cầu Giấy',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _addressController,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ chi tiết',
                      hintText: 'Số nhà, tên đường, phường/xã',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Giới thiệu',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    enabled: !_saving,
                    minLines: 4,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả khách sạn',
                      hintText: 'Không gian, tiện nghi, vị trí và dịch vụ...',
                      alignLabelWithHint: true,
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Đang lưu...' : 'Lưu khách sạn'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHotels extends StatelessWidget {
  const _EmptyHotels({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.apartment_outlined, size: 58, color: colors.primary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

List<String> _hotelImages(HotelModel hotel) {
  final images = <String>[];

  for (final image in hotel.images) {
    final url = image.trim();

    if (url.isNotEmpty && !images.contains(url)) {
      images.add(url);
    }
  }

  final oldImageUrl = hotel.imageUrl.trim();

  if (oldImageUrl.isNotEmpty && !images.contains(oldImageUrl)) {
    images.insert(0, oldImageUrl);
  }

  return images;
}

String _formatMoney(double value) {
  final raw = value.toStringAsFixed(0);

  final formatted = raw.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );

  return '$formatted đ';
}
