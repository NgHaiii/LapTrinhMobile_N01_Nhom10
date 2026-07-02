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
    this.initialCheckOut,
    this.initialDurationHours = 1,
    this.maxDurationHours = 720,
  });

  final List<RoomReservation> reservations;
  final ValueChanged<HourlyBookingSelection?> onChanged;

  final DateTime? initialCheckIn;
  final DateTime? initialCheckOut;

  /// Giữ tương thích với code cũ.
  final int initialDurationHours;

  /// Mặc định tối đa 30 ngày.
  final int maxDurationHours;

  @override
  State<HourlyBookingPicker> createState() =>
      _HourlyBookingPickerState();
}

class _HourlyBookingPickerState
    extends State<HourlyBookingPicker> {
  late DateTime _checkInDate;
  late DateTime _checkOutDate;

  int? _checkInHour;
  int? _checkOutHour;

  @override
  void initState() {
    super.initState();

    final suppliedCheckIn = widget.initialCheckIn;

    final initialCheckIn =
        suppliedCheckIn != null &&
            suppliedCheckIn.isAfter(DateTime.now())
        ? _wholeHour(suppliedCheckIn)
        : _nextWholeHour(DateTime.now());

    final fallbackDuration =
        widget.initialDurationHours.clamp(
          1,
          widget.maxDurationHours,
        );

    final suppliedCheckOut = widget.initialCheckOut;

    final initialCheckOut =
        suppliedCheckOut != null &&
            suppliedCheckOut.isAfter(initialCheckIn)
        ? _wholeHour(suppliedCheckOut)
        : initialCheckIn.add(
            Duration(hours: fallbackDuration),
          );

    _checkInDate = _dateOnly(initialCheckIn);
    _checkOutDate = _dateOnly(initialCheckOut);
    _checkInHour = initialCheckIn.hour;
    _checkOutHour = initialCheckOut.hour;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _normalizeSelection();
    });
  }

  @override
  void didUpdateWidget(
    HourlyBookingPicker oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.reservations !=
        widget.reservations) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _normalizeSelection();
      });
    }
  }

  DateTime? get _checkIn {
    final hour = _checkInHour;
    if (hour == null) return null;

    return DateTime(
      _checkInDate.year,
      _checkInDate.month,
      _checkInDate.day,
      hour,
    );
  }

  DateTime? get _checkOut {
    final hour = _checkOutHour;
    if (hour == null) return null;

    return DateTime(
      _checkOutDate.year,
      _checkOutDate.month,
      _checkOutDate.day,
      hour,
    );
  }

  int get _durationHours {
    final checkIn = _checkIn;
    final checkOut = _checkOut;

    if (checkIn == null ||
        checkOut == null ||
        !checkOut.isAfter(checkIn)) {
      return 0;
    }

    return checkOut.difference(checkIn).inHours;
  }

  Future<DateTime?> _showVietnameseDatePicker({
    required String title,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required bool Function(DateTime)
    selectableDayPredicate,
  }) {
    return showDatePicker(
      context: context,
      locale: const Locale('vi', 'VN'),
      helpText: title,
      cancelText: 'Hủy',
      confirmText: 'Chọn ngày',
      fieldLabelText: 'Nhập ngày',
      fieldHintText: 'dd/mm/yyyy',
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate:
          selectableDayPredicate,
      initialEntryMode:
          DatePickerEntryMode.calendarOnly,
      initialDatePickerMode: DatePickerMode.day,
      builder: (pickerContext, child) {
        final theme = Theme.of(pickerContext);
        final colors = theme.colorScheme;

        return Theme(
          data: theme.copyWith(
            colorScheme: colors.copyWith(
              primary: colors.primary,
              onPrimary: colors.onPrimary,
              surface: colors.surface,
              onSurface: colors.onSurface,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: colors.surface,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor:
                  colors.primaryContainer,
              headerForegroundColor:
                  colors.onPrimaryContainer,
              headerHeadlineStyle: theme
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
              headerHelpStyle: theme
                  .textTheme
                  .labelLarge
                  ?.copyWith(
                    color:
                        colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
              weekdayStyle: theme
                  .textTheme
                  .labelMedium
                  ?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
              dayStyle: theme.textTheme.bodyMedium
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(8),
              ),
              todayBorder: BorderSide(
                color: colors.primary,
                width: 1.5,
              ),
              cancelButtonStyle:
                  TextButton.styleFrom(
                    foregroundColor:
                        colors.onSurfaceVariant,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              confirmButtonStyle:
                  TextButton.styleFrom(
                    foregroundColor:
                        colors.primary,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Future<void> _selectCheckInDate() async {
    final today = _dateOnly(DateTime.now());
    final lastDate = today.add(
      const Duration(days: 730),
    );

    final preferredDate =
        _checkInDate.isBefore(today) ||
            _checkInDate.isAfter(lastDate)
        ? today
        : _checkInDate;

    final initialDate = _findAvailableCheckInDate(
      preferredDate: preferredDate,
      firstDate: today,
      lastDate: lastDate,
    );

    if (initialDate == null) {
      _message(
        'Không còn ngày nhận phòng phù hợp.',
      );
      return;
    }

    final result =
        await _showVietnameseDatePicker(
          title: 'Chọn ngày nhận phòng',
          initialDate: initialDate,
          firstDate: today,
          lastDate: lastDate,
          selectableDayPredicate:
              _hasAvailableCheckInOnDate,
        );

    if (!mounted || result == null) return;

    final oldCheckOut = _checkOut;

    final firstHour = _firstAvailableCheckInHour(
      result,
    );

    if (firstHour == null) {
      _message(
        'Ngày này không còn giờ nhận phòng.',
      );
      return;
    }

    setState(() {
      _checkInDate = _dateOnly(result);
      _checkInHour = firstHour;

      // Giữ lại ngày/giờ trả cũ để kiểm tra
      // sau khi giờ nhận thay đổi.
      if (oldCheckOut != null) {
        _checkOutDate = _dateOnly(oldCheckOut);
        _checkOutHour = oldCheckOut.hour;
      }
    });

    _preserveOrSuggestCheckOut();
  }

  Future<void> _selectCheckOutDate() async {
    final checkIn = _checkIn;

    if (checkIn == null) {
      _message(
        'Vui lòng chọn giờ nhận phòng trước.',
      );
      return;
    }

    final firstDate = _dateOnly(checkIn);

    final lastDate = firstDate.add(
      Duration(
        days:
            (widget.maxDurationHours / 24).ceil(),
      ),
    );

    final preferredDate =
        !_checkOutDate.isBefore(firstDate) &&
            !_checkOutDate.isAfter(lastDate)
        ? _checkOutDate
        : firstDate;

    final initialDate = _findAvailableCheckOutDate(
      preferredDate: preferredDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (initialDate == null) {
      _message(
        'Không còn ngày trả phòng phù hợp với '
        'giờ nhận đã chọn.',
      );
      return;
    }

    final result =
        await _showVietnameseDatePicker(
          title: 'Chọn ngày trả phòng',
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          selectableDayPredicate:
              _hasAvailableCheckOutOnDate,
        );

    if (!mounted || result == null) return;

    final selectedDate = _dateOnly(result);

    // Nếu khách chọn lại đúng ngày trả hiện tại
    // và giờ trả cũ vẫn hợp lệ thì giữ nguyên giờ.
    final currentCheckOut = _checkOut;

    if (currentCheckOut != null &&
        _sameDate(
          selectedDate,
          _dateOnly(currentCheckOut),
        ) &&
        _isCheckOutAvailable(currentCheckOut)) {
      setState(
        () => _checkOutDate = selectedDate,
      );

      _notify();
      return;
    }

    final firstHour =
        _firstAvailableCheckOutHour(selectedDate);

    if (firstHour == null) {
      _message(
        'Ngày này không còn giờ trả phòng hợp lệ.',
      );
      return;
    }

    setState(() {
      _checkOutDate = selectedDate;
      _checkOutHour = firstHour;
    });

    _notify();
  }

  void _selectCheckInHour(int hour) {
    final value = DateTime(
      _checkInDate.year,
      _checkInDate.month,
      _checkInDate.day,
      hour,
    );

    if (!_isCheckInHourAvailable(value)) return;

    setState(() => _checkInHour = hour);

    // Không tự đổi ngày trả nếu ngày/giờ trả
    // hiện tại vẫn còn hợp lệ.
    _preserveOrSuggestCheckOut();
  }

  void _selectCheckOutHour(int hour) {
    final value = DateTime(
      _checkOutDate.year,
      _checkOutDate.month,
      _checkOutDate.day,
      hour,
    );

    if (!_isCheckOutAvailable(value)) return;

    setState(() => _checkOutHour = hour);
    _notify();
  }

  void _preserveOrSuggestCheckOut() {
    final currentCheckOut = _checkOut;

    if (currentCheckOut != null &&
        _isCheckOutAvailable(currentCheckOut)) {
      _notify();
      return;
    }

    _setSuggestedCheckOut();
  }

  void _setSuggestedCheckOut() {
    final checkIn = _checkIn;

    if (checkIn == null) {
      if (mounted) {
        setState(() => _checkOutHour = null);
      }

      widget.onChanged(null);
      return;
    }

    DateTime? suggestion;

    for (var hours = 1;
        hours <= widget.maxDurationHours;
        hours++) {
      final candidate = checkIn.add(
        Duration(hours: hours),
      );

      if (_isCheckOutAvailable(candidate)) {
        suggestion = candidate;
        break;
      }
    }

    if (!mounted) return;

    setState(() {
      if (suggestion == null) {
        _checkOutDate = _dateOnly(checkIn);
        _checkOutHour = null;
      } else {
        _checkOutDate = _dateOnly(suggestion);
        _checkOutHour = suggestion.hour;
      }
    });

    _notify();
  }

  void _normalizeSelection() {
    var checkInHour = _checkInHour;

    if (checkInHour == null ||
        !_isCheckInHourAvailable(
          DateTime(
            _checkInDate.year,
            _checkInDate.month,
            _checkInDate.day,
            checkInHour,
          ),
        )) {
      checkInHour = _firstAvailableCheckInHour(
        _checkInDate,
      );
    }

    if (!mounted) return;

    setState(() => _checkInHour = checkInHour);

    _preserveOrSuggestCheckOut();
  }

  bool _hasAvailableCheckInOnDate(
    DateTime date,
  ) {
    final normalizedDate = _dateOnly(date);

    for (var hour = 0; hour < 24; hour++) {
      final value = DateTime(
        normalizedDate.year,
        normalizedDate.month,
        normalizedDate.day,
        hour,
      );

      if (_isCheckInHourAvailable(value)) {
        return true;
      }
    }

    return false;
  }

  bool _hasAvailableCheckOutOnDate(
    DateTime date,
  ) {
    final normalizedDate = _dateOnly(date);

    for (var hour = 0; hour < 24; hour++) {
      final candidate = DateTime(
        normalizedDate.year,
        normalizedDate.month,
        normalizedDate.day,
        hour,
      );

      if (_isCheckOutAvailable(candidate)) {
        return true;
      }
    }

    return false;
  }

  DateTime? _findAvailableCheckInDate({
    required DateTime preferredDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    var candidate = _dateOnly(preferredDate);

    while (!candidate.isAfter(lastDate)) {
      if (_hasAvailableCheckInOnDate(candidate)) {
        return candidate;
      }

      candidate = candidate.add(
        const Duration(days: 1),
      );
    }

    candidate = _dateOnly(firstDate);

    while (candidate.isBefore(preferredDate)) {
      if (_hasAvailableCheckInOnDate(candidate)) {
        return candidate;
      }

      candidate = candidate.add(
        const Duration(days: 1),
      );
    }

    return null;
  }

  DateTime? _findAvailableCheckOutDate({
    required DateTime preferredDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    var candidate = _dateOnly(preferredDate);

    while (!candidate.isAfter(lastDate)) {
      if (_hasAvailableCheckOutOnDate(candidate)) {
        return candidate;
      }

      candidate = candidate.add(
        const Duration(days: 1),
      );
    }

    candidate = _dateOnly(firstDate);

    while (candidate.isBefore(preferredDate)) {
      if (_hasAvailableCheckOutOnDate(candidate)) {
        return candidate;
      }

      candidate = candidate.add(
        const Duration(days: 1),
      );
    }

    return null;
  }

  int? _firstAvailableCheckInHour(
    DateTime date,
  ) {
    for (var hour = 0; hour < 24; hour++) {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
      );

      if (_isCheckInHourAvailable(value)) {
        return hour;
      }
    }

    return null;
  }

  int? _firstAvailableCheckOutHour(
    DateTime date,
  ) {
    for (var hour = 0; hour < 24; hour++) {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
      );

      if (_isCheckOutAvailable(value)) {
        return hour;
      }
    }

    return null;
  }

  bool _isCheckInHourAvailable(
    DateTime value,
  ) {
    if (!value.isAfter(DateTime.now())) {
      return false;
    }

    return !_isOccupied(
      value,
      value.add(const Duration(hours: 1)),
    );
  }

  bool _isCheckOutAvailable(
    DateTime candidate,
  ) {
    final checkIn = _checkIn;

    if (checkIn == null ||
        !candidate.isAfter(checkIn)) {
      return false;
    }

    final duration =
        candidate.difference(checkIn);

    if (duration.inMinutes % 60 != 0 ||
        duration.inHours < 1 ||
        duration.inHours >
            widget.maxDurationHours) {
      return false;
    }

    return !_isOccupied(checkIn, candidate);
  }

  bool _isOccupied(
    DateTime start,
    DateTime end,
  ) {
    return widget.reservations.any(
      (reservation) =>
          reservation.overlaps(start, end),
    );
  }

  bool _checkOutBlockedByReservation(
    DateTime candidate,
  ) {
    final checkIn = _checkIn;

    if (checkIn == null ||
        !candidate.isAfter(checkIn)) {
      return false;
    }

    return _isOccupied(checkIn, candidate);
  }

  void _notify() {
    final checkIn = _checkIn;
    final checkOut = _checkOut;

    if (checkIn == null ||
        checkOut == null ||
        !_isCheckOutAvailable(checkOut)) {
      widget.onChanged(null);
      return;
    }

    widget.onChanged(
      HourlyBookingSelection(
        checkIn: checkIn,
        checkOut: checkOut,
        durationHours:
            checkOut.difference(checkIn).inHours,
      ),
    );
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(value)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final checkIn = _checkIn;
    final checkOut = _checkOut;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          number: 1,
          title: 'Thời gian nhận phòng',
        ),
        const SizedBox(height: 9),
        _DateTile(
          icon: Icons.login_rounded,
          label: 'Ngày nhận phòng',
          value: _dateLabel(_checkInDate),
          onTap: _selectCheckInDate,
        ),
        const SizedBox(height: 16),
        const Text(
          'Giờ nhận phòng',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Các giờ màu đỏ đã có khách đặt.',
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        _HourGrid(
          selectedHour: _checkInHour,
          enabled: (hour) {
            return _isCheckInHourAvailable(
              DateTime(
                _checkInDate.year,
                _checkInDate.month,
                _checkInDate.day,
                hour,
              ),
            );
          },
          blocked: (hour) {
            final start = DateTime(
              _checkInDate.year,
              _checkInDate.month,
              _checkInDate.day,
              hour,
            );

            return _isOccupied(
              start,
              start.add(
                const Duration(hours: 1),
              ),
            );
          },
          onSelected: _selectCheckInHour,
        ),
        const SizedBox(height: 26),
        const _SectionTitle(
          number: 2,
          title: 'Thời gian trả phòng',
        ),
        const SizedBox(height: 9),
        _DateTile(
          icon: Icons.logout_rounded,
          label: 'Ngày trả phòng',
          value: _dateLabel(_checkOutDate),
          onTap: _selectCheckOutDate,
          enabled: checkIn != null,
        ),
        const SizedBox(height: 16),
        const Text(
          'Giờ trả phòng',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Ngày và giờ không phù hợp sẽ bị khóa.',
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        _HourGrid(
          selectedHour: _checkOutHour,
          enabled: (hour) {
            return _isCheckOutAvailable(
              DateTime(
                _checkOutDate.year,
                _checkOutDate.month,
                _checkOutDate.day,
                hour,
              ),
            );
          },
          blocked: (hour) {
            return _checkOutBlockedByReservation(
              DateTime(
                _checkOutDate.year,
                _checkOutDate.month,
                _checkOutDate.day,
                hour,
              ),
            );
          },
          onSelected: _selectCheckOutHour,
        ),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _Legend(
              color: Colors.teal,
              label: 'Đang chọn',
            ),
            _Legend(
              color: Colors.grey,
              label: 'Có thể chọn',
            ),
            _Legend(
              color: Colors.redAccent,
              label: 'Đã được đặt',
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (checkIn != null &&
            checkOut != null &&
            _isCheckOutAvailable(checkOut))
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  color: colors.onPrimaryContainer,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thời gian lưu trú',
                        style: TextStyle(
                          color:
                              colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$_durationHours giờ',
                        style: TextStyle(
                          color:
                              colors.onPrimaryContainer,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${_dateTimeLabel(checkIn)} - '
                        '${_dateTimeLabel(checkOut)}',
                        style: TextStyle(
                          color:
                              colors.onPrimaryContainer,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            'Vui lòng chọn đầy đủ ngày và giờ '
            'nhận/trả phòng.',
            style: TextStyle(
              color: colors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _HourGrid extends StatelessWidget {
  const _HourGrid({
    required this.selectedHour,
    required this.enabled,
    required this.blocked,
    required this.onSelected,
  });

  final int? selectedHour;
  final bool Function(int hour) enabled;
  final bool Function(int hour) blocked;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 560 ? 8 : 4;

        return GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          itemCount: 24,
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 46,
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
              ),
          itemBuilder: (context, hour) {
            return _HourTile(
              label: _hourLabel(hour),
              selected: selectedHour == hour,
              enabled: enabled(hour),
              blocked: blocked(hour),
              onTap: () => onSelected(hour),
            );
          },
        );
      },
    );
  }
}

class _HourTile extends StatelessWidget {
  const _HourTile({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.blocked,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final bool blocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final background = selected
        ? colors.primary
        : blocked
        ? colors.errorContainer
        : enabled
        ? colors.surfaceContainerHighest
        : colors.surfaceContainerLow;

    final foreground = selected
        ? colors.onPrimary
        : blocked
        ? colors.error
        : enabled
        ? colors.onSurface
        : colors.outline;

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
              decoration: blocked
                  ? TextDecoration.lineThrough
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        enabled: enabled,
        onTap: enabled ? onTap : null,
        leading: Icon(
          icon,
          color: enabled
              ? colors.primary
              : colors.outline,
        ),
        title: Text(label),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.number,
    required this.title,
  });

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          child: Text(
            '$number',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 9),
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
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

DateTime _dateOnly(DateTime value) {
  return DateTime(
    value.year,
    value.month,
    value.day,
  );
}

DateTime _wholeHour(DateTime value) {
  final result = DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
  );

  if (value.minute > 0 ||
      value.second > 0 ||
      value.millisecond > 0 ||
      value.microsecond > 0) {
    return result.add(
      const Duration(hours: 1),
    );
  }

  return result;
}

DateTime _nextWholeHour(DateTime value) {
  return DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
  ).add(const Duration(hours: 1));
}

bool _sameDate(
  DateTime first,
  DateTime second,
) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
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
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year} '
      '${value.hour.toString().padLeft(2, '0')}:00';
}