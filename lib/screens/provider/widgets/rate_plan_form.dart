import 'package:flutter/material.dart';

import '../../../model/room_rate_plan.dart';

class ProviderRatePlanForm extends StatefulWidget {
  const ProviderRatePlanForm({
    super.key,
    required this.onSaved,
    this.initialPlan,
  });

  final RoomRatePlan? initialPlan;
  final ValueChanged<RoomRatePlan> onSaved;

  @override
  State<ProviderRatePlanForm> createState() =>
      _ProviderRatePlanFormState();
}

class _ProviderRatePlanFormState
    extends State<ProviderRatePlanForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;

  late String _type;
  late int _startHour;
  late int _endHour;
  late bool _enabled;

  @override
  void initState() {
    super.initState();

    final plan = widget.initialPlan;

    _type = plan?.type ?? RatePlanType.daytime;
    _startHour = plan?.startHour ?? 8;
    _endHour = plan?.endHour ?? 18;
    _enabled = plan?.enabled ?? true;

    _nameController = TextEditingController(
      text: plan?.name ?? RatePlanType.label(_type),
    );

    _priceController = TextEditingController(
      text: plan == null
          ? ''
          : plan.price.toStringAsFixed(0),
    );
  }

  void _changeType(String type) {
    setState(() {
      _type = type;
      _nameController.text = RatePlanType.label(type);

      switch (type) {
        case RatePlanType.overnight:
          _startHour = 20;
          _endHour = 8;
        case RatePlanType.dayNight:
          _startHour = 14;
          _endHour = 12;
        default:
          _startHour = 8;
          _endHour = 18;
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (_startHour == _endHour) {
      _message('Giờ bắt đầu và kết thúc không được trùng nhau.');
      return;
    }

    final oldPlan = widget.initialPlan;

    final id = oldPlan?.id ??
        '${_type}_${DateTime.now().microsecondsSinceEpoch}';

    final plan = RoomRatePlan(
      id: id,
      name: _nameController.text.trim(),
      type: _type,
      startHour: _startHour,
      endHour: _endHour,
      price: _parseMoney(_priceController.text),
      enabled: _enabled,
    );

    if (!plan.isValid) {
      _message('Thông tin combo chưa hợp lệ.');
      return;
    }

    widget.onSaved(plan);
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Không được để trống';
    }

    return null;
  }

  String? _priceValidator(String? value) {
    final price = _parseMoney(value ?? '');

    if (price <= 0) {
      return 'Giá combo phải lớn hơn 0';
    }

    return null;
  }

  int get _durationHours {
    if (_endHour > _startHour) {
      return _endHour - _startHour;
    }

    return 24 - _startHour + _endHour;
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = List.generate(24, (index) => index);

    return Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            widget.initialPlan == null
                ? 'Thêm combo giá'
                : 'Chỉnh sửa combo',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Loại combo',
              prefixIcon: Icon(Icons.local_offer_outlined),
            ),
            items: RatePlanType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(RatePlanType.label(type)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) _changeType(value);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            validator: _required,
            decoration: const InputDecoration(
              labelText: 'Tên hiển thị',
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _startHour,
                  decoration: const InputDecoration(
                    labelText: 'Bắt đầu',
                  ),
                  items: hours.map((hour) {
                    return DropdownMenuItem(
                      value: hour,
                      child: Text(_hourLabel(hour)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _startHour = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _endHour,
                  decoration: const InputDecoration(
                    labelText: 'Kết thúc',
                  ),
                  items: hours.map((hour) {
                    return DropdownMenuItem(
                      value: hour,
                      child: Text(_hourLabel(hour)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _endHour = value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Thời lượng combo: $_durationHours giờ'
            '${_endHour <= _startHour ? ' · qua ngày hôm sau' : ''}',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _priceController,
            validator: _priceValidator,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Giá combo',
              suffixText: 'đ',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Kích hoạt combo'),
            subtitle: Text(
              _enabled
                  ? 'Khách hàng có thể chọn combo này'
                  : 'Combo đang tạm ẩn',
            ),
            value: _enabled,
            onChanged: (value) {
              setState(() => _enabled = value);
            },
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Lưu combo'),
          ),
        ],
      ),
    );
  }
}

String _hourLabel(int hour) {
  return '${hour.toString().padLeft(2, '0')}:00';
}

double _parseMoney(String value) {
  final normalized = value
      .replaceAll('đ', '')
      .replaceAll(' ', '')
      .replaceAll('.', '')
      .replaceAll(',', '.');

  return double.tryParse(normalized) ?? 0;
}