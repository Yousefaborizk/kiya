import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/facebook_service.dart';

class FacebookCommentsScreen extends StatefulWidget {
  const FacebookCommentsScreen({super.key});

  @override
  State<FacebookCommentsScreen> createState() => _FacebookCommentsScreenState();
}

class _FacebookCommentsScreenState extends State<FacebookCommentsScreen> {
  final _service = FacebookService();
  final _replyController = TextEditingController();

  void _showReplyDialog(String commentId, String senderName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('الرد على $senderName'),
        content: TextField(
          controller: _replyController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'اكتب ردك هنا...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = _replyController.text.trim();
              if (text.isEmpty) return;

              Navigator.pop(context); // غلق الديالوج
              _replyController.clear();

              try {
                await _service.replyToComment(commentId, text);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('✅ تم إرسال الرد بنجاح'),
                      backgroundColor: Colors.green),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('❌ خطأ: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كومنتات فيسبوك'),
        backgroundColor: const Color(0xFF1877F2),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // بنقرأ من الجدول اللي عملناه
        stream: Supabase.instance.client
            .from('social_comments')
            .stream(primaryKey: ['id'])
            .eq('platform', 'facebook')
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final comments = snapshot.data!;
          if (comments.isEmpty) {
            return const Center(child: Text('لا توجد كومنتات حتى الآن'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: comments.length,
            itemBuilder: (context, index) {
              final c = comments[index];
              final isReplied = c['is_replied'] == true;
              final date = DateTime.parse(c['created_at']).toLocal();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF1877F2),
                            child: Icon(Icons.facebook, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c['sender_name'] ?? 'مستخدم',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            DateFormat('hh:mm a - dd/MM').format(date),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        c['content'] ?? '',
                        style: const TextStyle(fontSize: 15),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isReplied)
                            const Text(
                              '✅ تم الرد',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold),
                            )
                          else
                            TextButton.icon(
                              icon: const Icon(Icons.reply),
                              label: const Text('رد'),
                              onPressed: () => _showReplyDialog(
                                  c['comment_id'], c['sender_name']),
                            ),
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
}
