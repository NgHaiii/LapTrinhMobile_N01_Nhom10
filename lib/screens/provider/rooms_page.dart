import 'package:flutter/material.dart';

import '../../model/hotel.dart';
import '../../model/room.dart';
import '../../model/room_rate_plan.dart';
import '../../services/provider_service.dart';
import '../../widgets/cloudinary_image_field.dart';
import 'widgets/rate_plan_form.dart';

class ProviderRoomsPage extends StatefulWidget {
  const ProviderRoomsPage({
    super.key,
    required this.service,
  });

  final ProviderService service;

  @override
  State<ProviderRoomsPage> createState() =>
      _ProviderRoomsPageState();
}

class _ProviderRoomsPageState
    extends State<ProviderRoomsPage> {
  String? _hotelId;

  Future<void> _openForm(
    List<HotelModel> hotels, [
    RoomModel? room,
  ]) async {
    if (hotels.isEmpty) {
      _message(
        'Bạn cần tạo khách sạn trước khi thêm phòng.',
      );
      return;
    }

    final selectedHotelId =
        room?.hotelId ?? _hotelId ?? hotels.first.id;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _RoomFormScreen(
          service: widget.service,
          hotels: hotels,
          room: room,
          initialHotelId: selectedHotelId,
        ),
      ),
    );

    if (!mounted || saved != true) return;

    _message(
      room == null
          ? 'Đã thêm phòng thành công.'
          : 'Đã cập nhật thông tin phòng.',
    );
  }

  Future<void> _delete(RoomModel room) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Xóa phòng?'),
        content: Text(
          'Phòng ${room.roomNumber} sẽ bị xóa khỏi '
          'khách sạn. Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Xóa phòng'),
          ),
        ],
      ),
    );

    if (accepted != true) return;

    try {
      await widget.service.deleteRoom(room);

      if (!mounted) return;
      _message('Đã xóa phòng.');
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HotelModel>>(
      stream: widget.service.watchHotels(),
      builder: (context, hotelSnapshot) {
        if (hotelSnapshot.connectionState ==
                ConnectionState.waiting &&
            !hotelSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (hotelSnapshot.hasError) {
          return _ErrorState(
            message: _cleanError(hotelSnapshot.error),
          );
        }

        final hotels = hotelSnapshot.data ?? [];

        final selectedHotel =
            hotels.any((hotel) => hotel.id == _hotelId)
            ? _hotelId
            : hotels.isEmpty
            ? null
            : hotels.first.id;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                16,
                20,
                12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child:
                        DropdownButtonFormField<String>(
                          key: ValueKey(selectedHotel),
                          initialValue: selectedHotel,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(
                                labelText: 'Khách sạn',
                                prefixIcon: Icon(
                                  Icons
                                      .apartment_outlined,
                                ),
                              ),
                          items: hotels.map((hotel) {
                            return DropdownMenuItem(
                              value: hotel.id,
                              child: Text(
                                hotel.name,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(
                              () => _hotelId = value,
                            );
                          },
                        ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip: 'Thêm phòng',
                    onPressed: hotels.isEmpty
                        ? null
                        : () => _openForm(hotels),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: selectedHotel == null
                  ? const _EmptyState(
                      icon: Icons.apartment_outlined,
                      message:
                          'Hãy tạo khách sạn trước khi thêm phòng.',
                    )
                  : StreamBuilder<List<RoomModel>>(
                      stream: widget.service.watchRooms(
                        hotelId: selectedHotel,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child:
                                CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return _ErrorState(
                            message: _cleanError(
                              snapshot.error,
                            ),
                          );
                        }

                        final rooms =
                            snapshot.data ?? [];

                        if (rooms.isEmpty) {
                          return const _EmptyState(
                            icon: Icons.bed_outlined,
                            message:
                                'Khách sạn chưa có phòng.',
                          );
                        }

                        return ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(
                                20,
                                4,
                                20,
                                28,
                              ),
                          itemCount: rooms.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final room = rooms[index];

                            return _RoomCard(
                              room: room,
                              onEdit: () => _openForm(
                                hotels,
                                room,
                              ),
                              onDelete: () =>
                                  _delete(room),
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
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                  width: 104,
                  height: 126,
                  child: room.coverImage.isEmpty
                      ? ColoredBox(
                          color: colors
                              .surfaceContainerHighest,
                          child: const Icon(
                            Icons.bed_outlined,
                            size: 38,
                          ),
                        )
                      : Image.network(
                          room.coverImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              ColoredBox(
                                color: colors
                                    .surfaceContainerHighest,
                                child: const Icon(
                                  Icons
                                      .broken_image_outlined,
                                ),
                              ),
                        ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${room.type} · '
                            'Phòng ${room.roomNumber}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Tùy chọn',
                          padding: EdgeInsets.zero,
                          onSelected: (value) {
                            if (value == 'edit') onEdit();
                            if (value == 'delete') {
                              onDelete();
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(
                                  Icons.edit_outlined,
                                ),
                                title: Text('Chỉnh sửa'),
                                contentPadding:
                                    EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(
                                  Icons.delete_outline,
                                ),
                                title: Text('Xóa phòng'),
                                contentPadding:
                                    EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      '${room.maxGuests} khách'
                      '${room.area > 0 ? ' · ${room.area.toStringAsFixed(0)} m²' : ''}'
                      ' · ${room.images.length} ảnh',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Giờ đầu ${_money(room.effectiveFirstHourPrice)}',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Từ giờ 2: '
                      '${_money(room.effectiveAdditionalHourPrice)}/giờ',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _SmallBadge(
                          icon: room.isAvailable
                              ? Icons.check_circle_outline
                              : Icons.pause_circle_outline,
                          label: room.isAvailable
                              ? 'Đang mở'
                              : 'Tạm đóng',
                          color: room.isAvailable
                              ? Colors.green
                              : Colors.orange,
                        ),
                        if (room.enabledRatePlans.isNotEmpty)
                          _SmallBadge(
                            icon:
                                Icons.local_offer_outlined,
                            label:
                                '${room.enabledRatePlans.length} combo',
                            color: colors.secondary,
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

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
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

class _RoomFormScreen extends StatefulWidget {
  const _RoomFormScreen({
    required this.service,
    required this.hotels,
    required this.initialHotelId,
    this.room,
  });

  final ProviderService service;
  final List<HotelModel> hotels;
  final String initialHotelId;
  final RoomModel? room;

  @override
  State<_RoomFormScreen> createState() =>
      _RoomFormScreenState();
}

class _RoomFormScreenState
    extends State<_RoomFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _numberController;
  late final TextEditingController
  _nightlyPriceController;
  late final TextEditingController
  _firstHourPriceController;
  late final TextEditingController
  _additionalHourPriceController;
  late final TextEditingController
  _weekendPercentController;
  late final TextEditingController
  _holidayPercentController;
  late final TextEditingController _guestsController;
  late final TextEditingController _areaController;
  late final TextEditingController _bedCountController;
  late final TextEditingController _bedTypeController;
  late final TextEditingController
  _descriptionController;
  late final TextEditingController
  _amenitiesController;

  late String _hotelId;
  late String _type;
  late bool _available;
  late List<String> _images;
  late List<RoomRatePlan> _ratePlans;

  bool _saving = false;

  static const _types = [
    'Phòng đơn',
    'Phòng đôi',
    'Phòng gia đình',
    'Phòng Deluxe',
    'Phòng Suite',
    'Phòng VIP',
  ];

  @override
  void initState() {
    super.initState();

    final room = widget.room;

    _hotelId =
        room?.hotelId ?? widget.initialHotelId;
    _type = _types.contains(room?.type)
        ? room!.type
        : _types.first;
    _available = room?.isAvailable ?? true;
    _images = [...?room?.images];
    _ratePlans = [...?room?.ratePlans];

    _numberController = TextEditingController(
      text: room?.roomNumber ?? '',
    );

    _nightlyPriceController =
        TextEditingController(
          text: room == null
              ? ''
              : room.price.toStringAsFixed(0),
        );

    _firstHourPriceController =
        TextEditingController(
          text: room == null
              ? ''
              : room.effectiveFirstHourPrice
                    .toStringAsFixed(0),
        );

    _additionalHourPriceController =
        TextEditingController(
          text: room == null
              ? ''
              : room.effectiveAdditionalHourPrice
                    .toStringAsFixed(0),
        );

    _weekendPercentController =
        TextEditingController(
          text: room?.weekendSurchargePercent
                  .toStringAsFixed(0) ??
              '20',
        );

    _holidayPercentController =
        TextEditingController(
          text: room?.holidaySurchargePercent
                  .toStringAsFixed(0) ??
              '35',
        );

    _guestsController = TextEditingController(
      text: room?.maxGuests.toString() ?? '2',
    );

    _areaController = TextEditingController(
      text: room == null || room.area <= 0
          ? ''
          : room.area.toStringAsFixed(0),
    );

    _bedCountController = TextEditingController(
      text: room?.bedCount.toString() ?? '1',
    );

    _bedTypeController = TextEditingController(
      text: room?.bedType ?? '',
    );

    _descriptionController =
        TextEditingController(
          text: room?.description ?? '',
        );

    _amenitiesController = TextEditingController(
      text: room?.amenities.join(', ') ?? '',
    );
  }

  Future<void> _openRatePlanForm([
    RoomRatePlan? initialPlan,
  ]) async {
    final plan =
        await showModalBottomSheet<RoomRatePlan>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (sheetContext) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(
                  sheetContext,
                ).bottom,
              ),
              child: FractionallySizedBox(
                heightFactor: 0.88,
                child: ProviderRatePlanForm(
                  initialPlan: initialPlan,
                  onSaved: (value) {
                    Navigator.pop(sheetContext, value);
                  },
                ),
              ),
            );
          },
        );

    if (!mounted || plan == null) return;

    setState(() {
      final index = _ratePlans.indexWhere(
        (item) => item.id == plan.id,
      );

      if (index < 0) {
        _ratePlans.add(plan);
      } else {
        _ratePlans[index] = plan;
      }
    });
  }

  Future<void> _removeRatePlan(
    RoomRatePlan plan,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa combo?'),
        content: Text(
          'Bạn có chắc muốn xóa "${plan.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (accepted == true && mounted) {
      setState(() {
        _ratePlans.removeWhere(
          (item) => item.id == plan.id,
        );
      });
    }
  }

  void _toggleRatePlan(
    RoomRatePlan plan,
    bool enabled,
  ) {
    setState(() {
      final index = _ratePlans.indexWhere(
        (item) => item.id == plan.id,
      );

      if (index >= 0) {
        _ratePlans[index] = plan.copyWith(
          enabled: enabled,
        );
      }
    });
  }

  Future<void> _save() async {
    if (_saving ||
        !_formKey.currentState!.validate()) {
      return;
    }

    if (_images.isEmpty) {
      _message(
        'Vui lòng đăng ít nhất một ảnh phòng.',
      );
      return;
    }

    final firstPrice = _number(
      _firstHourPriceController.text,
    );

    final additionalPrice = _number(
      _additionalHourPriceController.text,
    );

    final weekendPercent = _number(
      _weekendPercentController.text,
    );

    final holidayPercent = _number(
      _holidayPercentController.text,
    );

    final guests = int.tryParse(
      _guestsController.text.trim(),
    );

    final bedCount = int.tryParse(
      _bedCountController.text.trim(),
    );

    if (guests == null || guests <= 0) {
      _message('Số khách không hợp lệ.');
      return;
    }

    if (bedCount == null || bedCount <= 0) {
      _message('Số giường không hợp lệ.');
      return;
    }

    setState(() => _saving = true);

    final amenities = _amenitiesController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    try {
      final currentRoom = widget.room;

      if (currentRoom == null) {
        await widget.service.addRoom(
          hotelId: _hotelId,
          roomNumber: _numberController.text,
          type: _type,
          price: _number(
            _nightlyPriceController.text,
          ),
          hourlyPrice: firstPrice,
          firstHourPrice: firstPrice,
          additionalHourPrice: additionalPrice,
          weekendSurchargePercent:
              weekendPercent,
          holidaySurchargePercent:
              holidayPercent,
          maxGuests: guests,
          area: _number(_areaController.text),
          bedCount: bedCount,
          bedType: _bedTypeController.text,
          description:
              _descriptionController.text,
          isAvailable: _available,
          images: _images,
          amenities: amenities,
          ratePlans: _ratePlans,
        );
      } else {
        await widget.service.updateRoom(
          currentRoom.copyWith(
            hotelId: _hotelId,
            roomNumber:
                _numberController.text.trim(),
            type: _type,
            price: _number(
              _nightlyPriceController.text,
            ),
            hourlyPrice: firstPrice,
            firstHourPrice: firstPrice,
            additionalHourPrice: additionalPrice,
            weekendSurchargePercent:
                weekendPercent,
            holidaySurchargePercent:
                holidayPercent,
            maxGuests: guests,
            area: _number(_areaController.text),
            bedCount: bedCount,
            bedType:
                _bedTypeController.text.trim(),
            description:
                _descriptionController.text.trim(),
            isAvailable: _available,
            images: _images,
            amenities: amenities,
            ratePlans: _ratePlans,
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Không được để trống';
    }

    return null;
  }

  String? _positiveNumber(String? value) {
    if (_number(value ?? '') <= 0) {
      return 'Giá trị phải lớn hơn 0';
    }

    return null;
  }

  String? _percentage(String? value) {
    final number = _number(value ?? '');

    if (number < 0 || number > 100) {
      return 'Nhập từ 0 đến 100';
    }

    return null;
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(value)),
      );
  }

  @override
  void dispose() {
    _numberController.dispose();
    _nightlyPriceController.dispose();
    _firstHourPriceController.dispose();
    _additionalHourPriceController.dispose();
    _weekendPercentController.dispose();
    _holidayPercentController.dispose();
    _guestsController.dispose();
    _areaController.dispose();
    _bedCountController.dispose();
    _bedTypeController.dispose();
    _descriptionController.dispose();
    _amenitiesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.room == null
              ? 'Thêm phòng'
              : 'Chỉnh sửa phòng',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            32,
          ),
          children: [
            const _SectionTitle(
              icon: Icons.bed_outlined,
              title: 'Thông tin phòng',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _hotelId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Khách sạn',
                prefixIcon: Icon(
                  Icons.apartment_outlined,
                ),
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
              onChanged: widget.room == null
                  ? (value) {
                      if (value != null) {
                        setState(
                          () => _hotelId = value,
                        );
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _numberController,
                    validator: _required,
                    decoration:
                        const InputDecoration(
                          labelText: 'Số phòng',
                          prefixIcon: Icon(
                            Icons.meeting_room_outlined,
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child:
                      DropdownButtonFormField<String>(
                        initialValue: _type,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(
                              labelText: 'Loại phòng',
                            ),
                        items: _types.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(
                              type,
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(
                              () => _type = value,
                            );
                          }
                        },
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle(
              icon: Icons.payments_outlined,
              title: 'Giá thuê theo giờ',
            ),
            const SizedBox(height: 5),
            Text(
              'Giá ngày lễ được ưu tiên và không cộng '
              'thêm phụ thu cuối tuần.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller:
                        _firstHourPriceController,
                    validator: _positiveNumber,
                    keyboardType:
                        TextInputType.number,
                    decoration:
                        const InputDecoration(
                          labelText: 'Giờ đầu',
                          suffixText: 'đ',
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller:
                        _additionalHourPriceController,
                    validator: _positiveNumber,
                    keyboardType:
                        TextInputType.number,
                    decoration:
                        const InputDecoration(
                          labelText: 'Từ giờ thứ 2',
                          suffixText: 'đ/giờ',
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nightlyPriceController,
              validator: _positiveNumber,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText:
                    'Giá tham khảo mỗi đêm',
                suffixText: 'đ',
                prefixIcon: Icon(
                  Icons.nightlight_outlined,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller:
                        _weekendPercentController,
                    validator: _percentage,
                    keyboardType:
                        TextInputType.number,
                    decoration:
                        const InputDecoration(
                          labelText:
                              'Phụ thu cuối tuần',
                          suffixText: '%',
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller:
                        _holidayPercentController,
                    validator: _percentage,
                    keyboardType:
                        TextInputType.number,
                    decoration:
                        const InputDecoration(
                          labelText: 'Phụ thu ngày lễ',
                          suffixText: '%',
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: _SectionTitle(
                    icon:
                        Icons.local_offer_outlined,
                    title: 'Combo giá',
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Thêm combo',
                  onPressed: _openRatePlanForm,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_ratePlans.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      colors.surfaceContainerLow,
                  borderRadius:
                      BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.outlineVariant,
                  ),
                ),
                child: const Text(
                  'Chưa có combo. Khách hàng vẫn có '
                  'thể đặt theo giá từng giờ.',
                ),
              )
            else
              ..._ratePlans.map(
                (plan) => Padding(
                  padding:
                      const EdgeInsets.only(bottom: 8),
                  child: _RatePlanTile(
                    plan: plan,
                    onEdit: () =>
                        _openRatePlanForm(plan),
                    onDelete: () =>
                        _removeRatePlan(plan),
                    onEnabledChanged: (value) =>
                        _toggleRatePlan(
                          plan,
                          value,
                        ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const _SectionTitle(
              icon: Icons.groups_outlined,
              title: 'Sức chứa và tiện nghi',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _guestsController,
                    validator: _positiveNumber,
                    keyboardType:
                        TextInputType.number,
                    decoration:
                        const InputDecoration(
                          labelText: 'Số khách',
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _areaController,
                    keyboardType:
                        TextInputType.number,
                    decoration:
                        const InputDecoration(
                          labelText: 'Diện tích',
                          suffixText: 'm²',
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller:
                        _bedCountController,
                    validator: _positiveNumber,
                    keyboardType:
                        TextInputType.number,
                    decoration:
                        const InputDecoration(
                          labelText: 'Số giường',
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller:
                        _bedTypeController,
                    decoration:
                        const InputDecoration(
                          labelText: 'Loại giường',
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amenitiesController,
              decoration: const InputDecoration(
                labelText:
                    'Tiện ích, ngăn cách bằng dấu phẩy',
                prefixIcon: Icon(
                  Icons.checklist_rounded,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Mô tả phòng',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            const _SectionTitle(
              icon:
                  Icons.photo_library_outlined,
              title: 'Hình ảnh phòng',
            ),
            const SizedBox(height: 12),
            CloudinaryMultiImageField(
              folder:
                  'provider_rooms/${widget.service.providerId}',
              tag: 'provider_room',
              label: 'Chọn ảnh từ thiết bị',
              initialUrls: _images,
              onChanged: (values) {
                _images =
                    List<String>.from(values);
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                _available
                    ? Icons.check_circle_outline
                    : Icons.pause_circle_outline,
              ),
              title: const Text(
                'Cho phép nhận đặt phòng',
              ),
              subtitle: Text(
                _available
                    ? 'Khách hàng có thể đặt phòng'
                    : 'Phòng đang tạm đóng',
              ),
              value: _available,
              onChanged: (value) {
                setState(
                  () => _available = value,
                );
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _saving
                    ? 'Đang lưu...'
                    : 'Lưu thông tin phòng',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatePlanTile extends StatelessWidget {
  const _RatePlanTile({
    required this.plan,
    required this.onEdit,
    required this.onDelete,
    required this.onEnabledChanged,
  });

  final RoomRatePlan plan;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: colors.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_offer_outlined,
            color: plan.enabled
                ? colors.primary
                : colors.outline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${plan.timeLabel} · '
                  '${_money(plan.price)}',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: plan.enabled,
            onChanged: onEnabledChanged,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('Chỉnh sửa'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Xóa combo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 21),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

double _number(String value) {
  final normalized = value
      .replaceAll('đ', '')
      .replaceAll(' ', '')
      .replaceAll('.', '')
      .replaceAll(',', '.');

  return double.tryParse(normalized) ?? 0;
}

String _money(double value) {
  final raw = value.round().toString();

  return '${raw.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  )}đ';
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}