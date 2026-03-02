class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final MessageType type;
  final String? recipeId;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.type = MessageType.text,
    this.recipeId,
  });
}

enum MessageType {
  text,
  recipe,
  voiceTranscription,
  cookingStep,
  suggestion,
}
