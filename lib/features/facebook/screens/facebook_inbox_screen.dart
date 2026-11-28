import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/facebook_models.dart';
import '../services/facebook_service.dart';
import 'facebook_chat_screen.dart';

class FacebookInboxScreen extends StatefulWidget {
  const FacebookInboxScreen({super.key});
  @override
  State<FacebookInboxScreen> createState() => _FacebookInboxScreenState();
}

class _FacebookInboxScreenState extends State<FacebookInboxScreen> {
  Key _refreshKey = UniqueKey();
  void _refresh() => setState(() => _refreshKey = UniqueKey());

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1877F2),
          title: const Text(
            'إدارة صفحة فيسبوك',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'الرسائل', icon: Icon(Icons.message)),
              Tab(text: 'الكومنتات', icon: Icon(Icons.comment)),
              Tab(text: 'البوستات', icon: Icon(Icons.post_add)),
            ],
          ),
        ),
        body: TabBarView(
          key: _refreshKey,
          children: const [
            _FacebookMessagesTab(),
            _FacebookCommentsTab(),
            _FacebookPostsTab(),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 1. تبويب الرسائل — REALTIME ✅
// ═══════════════════════════════════════════════════════════
class _FacebookMessagesTab extends StatefulWidget {
  const _FacebookMessagesTab();
  @override
  State<_FacebookMessagesTab> createState() => _FacebookMessagesTabState();
}

class _FacebookMessagesTabState extends State<_FacebookMessagesTab> {
  final _service = FacebookService();
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  // ✅ Nullable (يمنع LateInitializationError على hot reload)
  Stream<List<FacebookConversation>>? _conversationsStream;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _search = v.toLowerCase().trim()),
            decoration: InputDecoration(
              hintText: 'ابحث باسم العميل...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF1877F2)),
              filled: true,
              fillColor: const Color(0xFFF0F2F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<FacebookConversation>>(
            // ✅ Init lazily — يشتغل حتى مع الـ hot reload
            stream: _conversationsStream ??= _service.streamConversations(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'خطأ في تحميل البيانات:\n${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }

              var items = snap.data ?? [];
              if (_search.isNotEmpty) {
                items = items
                    .where((c) =>
                        (c.customerName ?? '')
                            .toLowerCase()
                            .contains(_search) ||
                        c.psid.contains(_search))
                    .toList();
              }

              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _search.isEmpty ? Icons.inbox : Icons.search_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _search.isEmpty
                            ? 'لا توجد رسائل'
                            : 'لا توجد نتائج لـ "$_search"',
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final c = items[i];
                  final isAssignedToMe = c.assignedTo == myId;
                  final agentName = c.assignedAgentName ?? 'موظف آخر';

                  return ListTile(
                    tileColor: Colors.white,
                    leading: CircleAvatar(
                      backgroundColor:
                          const Color(0xFF1877F2).withValues(alpha: 0.1),
                      backgroundImage: c.customerProfilePic != null
                          ? NetworkImage(c.customerProfilePic!)
                          : null,
                      child: c.customerProfilePic == null
                          ? const Icon(Icons.person, color: Color(0xFF1877F2))
                          : null,
                    ),
                    title: Text(
                      c.customerName ?? c.psid,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          c.lastMessagePreview ?? 'رسالة جديدة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (c.assignedTo != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.assignment_ind,
                                  size: 14,
                                  color: isAssignedToMe
                                      ? Colors.green
                                      : Colors.blue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAssignedToMe
                                      ? 'مسؤول: أنت'
                                      : 'مسؤول: $agentName',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isAssignedToMe
                                        ? Colors.green
                                        : Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    trailing: Text(
                      DateFormat('hh:mm a').format(c.lastMessageAt.toLocal()),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    onTap: () async {
                      if (c.assignedTo == null && myId != null) {
                        try {
                          await _service.assignToMe(c.id, myId);
                        } catch (e) {
                          debugPrint('⚠️ assignToMe failed: $e');
                        }
                      }
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FacebookChatScreen(conversation: c),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 2. تبويب الكومنتات — REALTIME (social_comments)
// ═══════════════════════════════════════════════════════════
class _FacebookCommentsTab extends StatefulWidget {
  const _FacebookCommentsTab();
  @override
  State<_FacebookCommentsTab> createState() => _FacebookCommentsTabState();
}

class _FacebookCommentsTabState extends State<_FacebookCommentsTab> {
  final _service = FacebookService();
  final _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _showReplyDialog(String commentId, String senderName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('الرد على $senderName'),
        content: TextField(
          controller: _replyController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'اكتب ردك...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = _replyController.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              _replyController.clear();
              try {
                await _service.replyToComment(commentId, text);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم الرد'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ $e'),
                    backgroundColor: Colors.red,
                  ),
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
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('social_comments')
          .stream(primaryKey: ['id'])
          .eq('platform', 'facebook')
          .order('created_at', ascending: false),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('خطأ: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final comments = snap.data!;
        if (comments.isEmpty) {
          return const Center(child: Text('لا توجد كومنتات'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: comments.length,
          itemBuilder: (_, i) {
            final c = comments[i];
            final isReplied = c['is_replied'] == true;
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
                        Text(
                          c['sender_name'] ?? 'مستخدم',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(c['content'] ?? ''),
                    const Divider(),
                    if (isReplied)
                      const Text(
                        '✅ تم الرد',
                        style: TextStyle(color: Colors.green),
                      )
                    else
                      TextButton.icon(
                        icon: const Icon(Icons.reply),
                        label: const Text('رد'),
                        onPressed: () => _showReplyDialog(
                          c['comment_id'],
                          c['sender_name'] ?? 'مستخدم',
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 3. تبويب البوستات
// ═══════════════════════════════════════════════════════════
class _FacebookPostsTab extends StatefulWidget {
  const _FacebookPostsTab();
  @override
  State<_FacebookPostsTab> createState() => _FacebookPostsTabState();
}

class _FacebookPostsTabState extends State<_FacebookPostsTab> {
  final _service = FacebookService();
  late Future<List<Map<String, dynamic>>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = _service.getPosts();
  }

  Future<void> _reload() async {
    setState(() => _postsFuture = _service.getPosts());
    await _postsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }

        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return const Center(child: Text('لا توجد بوستات'));
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: posts.length,
            itemBuilder: (_, i) {
              final post = posts[i];
              final date = post['created_time'] != null
                  ? DateTime.parse(post['created_time']).toLocal()
                  : DateTime.now();
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
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
                          const Text(
                            'صفحتك',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
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
                      child: Text(post['message'] ?? ''),
                    ),
                    if (post['full_picture'] != null) ...[
                      const SizedBox(height: 12),
                      Image.network(
                        post['full_picture'],
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
          ),
        );
      },
    );
  }
}
