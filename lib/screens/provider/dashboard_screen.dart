import 'package:flutter/material.dart';
import '../../services/auth.dart';

class ProviderDashboard extends StatelessWidget {
  const ProviderDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Dịch Vụ'),
        backgroundColor: Colors.orange.shade200,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Bảng điều khiển Nhà cung cấp",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                children: [
                  _buildStatCard("Phòng của tôi", Icons.hotel, Colors.blue),
                  _buildStatCard("Đơn đặt mới", Icons.list_alt, Colors.green),
                  _buildStatCard("Doanh thu", Icons.money, Colors.orange),
                  _buildStatCard("Cài đặt", Icons.settings, Colors.grey),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          print("Thêm phòng/khách sạn mới");
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatCard(String title, IconData icon, Color color) {
    return Card(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}