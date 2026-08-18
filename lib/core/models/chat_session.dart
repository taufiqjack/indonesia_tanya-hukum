import 'package:indonesia_law/core/models/chat_message.dart';

/// One saved conversation as it appears in the history list.
class ChatSession {
  const ChatSession({
    required this.id,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// First question asked, used as the row label in the history drawer.
  String get title {
    final first = messages
        .where((message) => message.isUser && message.text.trim().isNotEmpty)
        .map((message) => message.text.trim())
        .firstOrNull;
    if (first == null) {
      // A question can be attachments only; name it after the first one.
      final attached = messages
          .where((message) => message.isUser && message.hasAttachments)
          .map((message) => message.attachments.first.name)
          .firstOrNull;
      return attached ?? 'Obrolan baru';
    }

    final singleLine = first.replaceAll(RegExp(r'\s+'), ' ');
    return singleLine.length <= 60
        ? singleLine
        : '${singleLine.substring(0, 60).trimRight()}…';
  }

  /// Last answer, used as the row subtitle.
  String get preview {
    final last = messages
        .where((message) => !message.isUser && message.text.trim().isNotEmpty)
        .map((message) => message.text.trim())
        .lastOrNull;
    if (last == null) return 'Belum ada jawaban';
    return last.replaceAll(RegExp(r'\s+'), ' ');
  }

  ChatSession copyWith({List<ChatMessage>? messages, DateTime? updatedAt}) {
    return ChatSession(
      id: id,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messages': [for (final message in messages) message.toJson()],
  };

  factory ChatSession.fromJson(Map<String, Object?> json) {
    final raw = json['messages'];
    final messages = <ChatMessage>[
      if (raw is List)
        for (final item in raw)
          if (item is Map<String, Object?>) ChatMessage.fromJson(item),
    ];

    final createdAt = _parseDate(json['createdAt']);
    return ChatSession(
      id: json['id'] is String
          ? json['id'] as String
          : createdAt.microsecondsSinceEpoch.toString(),
      messages: messages,
      createdAt: createdAt,
      updatedAt: _parseDate(json['updatedAt'] ?? json['createdAt']),
    );
  }

  static DateTime _parseDate(Object? value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
