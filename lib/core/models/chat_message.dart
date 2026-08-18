import 'package:indonesia_law/core/models/chat_attachment.dart';

/// Who produced a message in the conversation.
enum ChatRole { user, model }

/// A single bubble in the chat transcript.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.isStreaming = false,
    this.isError = false,
    this.attachments = const <ChatAttachment>[],
  });

  const ChatMessage.user(this.text, {this.attachments = const <ChatAttachment>[]})
    : role = ChatRole.user,
      isStreaming = false,
      isError = false;

  const ChatMessage.model(
    this.text, {
    this.isStreaming = false,
    this.isError = false,
  }) : role = ChatRole.model,
       attachments = const <ChatAttachment>[];

  final ChatRole role;
  final String text;

  /// True while the answer is still being received from the API.
  final bool isStreaming;

  /// True when this bubble reports a failure instead of an answer.
  final bool isError;

  /// Files or photos sent along with the question. Always empty for answers.
  final List<ChatAttachment> attachments;

  bool get isUser => role == ChatRole.user;

  bool get hasAttachments => attachments.isNotEmpty;

  ChatMessage copyWith({
    String? text,
    bool? isStreaming,
    bool? isError,
    List<ChatAttachment>? attachments,
  }) {
    return ChatMessage(
      role: role,
      text: text ?? this.text,
      isStreaming: isStreaming ?? this.isStreaming,
      isError: isError ?? this.isError,
      attachments: attachments ?? this.attachments,
    );
  }

  /// `isStreaming` is deliberately not persisted — a restored message is never
  /// mid-flight. Attachment payloads are dropped too; only their labels stay.
  Map<String, Object?> toJson() => {
    'role': role.name,
    'text': text,
    if (isError) 'isError': true,
    if (attachments.isNotEmpty)
      'attachments': [
        for (final attachment in attachments) attachment.toJson(),
      ],
  };

  factory ChatMessage.fromJson(Map<String, Object?> json) {
    final role = json['role'] == ChatRole.user.name
        ? ChatRole.user
        : ChatRole.model;
    final rawAttachments = json['attachments'];
    return ChatMessage(
      role: role,
      text: json['text'] is String ? json['text'] as String : '',
      isError: json['isError'] == true,
      attachments: <ChatAttachment>[
        if (rawAttachments is List)
          for (final item in rawAttachments)
            if (item is Map<String, Object?>) ChatAttachment.fromJson(item),
      ],
    );
  }
}
