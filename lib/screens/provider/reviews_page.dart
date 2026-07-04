import 'package:flutter/material.dart';

import '../../model/review.dart';
import '../../services/review_service.dart';
import '../customer/widgets/review_card.dart';

class ProviderReviewsPage extends StatefulWidget {
  const ProviderReviewsPage({
    super.key,
    required this.service,
  });

  final ReviewService service;

  @override
  State<ProviderReviewsPage> createState() =>
      _ProviderReviewsPageState();
}

class _ProviderReviewsPageState
    extends State<ProviderReviewsPage> {
  final _searchController = TextEditingController();

  String _search = '';
  String _filter = 'all';
  String? _processingId;

  Future<void> _reply(ReviewModel review) async {
    final controller = TextEditingController(
      text: review.providerReply,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.reply_outlined),
        title: Text(
          review.hasProviderReply
              ? 'Chỉnh sửa phản hồi'
              : 'Phản hồi khách hàng',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          maxLength: 1000,
          textCapitalization:
              TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nội dung phản hồi',
            hintText:
                'Cảm ơn khách hàng hoặc giải trình vấn đề...',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            onPressed: () {
              final value = controller.text.trim();

              if (value.length < 2) return;

              Navigator.pop(
                dialogContext,
                value,
              );
            },
            icon: const Icon(Icons.send_outlined),
            label: const Text('Gửi'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (!mounted || result == null) return;

    setState(() => _processingId = review.id);

    try {
      await widget.service.replyToReview(
        reviewId: review.id,
        reply: result,
      );

      if (!mounted) return;
      _message('Đã gửi phản hồi.');
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _processingId = null);
      }
    }
  }

  Future<void> _removeReply(
    ReviewModel review,
  ) async {
    setState(() => _processingId = review.id);

    try {
      await widget.service.removeProviderReply(
        review.id,
      );

      if (!mounted) return;
      _message('Đã xóa phản hồi.');
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _processingId = null);
      }
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReviewModel>>(
      stream: widget.service.watchProviderReviews(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _EmptyReviews(
            title: 'Không thể tải đánh giá',
            message: _cleanError(snapshot.error),
          );
        }

        final allReviews = snapshot.data ?? [];

        final reviews = allReviews.where((review) {
          final keyword =
              _search.trim().toLowerCase();

          final matchesSearch = keyword.isEmpty ||
              review.hotelName
                  .toLowerCase()
                  .contains(keyword) ||
              review.roomNumber
                  .toLowerCase()
                  .contains(keyword) ||
              review.customerName
                  .toLowerCase()
                  .contains(keyword) ||
              review.comment
                  .toLowerCase()
                  .contains(keyword);

          final matchesFilter = switch (_filter) {
            'admin_action' =>
              review.providerActionRequired,
            'unanswered' =>
              !review.hasProviderReply,
            'critical' =>
              review.severity ==
                  ReviewSeverity.critical,
            'low' => review.rating <= 2,
            _ => true,
          };

          return matchesSearch && matchesFilter;
        }).toList()
          ..sort(_compareReviews);

        return Column(
          children: [
            Material(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  12,
                ),
                child: Column(
                  children: [
                    SearchBar(
                      controller: _searchController,
                      hintText:
                          'Tìm khách sạn, phòng, khách hàng...',
                      leading: const Icon(
                        Icons.search_rounded,
                      ),
                      onChanged: (value) {
                        setState(() => _search = value);
                      },
                      trailing: [
                        if (_search.isNotEmpty)
                          IconButton(
                            tooltip: 'Xóa tìm kiếm',
                            onPressed: () {
                              _searchController.clear();
                              setState(
                                () => _search = '',
                              );
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection:
                            Axis.horizontal,
                        children: [
                          _FilterChip(
                            label: 'Tất cả',
                            selected:
                                _filter == 'all',
                            onTap: () {
                              setState(
                                () => _filter = 'all',
                              );
                            },
                          ),
                          _FilterChip(
                            label:
                                'Admin yêu cầu xử lý',
                            selected: _filter ==
                                'admin_action',
                            warning: true,
                            onTap: () {
                              setState(
                                () => _filter =
                                    'admin_action',
                              );
                            },
                          ),
                          _FilterChip(
                            label: 'Chưa phản hồi',
                            selected: _filter ==
                                'unanswered',
                            onTap: () {
                              setState(
                                () => _filter =
                                    'unanswered',
                              );
                            },
                          ),
                          _FilterChip(
                            label: 'Nghiêm trọng',
                            selected: _filter ==
                                'critical',
                            warning: true,
                            onTap: () {
                              setState(
                                () => _filter =
                                    'critical',
                              );
                            },
                          ),
                          _FilterChip(
                            label: '1–2 sao',
                            selected:
                                _filter == 'low',
                            onTap: () {
                              setState(
                                () => _filter = 'low',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: reviews.isEmpty
                  ? const _EmptyReviews(
                      title: 'Không có đánh giá',
                      message:
                          'Đánh giá phòng của khách hàng sẽ xuất hiện tại đây.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        14,
                        16,
                        32,
                      ),
                      itemCount: reviews.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final review = reviews[index];

                        return Column(
                          children: [
                            if (review
                                .providerActionRequired)
                              _AdminRequestBanner(
                                review: review,
                              ),
                            CustomerReviewCard(
                              review: review,
                              showHotelName: true,
                              footer: Align(
                                alignment:
                                    Alignment.centerRight,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (review
                                        .hasProviderReply)
                                      TextButton.icon(
                                        onPressed:
                                            _processingId ==
                                                    review.id
                                                ? null
                                                : () =>
                                                    _removeReply(
                                                      review,
                                                    ),
                                        icon: const Icon(
                                          Icons
                                              .delete_outline,
                                        ),
                                        label: const Text(
                                          'Xóa phản hồi',
                                        ),
                                      ),
                                    FilledButton.tonalIcon(
                                      onPressed:
                                          _processingId ==
                                                  review.id
                                              ? null
                                              : () =>
                                                  _reply(
                                                    review,
                                                  ),
                                      icon:
                                          _processingId ==
                                                  review.id
                                              ? const SizedBox.square(
                                                  dimension:
                                                      17,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth:
                                                        2,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons
                                                      .reply_outlined,
                                                ),
                                      label: Text(
                                        review
                                                .hasProviderReply
                                            ? 'Sửa phản hồi'
                                            : 'Phản hồi',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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

class _AdminRequestBanner extends StatelessWidget {
  const _AdminRequestBanner({
    required this.review,
  });

  final ReviewModel review;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.error),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.priority_high_rounded,
            color: colors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin yêu cầu xử lý',
                  style: TextStyle(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (review.adminNote.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    review.adminNote,
                    style: TextStyle(
                      color: colors.onErrorContainer,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.warning = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        avatar: warning
            ? const Icon(
                Icons.warning_amber_rounded,
                size: 17,
              )
            : null,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 58,
              color: colors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _compareReviews(
  ReviewModel first,
  ReviewModel second,
) {
  final action = (second.providerActionRequired ? 1 : 0)
      .compareTo(
    first.providerActionRequired ? 1 : 0,
  );

  if (action != 0) return action;

  final severity = _priority(second.severity)
      .compareTo(_priority(first.severity));

  if (severity != 0) return severity;

  final firstDate =
      first.updatedAt ??
      first.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  final secondDate =
      second.updatedAt ??
      second.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  return secondDate.compareTo(firstDate);
}

int _priority(String severity) {
  return switch (severity) {
    ReviewSeverity.critical => 4,
    ReviewSeverity.high => 3,
    ReviewSeverity.warning => 2,
    _ => 1,
  };
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}