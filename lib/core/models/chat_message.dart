/// Who produced a message in the conversation.
enum ChatRole { user, model }

/// A single bubble in the chat transcript.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.isStreaming = false,
    this.isError = false,
  });

  const ChatMessage.user(this.text)
    : role = ChatRole.user,
      isStreaming = false,
      isError = false;

  const ChatMessage.model(
    this.text, {
    this.isStreaming = false,
    this.isError = false,
  }) : role = ChatRole.model;

  final ChatRole role;
  final String text;

  /// True while the answer is still being received from the API.
  final bool isStreaming;

  /// True when this bubble reports a failure instead of an answer.
  final bool isError;

  bool get isUser => role == ChatRole.user;

  ChatMessage copyWith({String? text, bool? isStreaming, bool? isError}) {
    return ChatMessage(
      role: role,
      text: text ?? this.text,
      isStreaming: isStreaming ?? this.isStreaming,
      isError: isError ?? this.isError,
    );
  }

  /// `isStreaming` is deliberately not persisted — a restored message is never
  /// mid-flight.
  Map<String, Object?> toJson() => {
    'role': role.name,
    'text': text,
    if (isError) 'isError': true,
  };

  factory ChatMessage.fromJson(Map<String, Object?> json) {
    final role = json['role'] == ChatRole.user.name
        ? ChatRole.user
        : ChatRole.model;
    return ChatMessage(
      role: role,
      text: json['text'] is String ? json['text'] as String : '',
      isError: json['isError'] == true,
    );
  }
}
