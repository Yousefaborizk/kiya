import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_assistant_repository.dart';
import '../models/ai_models.dart';

final aiAssistantRepoProvider = Provider<AiAssistantRepository>(
  (ref) => AiAssistantRepository(),
);

final currentConversationIdProvider = StateProvider<String?>((_) => null);

final conversationsProvider = StreamProvider<List<AiConversation>>((ref) {
  final repo = ref.watch(aiAssistantRepoProvider);
  return repo.watchConversations();
});

final messagesProvider =
    StreamProvider.family<List<AiMessage>, String>((ref, conversationId) {
  final repo = ref.watch(aiAssistantRepoProvider);
  return repo.watchMessages(conversationId);
});
