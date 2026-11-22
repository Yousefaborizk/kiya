import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/whatsapp_models.dart';
import '../services/whatsapp_service.dart';

class WhatsAppChatScreen extends StatefulWidget {
  final WhatsAppConversation conversation;
  const WhatsAppChatScreen({super.key, required this.conversation});

  @override
  State<WhatsAppChatScreen> createState() => _WhatsAppChatScreenState();
}

class _WhatsAppChatScreenState extends State<WhatsAppChatScreen> {
  final WhatsAppService _service = WhatsAppService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  // 📋 قائمة الردود السريعة (Canned Responses)
  final List<String> _quickReplies = [
    'أهلاً بك، كيف يمكننا مساعدتك؟',
    'تم استلام طلبك وجاري مراجعته.',
    'سعر المنتج هو ...',
    'سيتم التواصل معك في أقرب وقت.',
    'شكراً لتواصلك معنا.',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await _service.sendMessage(widget.conversation.customerPhone, text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getDisplayName() {
    if (widget.conversation.customerName != null &&
        widget.conversation.customerName!.isNotEmpty &&
        !widget.conversation.customerName!.contains('@')) {
      return widget.conversation.customerName!;
    }
    final cleanPhone = widget.conversation.customerPhone.split('@')[0];
    return cleanPhone.startsWith('+') ? cleanPhone : '+$cleanPhone';
  }

  // 📅 دالة بتحدد شكل فاصل التاريخ
  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) return 'اليوم';
    if (messageDate == yesterday) return 'أمس';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // ⚡ قائمة الردود السريعة
  void _showQuickReplies() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('الردود السريعة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _quickReplies.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.flash_on, color: Colors.amber),
                      title: Text(_quickReplies[index]),
                      onTap: () {
                        _messageController.text = _quickReplies[index];
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final displayName = _getDisplayName();
    final isLocked = widget.conversation.assignedTo != null &&
        widget.conversation.assignedTo != myId;
    final agentName = widget.conversation.assignedAgentName ?? 'موظف آخر';

    return Scaffold(
      backgroundColor: const Color(0xFFEFEAE2), // لون خلفية واتساب
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayName,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              isLocked ? 'مسؤول: $agentName' : 'مسؤول: أنت',
              style: TextStyle(
                  fontSize: 12,
                  color: isLocked ? Colors.red.shade200 : Colors.greenAccent,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<WhatsAppMessage>>(
              stream: _service.streamMessages(widget.conversation.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;

                if (messages.isEmpty) {
                  return const Center(
                      child: Text('لا توجد رسائل بعد',
                          style: TextStyle(color: Colors.grey)));
                }

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.fromMe;

                    // 📅 التحقق من التاريخ لعرض فاصل
                    bool showDateSeparator = false;
                    if (index == 0) {
                      showDateSeparator = true;
                    } else {
                      final prevMsg = messages[index - 1];
                      if (msg.timestamp.day != prevMsg.timestamp.day ||
                          msg.timestamp.month != prevMsg.timestamp.month ||
                          msg.timestamp.year != prevMsg.timestamp.year) {
                        showDateSeparator = true;
                      }
                    }

                    return Column(
                      children: [
                        // فاصل التاريخ
                        if (showDateSeparator)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 16),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _formatDateSeparator(msg.timestamp.toLocal()),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),

                        // فقاعة الرسالة
                        Align(
                          alignment: isMe
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.only(
                                left: 12, right: 12, top: 8, bottom: 6),
                            decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFFD9FDD3)
                                    : Colors.white, // أخضر واتساب الفاتح
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: isMe
                                      ? const Radius.circular(0)
                                      : const Radius.circular(12),
                                  bottomRight: isMe
                                      ? const Radius.circular(12)
                                      : const Radius.circular(0),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1))
                                ]),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(msg.content ?? '',
                                    style: const TextStyle(
                                        fontSize: 15, color: Colors.black87)),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                        DateFormat('hh:mm a')
                                            .format(msg.timestamp.toLocal()),
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600)),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.done_all,
                                          size: 14, color: Colors.blue),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ── حالة القفل أو مربع الكتابة ──
          if (isLocked)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red.shade50,
              width: double.infinity,
              child: Text(
                '🔒 هذه المحادثة مسندة إلى ($agentName). لا يمكنك الرد عليها.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: Colors.transparent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // ⚡ زرار الردود السريعة
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.flash_on, color: Colors.amber),
                      onPressed: _showQuickReplies,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // مربع الكتابة
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 2)
                        ],
                      ),
                      child: TextField(
                        controller: _messageController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        enabled: !_isSending,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'اكتب رسالة...',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // زرار الإرسال
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _isSending
                        ? Colors.grey
                        : const Color(0xFF00A884), // أخضر واتساب
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : IconButton(
                            icon: const Icon(Icons.send,
                                color: Colors.white, size: 20),
                            onPressed: _sendMessage),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
