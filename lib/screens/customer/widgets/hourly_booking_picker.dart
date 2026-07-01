import 'package:flutter/material.dart';

import '../../../model/room_reservation.dart';

class HourlyBookingSelection {
  const HourlyBookingSelection({
    required this.checkIn,
    required this.checkOut,
    required this.durationHours,
  });

  final DateTime checkIn;
  final DateTime checkOut;
  final int durationHours;
}

class HourlyBookingPicker extends StatefulWidget {
  const HourlyBookingPicker({
    super.key,
    required this.reservations,
    required this.onChanged,
    this.initialCheckIn,
    this.initialDurationHours = 1,
    this.maxDurationHours = 48,
  });

  final List<RoomReservation> reservations;
  final ValueChanged<HourlyBookingSelection?> onChanged;
  final DateTime? initialCheckIn;
  final int initialDurationHours;
  final int maxDurationHours;

  @override
  State<HourlyBookingPicker> createState() =>
      _HourlyBookingPickerState();
}

class _HourlyBookingPickerState
    extends State<HourlyBookingPicker> {
  late DateTime _selectedDate;
  int? _selectedHour;
  late int _durationHours;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final initial = widget.initialCheckIn;

    _selectedDate = DateTime(
      initial?.year ?? now.year,
      initial?.month ?? now.month,
      initial?.day ?? now.day,
    );

    _selectedHour = initial?.hour;
    _durationHours = widget.initialDurationHours.clamp(
      1,
      widget.maxDurationHours,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _normalizeSelection();
    });
  }

  @override
  void didUpdateWidget(HourlyBookingPicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.reservations != widget.reservations) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _normalizeSelection();
      });
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);

    final result = await showDatePicker(
      context: context,
      helpText: 'Chọn ngày nhận phòng',
      initialDate: _selectedDate.isBefore(firstDate)
          ? firstDate
          : _selectedDate,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 730)),
    );

    if (!mounted || result == null) return;

    setState(() {
      _selectedDate = DateTime(
        result.year,
        result.month,
        result.day,
      );
      _selectedHour = null;
      _durationHours = 1;
    });

    _normalizeSelection();
  }

  void _selectHour(int hour) {
    final start = _dateAtHour(hour);

    if (!_isStartHourAvailable(start)) return;

    setState(() {
      _selectedHour = hour;
      _durationHours = 1;
    });

    _notify();
  }

  void _decreaseDuration() {
    if (_durationHours <= 1) return;

    setState(() => _durationHours--);
    _notify();
  }

  void _increaseDuration() {
    if (!_canIncreaseDuration) return;

    setState(() => _durationHours++);
    _notify();
  }

  bool get _canIncreaseDuration {
    final checkIn = _currentCheckIn;

    if (checkIn == null ||
        _durationHours >= widget.maxDurationHours) {
      return false;
    }

    final nextHourStart = checkIn.add(
      Duration(hours: _durationHours),
    );

    return !_isOccupied(
      nextHourStart,
      nextHourStart.add(const Duration(hours: 1)),
    );
  }

  DateTime? get _currentCheckIn {
    final hour = _selectedHour;

    if (hour == null) return null;
    return _dateAtHour(hour);
  }

  void _normalizeSelection() {
    final current = _currentCheckIn;

    if (current != null &&
        _isStartHourAvailable(current) &&
        !_isOccupied(
          current,
          current.add(Duration(hours: _durationHours)),
        )) {
      _notify();
      return;
    }

    int? firstAvailable;

    for (var hour = 0; hour < 24; hour++) {
      if (_isStartHourAvailable(_dateAtHour(hour))) {
        firstAvailable = hour;
        break;
      }
    }

    if (!mounted) return;

    setState(() {
      _selectedHour = firstAvailable;
      _durationHours = 1;
    });

    _notify();
  }

  void _notify() {
    final checkIn = _currentCheckIn;

    if (checkIn == null) {
      widget.onChanged(null);
      return;
    }

    final checkOut = checkIn.add(
      Duration(hours: _durationHours),
    );

    if (_isOccupied(checkIn, checkOut)) {
      widget.onChanged(null);
      return;
    }

    widget.onChanged(
      HourlyBookingSelection(
        checkIn: checkIn,
        checkOut: checkOut,
        durationHours: _durationHours,
      ),
    );
  }

  bool _isStartHourAvailable(DateTime start) {
    final now = DateTime.now();

    if (!start.isAfter(now)) return false;

    return !_isOccupied(
      start,
      start.add(const Duration(hours: 1)),
    );
  }

  bool _isOccupied(DateTime start, DateTime end) {
    return widget.reservations.any(
      (reservation) => reservation.overlaps(start, end),
    );
  }

  DateTime _dateAtHour(int hour) {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final checkIn = _currentCheckIn;
    final checkOut = checkIn?.add(
      Duration(hours: _durationHours),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ngày nhận phòng',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          child: ListTile(
            onTap: _selectDate,
            leading: Icon(
              Icons.calendar_today_outlined,
              color: colors.primary,
            ),
            title: const Text('Ngày đã chọn'),
            subtitle: Text(
              _dateLabel(_selectedDate),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Giờ nhận phòng',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Các giờ bị khóa đã có khách đặt.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560 ? 8 : 4;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 24,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 46,
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
              ),
              itemBuilder: (context, hour) {
                final start = _dateAtHour(hour);
                final available = _isStartHourAvailable(start);
                final selected = _selectedHour == hour;

                return _HourTile(
                  label: _hourLabel(hour),
                  selected: selected,
                  enabled: available,
                  onTap: () => _selectHour(hour),
                );
              },
            );
          },
        ),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _Legend(color: Colors.teal, label: 'Đang chọn'),
            _Legend(color: Colors.grey, label: 'Còn trống'),
            _Legend(
              color: Colors.redAccent,
              label: 'Đã được đặt',
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'Thời lượng thuê',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed:
                      _durationHours > 1 ? _decreaseDuration : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$_durationHours giờ',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (checkIn != null && checkOut != null)
                        Text(
                          '${_dateTimeLabel(checkIn)} - '
                          '${_dateTimeLabel(checkOut)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton.filled(
                  onPressed:
                      _canIncreaseDuration ? _increaseDuration : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),
        if (checkIn == null) ...[
          const SizedBox(height: 10),
          Text(
            'Ngày này không còn giờ phù hợp.',
            style: TextStyle(
              color: colors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ] else if (!_canIncreaseDuration) ...[
          const SizedBox(height: 8),
          Text(
            'Không thể tăng thêm vì khung giờ tiếp theo '
            'đã được đặt hoặc đã đạt giới hạn.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _HourTile extends StatelessWidget {
  const _HourTile({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final background = selected
        ? colors.primary
        : enabled
        ? colors.surfaceContainerHighest
        : colors.errorContainer.withValues(alpha: 0.45);

    final foreground = selected
        ? colors.onPrimary
        : enabled
        ? colors.onSurfaceVariant
        : colors.error.withValues(alpha: 0.65);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(7),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              decoration:
                  enabled ? null : TextDecoration.lineThrough,
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

String _hourLabel(int hour) {
  return '${hour.toString().padLeft(2, '0')}:00';
}

String _dateLabel(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';
}

String _dateTimeLabel(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:00';
}