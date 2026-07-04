import 'package:flutter/material.dart';

import '../../model/review.dart';
import '../../services/review_service.dart';
import 'widgets/review_alert_card.dart';
import 'widgets/review_statistics.dart';

class AdminReviewManagementPage extends StatefulWidget {
  const AdminReviewManagementPage({
    super.key,
    this.service,
  });

  final ReviewService? service;

  @override
  State<AdminReviewManagementPage> createState() =>
      _AdminReviewManagementPageState();
}

class _AdminReviewManagementPageState
    extends State<AdminReviewManagementPage> {
  final _searchController = TextEditingController();

  late final ReviewService _service;

  String _search = '';
  String _severity = 'all';
  String _status = 'all';
  String? _processingId;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ReviewService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleAction(
    ReviewModel review,
    ReviewAdminAction action,
  ) async {
    if (_processingId != null) return;

    if (action == ReviewAdminAction.hide ||
        action == ReviewAdminAction.publish) {
      await _changeVisibility(
        review,
        action == ReviewAdminAction.publish,
      );
      return;
    }

    final configuration = switch (action) {
      ReviewAdminAction.investigate => (
          title: 'Bắt đầu xác minh',
          status: ReviewModerationStatus.investigating,
          providerAction: false,
          hint: 'Ghi chú nội dung cần xác minh...',
        ),
      ReviewAdminAction.contactProvider => (
          title: 'Yêu cầu nhà cung cấp xử lý',
          status: ReviewModerationStatus.providerContacted,
          providerAction: true,
          hint: 'Ghi rõ vấn đề nhà cung cấp cần giải trình...',
        ),
      ReviewAdminAction.resolve => (
          title: 'Đánh dấu đã xử lý',
          status: ReviewModerationStatus.resolved,
          providerAction: false,
          hint: 'Ghi lại kết quả xử lý...',
        ),
      ReviewAdminAction.dismiss => (
          title: 'Không ghi nhận vi phạm',
          status: ReviewModerationStatus.dismissed,
          providerAction: false,
          hint: 'Nêu lý do không ghi nhận vi phạm...',
        ),
      _ => null,
    };

    if (configuration == null) return;

    final note = await _requestAdminNote(
      title: configuration.title,
      hint: configuration.hint,
      initialValue: review.adminNote,
    );

    if (!mounted || note == null) return;

    setState(() => _processingId = review.id);

    try {
      await _service.moderateReview(
        reviewId: review.id,
        moderationStatus: configuration.status,
        adminNote: note,
        providerActionRequired: configuration.providerAction,
      );

      if (!mounted) return;
      _showMessage('Đã cập nhật trạng thái xử lý.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _processingId = null);
      }
    }
  }

  Future<String?> _requestAdminNote({
    required String title,
    required String hint,
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.admin_panel_settings_outlined),
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              maxLength: 1500,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Ghi chú nội bộ',
                hintText: hint,
                alignLabelWithHint: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              onPressed: () {
                final value = controller.text.trim();

                if (value.length < 3) {
                  ScaffoldMessenger.of(dialogContext)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Ghi chú phải có ít nhất 3 ký tự.',
                        ),
                      ),
                    );
                  return;
                }

                Navigator.pop(dialogContext, value);
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Lưu'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _changeVisibility(
    ReviewModel review,
    bool visible,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            visible
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          title: Text(
            visible ? 'Hiện lại đánh giá?' : 'Ẩn đánh giá?',
          ),
          content: Text(
            visible
                ? 'Đánh giá sẽ xuất hiện trở lại trên ứng dụng.'
                : 'Chỉ nên ẩn đánh giá vi phạm nội dung, spam hoặc '
                    'xúc phạm. Không nên ẩn chỉ vì khách đánh giá thấp.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(visible ? 'Hiện lại' : 'Ẩn đánh giá'),
            ),
          ],
        );
      },
    );

    if (!mounted || accepted != true) return;

    setState(() => _processingId = review.id);

    try {
      await _service.setReviewVisibility(
        reviewId: review.id,
        visible: visible,
      );

      if (!mounted) return;

      _showMessage(
        visible ? 'Đã hiện lại đánh giá.' : 'Đã ẩn đánh giá.',
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _search = '';
      _severity = 'all';
      _status = 'all';
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReviewModel>>(
      stream: _service.watchAllReviewsForAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Không thể tải đánh giá',
            message: _cleanError(snapshot.error),
          );
        }

        final allReviews = snapshot.data ?? [];
        final filteredReviews = allReviews.where(_matchesFilter).toList()
          ..sort(_compareReviews);

        return CustomScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(
                allReviews: allReviews,
                resultCount: filteredReviews.length,
              ),
            ),
            if (filteredReviews.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  icon: Icons.fact_check_outlined,
                  title: 'Không có đánh giá phù hợp',
                  message:
                      'Hãy thay đổi từ khóa hoặc điều kiện lọc.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                sliver: SliverList.separated(
                  itemCount: filteredReviews.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final review = filteredReviews[index];

                    return AdminReviewAlertCard(
                      review: review,
                      processing: _processingId == review.id,
                      onAction: (action) {
                        _handleAction(review, action);
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

  Widget _buildHeader({
    required List<ReviewModel> allReviews,
    required int resultCount,
  }) {
    final colors = Theme.of(context).colorScheme;
    final hasFilters = _search.trim().isNotEmpty ||
        _severity != 'all' ||
        _status != 'all';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminReviewStatistics(reviews: allReviews),
              const SizedBox(height: 16),
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
              const SizedBox(height: 12),
              _buildResponsiveFilters(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.manage_search_outlined,
                    size: 19,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '$resultCount đánh giá phù hợp',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (hasFilters)
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(
                        Icons.filter_alt_off_outlined,
                        size: 19,
                      ),
                      label: const Text('Xóa lọc'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              _buildSeverityFilter(),
              const SizedBox(height: 10),
              _buildStatusFilter(),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildSeverityFilter()),
            const SizedBox(width: 12),
            Expanded(child: _buildStatusFilter()),
          ],
        );
      },
    );
  }

  Widget _buildSeverityFilter() {
    return DropdownButtonFormField<String>(
      key: ValueKey('severity_$_severity'),
      initialValue: _severity,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Mức độ cảnh báo',
        prefixIcon: Icon(Icons.warning_amber_outlined),
      ),
      items: const [
        DropdownMenuItem(
          value: 'all',
          child: Text(
            'Tất cả mức độ',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: ReviewSeverity.critical,
          child: Text(
            'Nghiêm trọng',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: ReviewSeverity.high,
          child: Text(
            'Mức cao',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: ReviewSeverity.warning,
          child: Text(
            'Cần lưu ý',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: ReviewSeverity.normal,
          child: Text(
            'Bình thường',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _severity = value);
        }
      },
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<String>(
      key: ValueKey('status_$_status'),
      initialValue: _status,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Trạng thái xử lý',
        prefixIcon: Icon(Icons.fact_check_outlined),
      ),
      items: const [
        DropdownMenuItem(
          value: 'all',
          child: Text(
            'Tất cả trạng thái',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: 'open',
          child: Text(
            'Chưa hoàn tất',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: ReviewModerationStatus.notRequired,
          child: Text(
            'Không cần xử lý',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: ReviewModerationStatus.pendingReview,
          child: Text(
            'Chờ xem xét',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: ReviewModerationStatus.investigating,
          child: Text(
            'Đang xác minh',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: ReviewModerationStatus.providerContacted,
          child: Text(
            'Đã liên hệ nhà cung cấp',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: ReviewModerationStatus.resolved,
          child: Text(
            'Đã xử lý',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: ReviewModerationStatus.dismissed,
          child: Text(
            'Không ghi nhận vi phạm',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _status = value);
        }
      },
    );
  }

  bool _matchesFilter(ReviewModel review) {
    final keyword = _search.trim().toLowerCase();

    final matchesSearch = keyword.isEmpty ||
        review.hotelName.toLowerCase().contains(keyword) ||
        review.roomNumber.toLowerCase().contains(keyword) ||
        review.roomType.toLowerCase().contains(keyword) ||
        review.customerName.toLowerCase().contains(keyword) ||
        review.comment.toLowerCase().contains(keyword);

    final matchesSeverity =
        _severity == 'all' || review.severity == _severity;

    final matchesStatus = switch (_status) {
      'all' => true,
      'open' =>
        review.moderationStatus != ReviewModerationStatus.resolved &&
            review.moderationStatus !=
                ReviewModerationStatus.dismissed &&
            review.moderationStatus !=
                ReviewModerationStatus.notRequired,
      _ => review.moderationStatus == _status,
    };

    return matchesSearch && matchesSeverity && matchesStatus;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: Icon(
                    icon,
                    size: 36,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
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
      ),
    );
  }
}

int _compareReviews(
  ReviewModel first,
  ReviewModel second,
) {
  final severityComparison = _severityPriority(
    second.severity,
  ).compareTo(
    _severityPriority(first.severity),
  );

  if (severityComparison != 0) {
    return severityComparison;
  }

  final firstDate = first.updatedAt ??
      first.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  final secondDate = second.updatedAt ??
      second.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  return secondDate.compareTo(firstDate);
}

int _severityPriority(String severity) {
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