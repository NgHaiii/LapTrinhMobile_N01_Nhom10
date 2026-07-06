import 'package:flutter/material.dart';

import '../../model/review.dart';
import '../../services/review_service.dart';
import '../customer/widgets/review_card.dart';
import 'violation_details_page.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reply(ReviewModel review) async {
    if (_processingId != null) return;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => _ProviderReplyDialog(
        initialValue: review.providerReply,
        editing: review.hasProviderReply,
      ),
    );

    if (!mounted || result == null) return;

    setState(() => _processingId = review.id);

    try {
      await widget.service.replyToReview(
        reviewId: review.id,
        reply: result,
      );

      if (!mounted) return;

      _showMessage(
        review.hasProviderReply
            ? 'Đã cập nhật phản hồi.'
            : 'Đã gửi phản hồi.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _processingId = null);
      }
    }
  }

  Future<void> _removeReply(ReviewModel review) async {
    if (_processingId != null) return;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.delete_outline),
          title: const Text('Xóa phản hồi?'),
          content: const Text(
            'Phản hồi của nhà cung cấp sẽ bị xóa khỏi '
            'đánh giá này.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Xóa phản hồi'),
            ),
          ],
        );
      },
    );

    if (!mounted || accepted != true) return;

    setState(() => _processingId = review.id);

    try {
      await widget.service.removeProviderReply(review.id);

      if (!mounted) return;
      _showMessage('Đã xóa phản hồi.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _processingId = null);
      }
    }
  }

  Future<void> _openViolation(
    ReviewModel review,
  ) async {
    final violationId = review.violationRecordId.trim();

    if (violationId.isEmpty) {
      _showMessage(
        'Đánh giá này chưa có biên bản vi phạm.',
      );
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProviderViolationDetailsPage(
          violationId: violationId,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

        final reviews = allReviews.where(_matchesFilter).toList()
          ..sort(_compareReviews);

        return CustomScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(
                allReviews: allReviews,
                resultCount: reviews.length,
              ),
            ),
            if (reviews.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyReviews(
                  title: 'Không có đánh giá',
                  message:
                      'Đánh giá phòng của khách hàng sẽ xuất hiện tại đây.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  32,
                ),
                sliver: SliverList.separated(
                  itemCount: reviews.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildReviewItem(reviews[index]);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader({
    required List<ReviewModel> allReviews,
    required int resultCount,
  }) {
    final colors = Theme.of(context).colorScheme;

    final needsAction = allReviews.where((review) {
      return review.providerActionRequired;
    }).length;

    final unanswered = allReviews.where((review) {
      return review.isPublished &&
          !review.hasProviderReply;
    }).length;

    final violations = allReviews.where((review) {
      return review.hasViolationRecord;
    }).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  icon: Icons.pending_actions_outlined,
                  label: 'Cần xử lý',
                  value: needsAction,
                  color: const Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.reply_outlined,
                  label: 'Chưa phản hồi',
                  value: unanswered,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.gavel_outlined,
                  label: 'Biên bản',
                  value: violations,
                  color: colors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SearchBar(
            controller: _searchController,
            hintText: 'Tìm khách sạn, phòng, khách hàng...',
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
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'Tất cả',
                  selected: _filter == 'all',
                  onTap: () {
                    setState(() => _filter = 'all');
                  },
                ),
                _FilterChip(
                  label: 'Admin yêu cầu',
                  selected: _filter == 'admin_action',
                  warning: true,
                  onTap: () {
                    setState(
                      () => _filter = 'admin_action',
                    );
                  },
                ),
                _FilterChip(
                  label: 'Chưa phản hồi',
                  selected: _filter == 'unanswered',
                  onTap: () {
                    setState(
                      () => _filter = 'unanswered',
                    );
                  },
                ),
                _FilterChip(
                  label: 'Có biên bản',
                  selected: _filter == 'violation',
                  warning: true,
                  onTap: () {
                    setState(
                      () => _filter = 'violation',
                    );
                  },
                ),
                _FilterChip(
                  label: 'Nghiêm trọng',
                  selected: _filter == 'critical',
                  warning: true,
                  onTap: () {
                    setState(
                      () => _filter = 'critical',
                    );
                  },
                ),
                _FilterChip(
                  label: '1-2 sao',
                  selected: _filter == 'low',
                  onTap: () {
                    setState(() => _filter = 'low');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$resultCount đánh giá phù hợp',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(ReviewModel review) {
    final processing = _processingId == review.id;

    return Column(
      children: [
        if (review.providerActionRequired ||
            review.hasViolationRecord)
          _AdminRequestBanner(review: review),
        CustomerReviewCard(
          review: review,
          showHotelName: true,
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (processing) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 10),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (review.hasViolationRecord)
                    OutlinedButton.icon(
                      onPressed: processing
                          ? null
                          : () => _openViolation(review),
                      icon: const Icon(Icons.gavel_outlined),
                      label: const Text(
                        'Xem biên bản',
                      ),
                    ),
                  if (review.hasProviderReply)
                    TextButton.icon(
                      onPressed: processing
                          ? null
                          : () => _removeReply(review),
                      icon: const Icon(
                        Icons.delete_outline,
                      ),
                      label: const Text('Xóa phản hồi'),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: processing
                        ? null
                        : () => _reply(review),
                    icon: const Icon(Icons.reply_outlined),
                    label: Text(
                      review.hasProviderReply
                          ? 'Sửa phản hồi'
                          : 'Phản hồi',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _matchesFilter(ReviewModel review) {
    final keyword = _search.trim().toLowerCase();

    final matchesSearch = keyword.isEmpty ||
        review.hotelName.toLowerCase().contains(keyword) ||
        review.roomNumber.toLowerCase().contains(keyword) ||
        review.customerName.toLowerCase().contains(keyword) ||
        review.comment.toLowerCase().contains(keyword);

    final matchesFilter = switch (_filter) {
      'admin_action' => review.providerActionRequired,
      'unanswered' => !review.hasProviderReply,
      'violation' => review.hasViolationRecord,
      'critical' =>
        review.severity == ReviewSeverity.critical,
      'low' => review.rating <= 2,
      _ => true,
    };

    return matchesSearch && matchesFilter;
  }
}

class _ProviderReplyDialog extends StatefulWidget {
  const _ProviderReplyDialog({
    required this.initialValue,
    required this.editing,
  });

  final String initialValue;
  final bool editing;

  @override
  State<_ProviderReplyDialog> createState() =>
      _ProviderReplyDialogState();
}

class _ProviderReplyDialogState
    extends State<_ProviderReplyDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();

    if (value.length < 2) {
      setState(() {
        _error =
            'Phản hồi phải có ít nhất 2 ký tự.';
      });
      return;
    }

    if (value.length > 1000) {
      setState(() {
        _error =
            'Phản hồi không được vượt quá 1000 ký tự.';
      });
      return;
    }

    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.reply_outlined),
      title: Text(
        widget.editing
            ? 'Chỉnh sửa phản hồi'
            : 'Phản hồi khách hàng',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Nội dung phản hồi',
            hintText:
                'Cảm ơn khách hàng hoặc giải thích hướng xử lý...',
            alignLabelWithHint: true,
            errorText: _error,
          ),
          onChanged: (_) {
            if (_error != null) {
              setState(() => _error = null);
            }
          },
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send_outlined),
          label: const Text('Gửi phản hồi'),
        ),
      ],
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
        border: Border.all(
          color: colors.error.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            review.hasViolationRecord
                ? Icons.gavel_outlined
                : Icons.priority_high_rounded,
            color: colors.error,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  review.hasViolationRecord
                      ? 'Đánh giá đã có biên bản vi phạm'
                      : 'Admin yêu cầu xử lý',
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
                      height: 1.35,
                    ),
                  ),
                ],
                if (review.hasViolationRecord) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Mở biên bản để gửi giải trình hoặc khiếu nại.',
                    style: TextStyle(
                      color: colors.onErrorContainer,
                      fontSize: 12,
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

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const Spacer(),
              Text(
                '$value',
                style: TextStyle(
                  color: color,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.15,
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
              size: 54,
              color: colors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
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

  final firstDate = first.updatedAt ??
      first.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  final secondDate = second.updatedAt ??
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