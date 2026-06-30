import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/provider_service.dart';

class ProviderBookingsPage extends StatefulWidget {
  const ProviderBookingsPage({super.key, required this.service});

  final ProviderService service;

  @override
  State<ProviderBookingsPage> createState() => _ProviderBookingsPageState();
}

class _ProviderBookingsPageState extends State<ProviderBookingsPage> {
  String _status = 'all';

  Future<void> _update(String id, String status) async {
    try {
      await widget.service.updateBookingStatus(id, status);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật đơn đặt phòng.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.service.watchBookings(),
      builder: (context, snapshot) {
        var bookings = snapshot.data?.docs.toList() ?? [];

        if (_status != 'all') {
          bookings = bookings.where((document) {
            return document.data()['status'] == _status;
          }).toList();
        }

        bookings.sort((a, b) {
          final aTime = a.data()['createdAt'] as Timestamp?;
          final bTime = b.data()['createdAt'] as Timestamp?;

          return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
            aTime?.millisecondsSinceEpoch ?? 0,
          );
        });

        return Column(
          children: [
            SizedBox(
              height: 58,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                children: [
                  _filter('all', 'Tất cả'),
                  _filter('pending', 'Chờ xác nhận'),
                  _filter('confirmed', 'Đã xác nhận'),
                  _filter('completed', 'Hoàn thành'),
                  _filter('cancelled', 'Đã hủy'),
                ],
              ),
            ),
            Expanded(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : bookings.isEmpty
                  ? const Center(child: Text('Không có đơn đặt phòng'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: bookings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final document = bookings[index];
                        final booking = document.data();
                        final status =
                            booking['status'] as String? ?? 'pending';

                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(14),
                            leading: CircleAvatar(
                              child: Icon(_statusIcon(status)),
                            ),
                            title: Text(
                              booking['hotelName'] as String? ?? 'Khách sạn',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              'Phòng ${booking['roomNumber'] ?? ''}\n'
                              '${booking['guests'] ?? 1} khách · '
                              '${_statusText(status)}\n'
                              '${_money(booking['totalAmount'])}',
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              enabled:
                                  status == 'pending' || status == 'confirmed',
                              onSelected: (value) {
                                _update(document.id, value);
                              },
                              itemBuilder: (_) => [
                                if (status == 'pending')
                                  const PopupMenuItem(
                                    value: 'confirmed',
                                    child: Text('Xác nhận đơn'),
                                  ),
                                if (status == 'pending')
                                  const PopupMenuItem(
                                    value: 'rejected',
                                    child: Text('Từ chối đơn'),
                                  ),
                                if (status == 'confirmed')
                                  const PopupMenuItem(
                                    value: 'completed',
                                    child: Text('Hoàn thành'),
                                  ),
                                if (status == 'confirmed')
                                  const PopupMenuItem(
                                    value: 'cancelled',
                                    child: Text('Hủy đơn'),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _filter(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 10, bottom: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _status == value,
        onSelected: (_) => setState(() => _status = value),
      ),
    );
  }

  String _statusText(String status) {
    return switch (status) {
      'confirmed' => 'Đã xác nhận',
      'completed' => 'Hoàn thành',
      'cancelled' => 'Đã hủy',
      'rejected' => 'Đã từ chối',
      _ => 'Chờ xác nhận',
    };
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'confirmed' => Icons.verified_outlined,
      'completed' => Icons.task_alt_rounded,
      'cancelled' || 'rejected' => Icons.cancel_outlined,
      _ => Icons.schedule_rounded,
    };
  }

  String _money(dynamic value) {
    final amount = value is num ? value.toDouble() : 0;
    return '${amount.toStringAsFixed(0)}đ';
  }
}
