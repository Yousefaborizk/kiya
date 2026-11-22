import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/facebook_service.dart';

class FacebookPostsScreen extends StatefulWidget {
  const FacebookPostsScreen({super.key});

  @override
  State<FacebookPostsScreen> createState() => _FacebookPostsScreenState();
}

class _FacebookPostsScreenState extends State<FacebookPostsScreen> {
  final _service = FacebookService();
  late Future<List<Map<String, dynamic>>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = _service.getPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بوستات فيسبوك'),
        backgroundColor: const Color(0xFF1877F2),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _postsFuture = _service.getPosts();
              });
            },
          )
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }

          final posts = snapshot.data ?? [];
          if (posts.isEmpty) {
            return const Center(child: Text('لا توجد بوستات على هذه الصفحة'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final message = post['message'] ?? 'بوست بدون نص';
              final imageUrl = post['full_picture'];
              final date = post['created_time'] != null
                  ? DateTime.parse(post['created_time']).toLocal()
                  : DateTime.now();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF1877F2),
                            child: Icon(Icons.facebook, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'صفحتك على فيسبوك',
                              style:
                                  TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy').format(date),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(message),
                    ),
                    if (imageUrl != null) ...[
                      const SizedBox(height: 12),
                      Image.network(
                        imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
