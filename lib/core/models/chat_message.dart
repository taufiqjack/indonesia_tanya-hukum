import 'package:indonesia_law/core/models/chat_attachment.dart';
import 'package:indonesia_law/core/models/citation.dart';

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
    this.citations = const <Citation>[],
  });

  const ChatMessage.user(this.text, {this.attachments = const <ChatAttachment>[]})
    : role = ChatRole.user,
      isStreaming = false,
      isError = false,
      citations = const <Citation>[];

  const ChatMessage.model(
    this.text, {
    this.isStreaming = false,
    this.isError = false,
    this.citations = const <Citation>[],
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

  /// Articles and sources the answer rests on. Always empty for questions.
  final List<Citation> citations;

  bool get isUser => role == ChatRole.user;

  bool get hasAttachments => attachments.isNotEmpty;

  bool get hasCitations => citations.isNotEmpty;

  ChatMessage copyWith({
    String? text,
    bool? isStreaming,
    bool? isError,
    List<ChatAttachment>? attachments,
    List<Citation>? citations,
  }) {
    return ChatMessage(
      role: role,
      text: text ?? this.text,
      isStreaming: isStreaming ?? this.isStreaming,
      isError: isError ?? this.isError,
      attachments: attachments ?? this.attachments,
      citations: citations ?? this.citations,
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
    if (citations.isNotEmpty)
      'citations': [for (final citation in citations) citation.toJson()],
  };

  /// Reads a message as the backend spells it: `USER`/`ASSISTANT` roles, the
  /// text under `message`, and attachments described by name only — their
  /// payloads stay on the server.
  factory ChatMessage.fromApi(Map<String, Object?> json) {
    final role = json['role']?.toString().toUpperCase() == 'USER'
        ? ChatRole.user
        : ChatRole.model;
    final rawAttachments = json['attachments'];
    return ChatMessage(
      role: role,
      text: json['message'] is String ? json['message'] as String : '',
      attachments: <ChatAttachment>[
        if (rawAttachments is List)
          for (final item in rawAttachments)
            if (item is Map<String, Object?>) ChatAttachment.fromApi(item),
      ],
      citations: _citations(json['citations']),
    );
  }

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
      citations: _citations(json['citations']),
    );
  }

  /// Citations are spelled the same way coming from the server and coming back
  /// from history, and a reference that names no page is dropped — a row that
  /// cannot be opened is only noise under the answer.
  static List<Citation> _citations(Object? raw) {
    if (raw is! List) return const <Citation>[];
    return <Citation>[
      for (final item in raw)
        if (item is Map<String, Object?>)
          if (Citation.fromJson(item) case final citation
              when citation.link != null)
            citation,
    ];
  }
}
