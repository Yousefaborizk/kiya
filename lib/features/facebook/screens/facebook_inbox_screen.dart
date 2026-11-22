import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/facebook_models.dart';
import '../services/facebook_service.dart';

class FacebookInboxScreen extends StatelessWidget {
  const FacebookInboxScreen({super.key});

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
        body: const TabBarView(
          children: [
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
// 1. تبويب الرسائل (Messages Tab)
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
            onChanged: (v) {
              setState(() => _search = v.toLowerCase().trim());
            },
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
            stream: _service.streamConversations(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('خطأ: ${snap.error}'));
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
                return const Center(child: Text('لا توجد رسائل'));
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
                        await _service.assignToMe(c.id, myId);
                      }
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _FacebookChatScreen(conversation: c),
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
// شاشة المحادثة (Chat Screen)
// ═══════════════════════════════════════════════════════════
class _FacebookChatScreen extends StatefulWidget {
  final FacebookConversation conversation;
  const _FacebookChatScreen({required this.conversation});
  @override
  State<_FacebookChatScreen> createState() => _FacebookChatScreenState();
}

class _FacebookChatScreenState extends State<_FacebookChatScreen> {
  final _service = FacebookService();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    _ctrl.clear();
    try {
      await _service.sendMessage(widget.conversation.psid, text);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1877F2),
        title:
            Text(widget.conversation.customerName ?? widget.conversation.psid),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<FacebookMessage>>(
              stream: _service.streamMessages(widget.conversation.id),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snap.data!;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    final isMe = m.fromMe;
                    return Align(
                      alignment:
                          isMe ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.72),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF1877F2) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              m.content ?? '',
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              DateFormat('hh:mm a')
                                  .format(m.timestamp.toLocal()),
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالة...',
                      filled: true,
                      fillColor: const Color(0xFFF0F2F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF1877F2),
                  child: IconButton(
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _sending ? null : _send,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 2. تبويب الكومنتات (Comments Tab)
// ═══════════════════════════════════════════════════════════
class _FacebookCommentsTab extends StatefulWidget {
  const _FacebookCommentsTab();
  @override
  State<_FacebookCommentsTab> createState() => _FacebookCommentsTabState();
}

class _FacebookCommentsTabState extends State<_FacebookCommentsTab> {
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
            hintText: 'اكتب ردك...',
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
              if (text.isEmpty) {
                return;
              }
              Navigator.pop(context);
              _replyController.clear();
              try {
                await _service.replyToComment(commentId, text);
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم الرد'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!context.mounted) {
                  return;
                }
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
                    if (isReplied) ...[
                      const Text(
                        '✅ تم الرد',
                        style: TextStyle(color: Colors.green),
                      ),
                    ] else ...[
                      TextButton.icon(
                        icon: const Icon(Icons.reply),
                        label: const Text('رد'),
                        onPressed: () => _showReplyDialog(
                          c['comment_id'],
                          c['sender_name'],
                        ),
                      ),
                    ],
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
// 3. تبويب البوستات (Posts Tab)
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
          onRefresh: () async {
            setState(() => _postsFuture = _service.getPosts());
          },
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
