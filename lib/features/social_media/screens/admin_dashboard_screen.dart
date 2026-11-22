import 'package:flutter/material.dart';
import '../services/whatsapp_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _service = WhatsAppService();
  late Future<List<dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _service.getAdminStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الموظفين (الواتساب)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                setState(() => _statsFuture = _service.getAdminStats()),
          )
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('حدث خطأ: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text('لا توجد إحصائيات متاحة حتى الآن.'));
          }

          final stats = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: stats.length,
            itemBuilder: (context, index) {
              final agent = stats[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                              backgroundColor: Colors.blueAccent,
                              child: Icon(Icons.support_agent,
                                  color: Colors.white)),
                          const SizedBox(width: 12),
                          Text(agent['agent_name'] ?? 'موظف',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('محادثات مسندة',
                              agent['total_assigned'].toString(), Colors.blue),
                          _buildStatItem('محادثات مفتوحة',
                              agent['open_assigned'].toString(), Colors.orange),
                          _buildStatItem(
                              'رسائل مرسلة',
                              agent['total_messages_sent'].toString(),
                              Colors.green),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
