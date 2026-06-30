import 'package:flutter/material.dart';

import '../../model/hotel.dart';
import '../../model/room.dart';
import '../../services/provider_service.dart';
import '../../widgets/cloudinary_image_field.dart';

class ProviderRoomsPage extends StatefulWidget {
  const ProviderRoomsPage({super.key, required this.service});

  final ProviderService service;

  @override
  State<ProviderRoomsPage> createState() => _ProviderRoomsPageState();
}

class _ProviderRoomsPageState extends State<ProviderRoomsPage> {
  String? _hotelId;

  Future<void> _showForm(List<HotelModel> hotels, [RoomModel? room]) async {
    if (hotels.isEmpty) {
      _message('Bạn cần tạo khách sạn trước khi thêm phòng.');
      return;
    }

    final selectedHotel = hotels.any((hotel) => hotel.id == _hotelId)
        ? _hotelId
        : hotels.first.id;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _RoomFormView(
          service: widget.service,
          hotels: hotels,
          room: room,
          initialHotelId: selectedHotel,
        ),
      ),
    );

    if (!mounted || saved != true) return;

    _message(room == null ? 'Đã thêm phòng thành công.' : 'Đã cập nhật phòng.');
  }

  Future<void> _delete(RoomModel room) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.delete_outline),
          title: const Text('Xóa phòng?'),
          content: Text(
            'Bạn có chắc muốn xóa phòng ${room.roomNumber}? '
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
      await widget.service.deleteRoom(room);
      _message('Đã xóa phòng.');
    } catch (error) {
      _message(error.toString());
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message.replaceFirst('Bad state: ', ''))),
      );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HotelModel>>(
      stream: widget.service.watchHotels(),
      builder: (context, hotelSnapshot) {
        final hotels = hotelSnapshot.data ?? [];

        final selectedHotel = hotels.any((hotel) => hotel.id == _hotelId)
            ? _hotelId
            : hotels.isEmpty
            ? null
            : hotels.first.id;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(selectedHotel),
                      initialValue: selectedHotel,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Khách sạn đang quản lý',
                        prefixIcon: Icon(Icons.apartment_outlined),
                      ),
                      items: hotels.map((hotel) {
                        return DropdownMenuItem(
                          value: hotel.id,
                          child: Text(
                            hotel.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _hotelId = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip: 'Thêm phòng',
                    onPressed: hotels.isEmpty ? null : () => _showForm(hotels),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: selectedHotel == null
                  ? const _EmptyRooms(
                      title: 'Chưa có khách sạn',
                      message: 'Hãy tạo khách sạn trước khi thêm phòng.',
                    )
                  : StreamBuilder<List<RoomModel>>(
                      stream: widget.service.watchRooms(hotelId: selectedHotel),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return _EmptyRooms(
                            title: 'Không thể tải phòng',
                            message: snapshot.error.toString(),
                          );
                        }

                        final rooms = snapshot.data ?? [];

                        if (rooms.isEmpty) {
                          return const _EmptyRooms(
                            title: 'Khách sạn chưa có phòng',
                            message: 'Nhấn nút + để thêm phòng đầu tiên.',
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          itemCount: rooms.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final room = rooms[index];

                            return _RoomCard(
                              room: room,
                              onEdit: () => _showForm(hotels, room),
                              onDelete: () => _delete(room),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.onEdit,
    required this.onDelete,
  });

  final RoomModel room;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _RoomImageCarousel(images: room.images),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${room.type} · Phòng ${room.roomNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${_formatMoney(room.price)}/đêm',
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(
                            icon: Icons.group_outlined,
                            label: '${room.maxGuests} khách',
                          ),
                          _InfoChip(
                            icon: room.isAvailable
                                ? Icons.check_circle_outline
                                : Icons.pause_circle_outline,
                            label: room.isAvailable
                                ? 'Đang mở bán'
                                : 'Tạm đóng',
                            foreground: room.isAvailable
                                ? Colors.green.shade700
                                : Colors.orange.shade800,
                          ),
                          if (room.images.isNotEmpty)
                            _InfoChip(
                              icon: Icons.photo_library_outlined,
                              label: '${room.images.length} ảnh',
                            ),
                        ],
                      ),
                      if (room.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          room.description,
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
                        title: Text('Xóa phòng'),
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

class _RoomImageCarousel extends StatefulWidget {
  const _RoomImageCarousel({required this.images});

  final List<String> images;

  @override
  State<_RoomImageCarousel> createState() => _RoomImageCarouselState();
}

class _RoomImageCarouselState extends State<_RoomImageCarousel> {
  int _currentIndex = 0;

  List<String> get _validImages {
    return widget.images.where((url) => url.trim().isNotEmpty).toSet().toList();
  }

  @override
  void didUpdateWidget(covariant _RoomImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final images = _validImages;
    if (images.isEmpty) {
      _currentIndex = 0;
    } else if (_currentIndex >= images.length) {
      _currentIndex = images.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = _validImages;
    final colors = Theme.of(context).colorScheme;

    if (images.isEmpty) {
      return ColoredBox(
        color: colors.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.bed_outlined,
            size: 52,
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.foreground});

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

class _RoomFormView extends StatefulWidget {
  const _RoomFormView({
    required this.service,
    required this.hotels,
    required this.initialHotelId,
    this.room,
  });

  final ProviderService service;
  final List<HotelModel> hotels;
  final String? initialHotelId;
  final RoomModel? room;

  @override
  State<_RoomFormView> createState() => _RoomFormViewState();
}

class _RoomFormViewState extends State<_RoomFormView> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _numberController;
  late final TextEditingController _typeController;
  late final TextEditingController _priceController;
  late final TextEditingController _guestsController;
  late final TextEditingController _descriptionController;

  late String _selectedHotelId;
  late List<String> _uploadedImageUrls;
  late bool _available;

  bool _saving = false;

  bool get _editing => widget.room != null;

  @override
  void initState() {
    super.initState();

    final room = widget.room;

    _selectedHotelId =
        room?.hotelId ?? widget.initialHotelId ?? widget.hotels.first.id;

    _uploadedImageUrls = List<String>.from(room?.images ?? const <String>[]);

    _available = room?.isAvailable ?? true;

    _numberController = TextEditingController(text: room?.roomNumber ?? '');
    _typeController = TextEditingController(text: room?.type ?? '');
    _priceController = TextEditingController(
      text: room == null ? '' : room.price.toStringAsFixed(0),
    );
    _guestsController = TextEditingController(
      text: room?.maxGuests.toString() ?? '2',
    );
    _descriptionController = TextEditingController(
      text: room?.description ?? '',
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    if (_uploadedImageUrls.isEmpty) {
      _message('Vui lòng tải lên ít nhất một ảnh phòng.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      final room = widget.room;
      final images = List<String>.from(_uploadedImageUrls);

      if (room == null) {
        await widget.service.addRoom(
          hotelId: _selectedHotelId,
          roomNumber: _numberController.text.trim(),
          type: _typeController.text.trim(),
          price: double.parse(_priceController.text.trim()),
          maxGuests: int.parse(_guestsController.text.trim()),
          description: _descriptionController.text.trim(),
          isAvailable: _available,
          images: images,
        );
      } else {
        await widget.service.updateRoom(
          RoomModel(
            id: room.id,
            hotelId: room.hotelId,
            providerId: room.providerId,
            roomNumber: _numberController.text.trim(),
            type: _typeController.text.trim(),
            price: double.parse(_priceController.text.trim()),
            description: _descriptionController.text.trim(),
            maxGuests: int.parse(_guestsController.text.trim()),
            isAvailable: _available,
            images: images,
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
        SnackBar(content: Text(message.replaceFirst('Bad state: ', ''))),
      );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Không được để trống';
    }

    return null;
  }

  String? _positiveNumber(String? value) {
    final number = double.tryParse(value?.trim() ?? '');

    if (number == null || number <= 0) {
      return 'Giá trị phải lớn hơn 0';
    }

    return null;
  }

  String? _positiveInteger(String? value) {
    final number = int.tryParse(value?.trim() ?? '');

    if (number == null || number <= 0) {
      return 'Số khách phải lớn hơn 0';
    }

    return null;
  }

  @override
  void dispose() {
    _numberController.dispose();
    _typeController.dispose();
    _priceController.dispose();
    _guestsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Chỉnh sửa phòng' : 'Thêm phòng')),
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
                    'Thông tin phòng',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Đăng nhiều ảnh để khách hàng dễ xem không gian phòng.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 22),
                  CloudinaryMultiImageField(
                    initialUrls: _uploadedImageUrls,
                    label: 'Hình ảnh phòng',
                    folder: 'room_images/${widget.service.providerId}',
                    tag: 'room',
                    onChanged: (urls) {
                      _uploadedImageUrls = List<String>.from(urls);
                    },
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedHotelId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Khách sạn',
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                    items: widget.hotels.map((hotel) {
                      return DropdownMenuItem(
                        value: hotel.id,
                        child: Text(
                          hotel.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _editing || _saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedHotelId = value);
                            }
                          },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _numberController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Số phòng',
                      prefixIcon: Icon(Icons.numbers_outlined),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _typeController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Loại phòng',
                      hintText: 'Ví dụ: Deluxe, Standard, Suite',
                      prefixIcon: Icon(Icons.bed_outlined),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Giá mỗi đêm',
                      prefixIcon: Icon(Icons.payments_outlined),
                      suffixText: 'đ',
                    ),
                    validator: _positiveNumber,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _guestsController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Số khách tối đa',
                      prefixIcon: Icon(Icons.group_outlined),
                    ),
                    validator: _positiveInteger,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả phòng',
                      hintText: 'Tiện nghi, diện tích, loại giường...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    margin: EdgeInsets.zero,
                    child: SwitchListTile(
                      secondary: Icon(
                        _available
                            ? Icons.storefront_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      title: const Text(
                        'Trạng thái mở bán',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        _available
                            ? 'Khách hàng có thể đặt phòng'
                            : 'Phòng đang được tạm ẩn',
                      ),
                      value: _available,
                      onChanged: _saving
                          ? null
                          : (value) {
                              setState(() => _available = value);
                            },
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Đang lưu...' : 'Lưu phòng'),
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

class _EmptyRooms extends StatelessWidget {
  const _EmptyRooms({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bed_outlined, size: 56, color: colors.primary),
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
      ),
    );
  }
}

String _formatMoney(double value) {
  final raw = value.toStringAsFixed(0);

  final formatted = raw.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );

  return '$formatted đ';
}
