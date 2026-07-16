import 'dart:async';

import 'package:flutter/material.dart';

import '../../../model/booking.dart';
import '../../../model/review.dart';
import '../../../services/review_service.dart';
class ReviewFormScreen extends StatefulWidget {
  const ReviewFormScreen({
    super.key,
    required this.service,
    required this.booking,
  });

  final ReviewService service;
  final BookingModel booking;

  @override
  State<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends State<ReviewFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();

  StreamSubscription<ReviewModel?>? _subscription;

  ReviewModel? _existingReview;
  int _rating = 5;

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  BookingModel get booking => widget.booking;

  bool get _canReview {
    return booking.status == BookingStatus.completed;
  }

  bool get _editing => _existingReview != null;

  @override
  void initState() {
    super.initState();
    _watchExistingReview();
  }

  void _watchExistingReview() {
    _subscription = widget.service
        .watchBookingReview(booking.id)
        .listen(
          (review) {
            if (!mounted) return;

            setState(() {
              _existingReview = review;

              if (review != null) {
                _rating = review.rating;
                _commentController.text = review.comment;
              }

              _loading = false;
              _loadError = null;
            });
          },
          onError: (Object error) {
            if (!mounted) return;

            setState(() {
              _loading = false;
              _loadError = _cleanError(error);
            });
          },
        );
  }

  Future<void> _submit() async {
    if (_saving || !_canReview) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      final existingReview = _existingReview;

      if (existingReview == null) {
        await widget.service.createReview(
          booking: booking,
          rating: _rating,
          comment: _commentController.text,
        );
      } else {
        await widget.service.updateReview(
          reviewId: existingReview.id,
          rating: _rating,
          comment: _commentController.text,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingReview == null
                ? 'Đã gửi đánh giá phòng.'
                : 'Đã cập nhật đánh giá.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() => _saving = false);
      _message(_cleanError(error));
    }
  }

  String? _validateComment(String? value) {
    final comment = value?.trim() ?? '';

    if (comment.length < 5) {
      return 'Nội dung đánh giá phải có ít nhất 5 ký tự';
    }

    if (comment.length > 1500) {
      return 'Nội dung không được vượt quá 1500 ký tự';
    }

    return null;
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Chỉnh sửa đánh giá' : 'Đánh giá phòng'),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildSubmitButton(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return _ReviewMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Không thể tải đánh giá',
        message: _loadError!,
      );
    }

    if (!_canReview) {
      return const _ReviewMessage(
        icon: Icons.lock_clock_outlined,
        title: 'Chưa thể đánh giá',
        message:
            'Bạn chỉ có thể đánh giá phòng sau khi đơn đặt phòng hoàn thành.',
      );
    }

    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          child: const Icon(Icons.bed_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.hotelName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${booking.roomType} · '
                                'Phòng ${booking.roomNumber}',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_dateTime(booking.checkIn)} - '
                                '${_dateTime(booking.checkOut)}',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'Trải nghiệm của bạn thế nào?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Đánh giá này dành riêng cho phòng '
                  '${booking.roomNumber}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                _StarPicker(
                  value: _rating,
                  enabled: !_saving,
                  onChanged: (value) {
                    setState(() => _rating = value);
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  _ratingLabel(_rating),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ratingColor(_rating),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 26),
                TextFormField(
                  controller: _commentController,
                  enabled: !_saving,
                  minLines: 5,
                  maxLines: 10,
                  maxLength: 1500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nhận xét về phòng',
                    hintText:
                        'Độ sạch sẽ, tiện nghi, hình ảnh thực tế, '
                        'chất lượng phục vụ...',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 92),
                      child: Icon(Icons.rate_review_outlined),
                    ),
                  ),
                  validator: _validateComment,
                ),
                if (_existingReview?.hasProviderReply == true) ...[
                  const SizedBox(height: 18),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.storefront_outlined,
                                color: colors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 7),
                              const Text(
                                'Phản hồi từ nhà cung cấp',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          Text(
                            _existingReview!.providerReply,
                            style: const TextStyle(height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildSubmitButton() {
    if (_loading || _loadError != null || !_canReview) {
      return null;
    }

    return SafeArea(
      child: Material(
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _editing
                        ? Icons.save_outlined
                        : Icons.send_outlined,
                  ),
            label: Text(
              _saving
                  ? 'Đang lưu...'
                  : _editing
                      ? 'Cập nhật đánh giá'
                      : 'Gửi đánh giá',
            ),
          ),
        ),
      ),
    );
  }
}

class _StarPicker extends StatelessWidget {
  const _StarPicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final rating = index + 1;
        final selected = rating <= value;

        return IconButton(
          tooltip: '$rating sao',
          onPressed: enabled ? () => onChanged(rating) : null,
          iconSize: 40,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          icon: Icon(
            selected ? Icons.star_rounded : Icons.star_border_rounded,
            color: selected ? Colors.amber.shade700 : Colors.grey,
          ),
        );
      }),
    );
  }
}

class _ReviewMessage extends StatelessWidget {
  const _ReviewMessage({
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: colors.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _ratingLabel(int rating) {
  return switch (rating) {
    1 => 'Rất không hài lòng',
    2 => 'Chưa hài lòng',
    3 => 'Bình thường',
    4 => 'Hài lòng',
    5 => 'Rất hài lòng',
    _ => '',
  };
}

Color _ratingColor(int rating) {
  return switch (rating) {
    1 || 2 => Colors.red,
    3 => Colors.orange,
    _ => Colors.green,
  };
}

String _dateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');

  return '$hour:$minute $day/$month/${value.year}';
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}