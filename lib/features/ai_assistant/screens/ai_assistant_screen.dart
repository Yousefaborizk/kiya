import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/shared/app_bar_actions.dart';
import '../../../widgets/shared/app_shell.dart';
import '../models/ai_models.dart';
import '../providers/ai_assistant_providers.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  bool _sending = false;
  bool _waitingForReply = false;
  bool _showListMobile = true;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── إرسال الرسالة ──────────────────────────────────
  Future<void> _handleSend() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    final repo = ref.read(aiAssistantRepoProvider);
    final currentId = ref.read(currentConversationIdProvider);

    setState(() {
      _sending = true;
      _waitingForReply = true;
    });

    _inputCtrl.clear();
    _focusNode.requestFocus();
    _scrollToBottomSoon();

    try {
      String conversationId;
      String? autoTitle;

      if (currentId == null) {
        final conv = await repo.createConversation();
        conversationId = conv.id;
        ref.read(currentConversationIdProvider.notifier).state = conversationId;
        autoTitle = _titleFrom(text);
      } else {
        conversationId = currentId;
      }

      await repo.sendMessage(
        conversationId: conversationId,
        content: text,
        autoTitle: autoTitle,
      );

      Future.delayed(const Duration(seconds: 60), () {
        if (mounted && _waitingForReply) {
          setState(() => _waitingForReply = false);
        }
      });
    } on AiException catch (e) {
      _snack(e.message, isError: true);
      if (mounted) setState(() => _waitingForReply = false);
    } catch (e) {
      _snack('ai_err_send_failed'.tr(), isError: true);
      debugPrint('🚨 SEND ERROR: $e');
      if (mounted) setState(() => _waitingForReply = false);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── إعادة توليد الرد (Regenerate) ─────────────────────
  Future<void> _regenerateResponse(String conversationId) async {
    if (_waitingForReply) return;
    setState(() => _waitingForReply = true);
    _scrollToBottomSoon();

    try {
      // نطلب من الـ AI إعادة التوليد بناءً على الـ Context الموجود
      await ref
          .read(aiAssistantRepoProvider)
          .regenerateResponse(conversationId);
    } catch (e) {
      if (mounted) setState(() => _waitingForReply = false);
      _snack('ai_err_send_failed'.tr(), isError: true);
    }
  }

  String _titleFrom(String text) =>
      text.length > 50 ? '${text.substring(0, 47)}...' : text;

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _startNewChat() {
    ref.read(currentConversationIdProvider.notifier).state = null;
    setState(() => _showListMobile = false);
    _focusNode.requestFocus();
  }

  Future<void> _deleteConversation(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ai_delete_chat'.tr()),
        content: Text('ai_delete_chat_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common_cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common_delete'.tr()),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(aiAssistantRepoProvider).deleteConversation(id);
      if (ref.read(currentConversationIdProvider) == id) {
        ref.read(currentConversationIdProvider.notifier).state = null;
      }
    } catch (e) {
      _snack('ai_err_delete_failed'.tr(args: ['$e']), isError: true);
    }
  }

  // ── البناء الرئيسي ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final currentId = ref.watch(currentConversationIdProvider);

    if (currentId != null) {
      ref.listen<AsyncValue<List<AiMessage>>>(
        messagesProvider(currentId),
        (prev, next) {
          final prevLen = prev?.value?.length ?? 0;
          final nextLen = next.value?.length ?? 0;
          if (nextLen > prevLen) {
            final last = next.value!.last;
            if (last.isAssistant && _waitingForReply) {
              setState(() => _waitingForReply = false);
            }
            _scrollToBottomSoon();
          }
        },
      );
    }

    return AppShell(
      currentRoute: '/ai-assistant',
      child: Scaffold(
        appBar: AppBar(
          title: Text('ai_assistant'.tr()),
          automaticallyImplyLeading: false,
          leading: !isWide
              ? IconButton(
                  icon: Icon(_showListMobile ? Icons.menu : Icons.arrow_back),
                  onPressed: () {
                    if (_showListMobile) {
                      Scaffold.of(context).openDrawer();
                    } else {
                      setState(() => _showListMobile = true);
                    }
                  },
                )
              : null,
          actions: [
            if (isWide)
              IconButton(
                tooltip: 'ai_new_chat'.tr(),
                icon: const Icon(Icons.add_comment_outlined),
                onPressed: _startNewChat,
              ),
            const AppBarActions(),
          ],
        ),
        body: SafeArea(
          child: isWide
              ? Row(
                  children: [
                    SizedBox(
                      width: 300,
                      child: _ConversationsSidebar(
                        currentId: currentId,
                        onSelect: (id) {
                          ref
                              .read(currentConversationIdProvider.notifier)
                              .state = id;
                        },
                        onNewChat: _startNewChat,
                        onDelete: _deleteConversation,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: _buildChatPane(currentId)),
                  ],
                )
              : (_showListMobile
                  ? _ConversationsSidebar(
                      currentId: currentId,
                      onSelect: (id) {
                        ref.read(currentConversationIdProvider.notifier).state =
                            id;
                        setState(() => _showListMobile = false);
                      },
                      onNewChat: () {
                        _startNewChat();
                        setState(() => _showListMobile = false);
                      },
                      onDelete: _deleteConversation,
                    )
                  : _buildChatPane(currentId)),
        ),
      ),
    );
  }

  // ── واجهة الدردشة ───────────────────────────────────
  Widget _buildChatPane(String? conversationId) {
    if (conversationId == null) {
      return _EmptyState(
        onSuggestionTap: (text) {
          _inputCtrl.text = text;
          _inputCtrl.selection = TextSelection.collapsed(offset: text.length);
          _handleSend();
        },
      );
    }

    final messagesAsync = ref.watch(messagesProvider(conversationId));

    return Column(
      children: [
        Expanded(
          child: messagesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, __) => _buildErrorState(error),
            data: (messages) {
              if (messages.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: messages.length + (_waitingForReply ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == messages.length) {
                    return const _TypingIndicator();
                  }

                  final isLastMessage = i == messages.length - 1;
                  final msg = messages[i];

                  return _MessageBubble(
                    message: msg,
                    isLastMessage: isLastMessage,
                    onRegenerate: () => _regenerateResponse(conversationId),
                  );
                },
              );
            },
          ),
        ),
        _InputBar(
          controller: _inputCtrl,
          focusNode: _focusNode,
          sending: _sending,
          onSend: _handleSend,
        ),
      ],
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'ai_load_error'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: Text('common_retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// 1. السايدبار (قائمة المحادثات)
// ══════════════════════════════════════════════════════
class _ConversationsSidebar extends ConsumerWidget {
  final String? currentId;
  final ValueChanged<String> onSelect;
  final VoidCallback onNewChat;
  final ValueChanged<String> onDelete;

  const _ConversationsSidebar({
    required this.currentId,
    required this.onSelect,
    required this.onNewChat,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convs = ref.watch(conversationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onNewChat,
                icon: const Icon(Icons.add, size: 18),
                label: Text('ai_new_chat'.tr()),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: convs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, __) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${'ai_load_error'.tr()}\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'ai_no_conversations'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondaryLight,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final c = list[i];
                    final selected = c.id == currentId;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      child: Material(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => onSelect(c.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 16,
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textSecondaryLight,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    c.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: selected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color:
                                          selected ? AppColors.primary : null,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  iconSize: 16,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppColors.textSecondaryLight),
                                  onPressed: () => onDelete(c.id),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// 2. الشاشة الفاضية (الاقتراحات)
// ══════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final ValueChanged<String> onSuggestionTap;
  const _EmptyState({required this.onSuggestionTap});

  static const _suggestions = [
    ('ai_sugg_1', Icons.mail_outline),
    ('ai_sugg_2', Icons.insights),
    ('ai_sugg_3', Icons.public),
    ('ai_sugg_4', Icons.description_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: const Icon(Icons.auto_awesome,
                    color: AppColors.secondary, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                'ai_welcome_title'.tr(),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'ai_welcome_subtitle'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondaryLight,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: _suggestions.map((s) {
                  final key = s.$1;
                  final icon = s.$2;
                  return OutlinedButton.icon(
                    onPressed: () => onSuggestionTap(key.tr()),
                    icon: Icon(icon, size: 16),
                    label: Text(key.tr(), style: const TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      side: BorderSide(
                          color: AppColors.borderLight.withValues(alpha: .8)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// 3. فقاعة الرسالة (Message Bubble)
// ══════════════════════════════════════════════════════
class _MessageBubble extends StatelessWidget {
  final AiMessage message;
  final bool isLastMessage;
  final VoidCallback onRegenerate;

  const _MessageBubble({
    required this.message,
    required this.isLastMessage,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubbleColor =
        isUser ? AppColors.primary : Theme.of(context).cardColor;
    final textColor = isUser ? Colors.white : AppColors.textPrimaryLight;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              const _Avatar(isUser: false),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      border: isUser
                          ? null
                          : Border.all(color: AppColors.borderLight),
                      boxShadow: isUser
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              )
                            ],
                    ),
                    child: isUser
                        ? SelectableText(
                            message.content,
                            style: TextStyle(
                                color: textColor, fontSize: 14, height: 1.5),
                          )
                        : GptMarkdown(
                            message.content,
                            style: const TextStyle(
                              color: AppColors.textPrimaryLight,
                              fontSize: 14.5,
                              height: 1.6,
                            ),
                          ),
                  ),

                  // أزرار الإجراءات (نسخ / إعادة توليد)
                  if (!isUser) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActionIcon(
                          icon: Icons.copy,
                          tooltip: 'ai_copied'.tr(),
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: message.content));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('ai_copied'.tr()),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        if (isLastMessage) ...[
                          const SizedBox(width: 8),
                          _ActionIcon(
                            icon: Icons.refresh,
                            tooltip: 'ai_regenerate'.tr(),
                            onTap: onRegenerate,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 12),
              const _Avatar(isUser: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIcon(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: AppColors.textSecondaryLight),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final bool isUser;
  const _Avatar({required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser ? AppColors.secondary : AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        isUser ? Icons.person : Icons.auto_awesome,
        color: isUser ? AppColors.primary : AppColors.secondary,
        size: 18,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// 4. مؤشر الكتابة (Typing Indicator)
// ══════════════════════════════════════════════════════
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Avatar(isUser: false),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final t = (_ctrl.value + i / 3) % 1.0;
                      final o = (1 - (t * 2 - 1).abs()).clamp(0.3, 1.0);
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: o),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// 5. شريط الإدخال (Input Bar)
// ══════════════════════════════════════════════════════
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: const Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: 'ai_input_hint'.tr(),
                filled: true,
                fillColor: AppColors.backgroundLight,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              onSubmitted: (_) {
                if (!sending) onSend();
              },
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: sending ? AppColors.textSecondaryLight : AppColors.primary,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: sending ? null : onSend,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
