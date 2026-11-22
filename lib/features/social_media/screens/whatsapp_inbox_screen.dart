import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/whatsapp_models.dart';
import '../services/whatsapp_service.dart';
import 'whatsapp_chat_screen.dart';

class WhatsAppInboxScreen extends StatefulWidget {
  const WhatsAppInboxScreen({super.key});

  @override
  State<WhatsAppInboxScreen> createState() => _WhatsAppInboxScreenState();
}

class _WhatsAppInboxScreenState extends State<WhatsAppInboxScreen> {
  final _service = WhatsAppService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _getDisplayName(WhatsAppConversation conv) {
    if (conv.customerName != null &&
        conv.customerName!.isNotEmpty &&
        !conv.customerName!.contains('@')) {
      return conv.customerName!;
    }
    final cleanPhone = conv.customerPhone.split('@')[0];
    return cleanPhone.startsWith('+') ? cleanPhone : '+$cleanPhone';
  }

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
        // 🔍 شريط البحث
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase().trim();
              });
            },
            decoration: InputDecoration(
              hintText: 'ابحث باسم العميل أو رقم الهاتف...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.green),
              ),
            ),
          ),
        ),

        // 📋 قائمة المحادثات
        Expanded(
          child: StreamBuilder<List<WhatsAppConversation>>(
            stream: _service.streamConversations(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('حدث خطأ: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red)),
                );
              }

              // جلب كل المحادثات
              var conversations = snapshot.data ?? [];

              // 🔍 تطبيق فلتر البحث
              if (_searchQuery.isNotEmpty) {
                conversations = conversations.where((c) {
                  final name = _getDisplayName(c).toLowerCase();
                  final phone = c.customerPhone.toLowerCase();
                  return name.contains(_searchQuery) ||
                      phone.contains(_searchQuery);
                }).toList();
              }

              // لو مفيش محادثات أصلاً أو مفيش نتائج بحث
              if (conversations.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          _searchQuery.isEmpty
                              ? Icons.chat_bubble_outline
                              : Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'لا توجد محادثات حتى الآن'
                            : 'لا توجد نتائج مطابقة لـ "$_searchQuery"',
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              // عرض النتائج
              return ListView.separated(
                itemCount: conversations.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 70),
                itemBuilder: (context, index) {
                  final conv = conversations[index];
                  final displayName = _getDisplayName(conv);
                  final isAssigned = conv.assignedTo != null;
                  final isAssignedToMe = conv.assignedTo == myId;
                  final agentName = conv.assignedAgentName ?? 'موظف آخر';

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: isAssigned
                          ? Colors.blue.shade50
                          : Colors.green.shade50,
                      child: Icon(Icons.person,
                          color: isAssigned ? Colors.blue : Colors.green),
                    ),
                    title: Text(displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(conv.lastMessagePreview ?? '',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (isAssigned)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.assignment_ind,
                                    size: 14,
                                    color: isAssignedToMe
                                        ? Colors.green
                                        : Colors.blue),
                                const SizedBox(width: 4),
                                Text(
                                  isAssignedToMe
                                      ? 'مسؤول: أنت'
                                      : 'مسؤول: $agentName',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isAssignedToMe
                                          ? Colors.green
                                          : Colors.blue,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    trailing: Text(
                      DateFormat('hh:mm a')
                          .format(conv.lastMessageAt.toLocal()),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    onTap: () async {
                      if (!isAssigned && myId != null) {
                        await _service.assignToMe(conv.id, myId);
                      }
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                WhatsAppChatScreen(conversation: conv)),
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
