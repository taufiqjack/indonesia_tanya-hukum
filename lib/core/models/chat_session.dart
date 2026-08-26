import 'package:indonesia_law/core/models/chat_message.dart';

/// One saved conversation as it appears in the history list.
///
/// The list and the transcript are two different reads on the server: the
/// drawer gets rows without their messages, and the messages only arrive when
/// a row is opened. A row is therefore allowed to hold an empty [messages]
/// while still knowing its [remoteTitle] and [messageCount].
class ChatSession {
  const ChatSession({
    required this.id,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.remoteTitle,
    this.messageCount,
  });

  final String id;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Title the server gave the conversation, when it came from there.
  final String? remoteTitle;

  /// How many messages the server holds, even when none are loaded yet.
  final int? messageCount;

  /// True for a row whose transcript still has to be fetched.
  bool get isSummary => messages.isEmpty && (messageCount ?? 0) > 0;

  /// The server's title when there is one, otherwise the first question asked.
  /// Used as the row label in the history drawer.
  String get title {
    final remote = remoteTitle?.trim();
    if (remote != null && remote.isNotEmpty) return _shorten(remote);

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

    return _shorten(first);
  }

  /// Last answer, used as the row subtitle. A row whose messages are not
  /// loaded yet says how long the conversation is instead.
  String get preview {
    final last = messages
        .where((message) => !message.isUser && message.text.trim().isNotEmpty)
        .map((message) => message.text.trim())
        .lastOrNull;
    if (last != null) return last.replaceAll(RegExp(r'\s+'), ' ');

    final count = messageCount ?? 0;
    return count > 0 ? '$count pesan' : 'Belum ada jawaban';
  }

  ChatSession copyWith({
    List<ChatMessage>? messages,
    DateTime? updatedAt,
    String? remoteTitle,
    int? messageCount,
  }) {
    return ChatSession(
      id: id,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      remoteTitle: remoteTitle ?? this.remoteTitle,
      messageCount: messageCount ?? this.messageCount,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (remoteTitle != null) 'title': remoteTitle,
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
      remoteTitle: json['title'] is String ? json['title'] as String : null,
    );
  }

  /// Reads a session as the backend spells it, either the full
  /// `ChatSessionResponse` or the lighter row the list endpoint returns.
  factory ChatSession.fromApi(Map<String, Object?> json) {
    final raw = json['messages'];
    final messages = <ChatMessage>[
      if (raw is List)
        for (final item in raw)
          if (item is Map<String, Object?>) ChatMessage.fromApi(item),
    ];

    final createdAt = _parseDate(json['created_at']);
    final count = json['message_count'];
    return ChatSession(
      id: json['id']?.toString() ?? '',
      messages: messages,
      createdAt: createdAt,
      updatedAt: _parseDate(json['last_message_at'] ?? json['created_at']),
      remoteTitle: json['title'] is String ? json['title'] as String : null,
      messageCount: count is int ? count : messages.length,
    );
  }

  static String _shorten(String text) {
    final singleLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return singleLine.length <= 60
        ? singleLine
        : '${singleLine.substring(0, 60).trimRight()}…';
  }

  static DateTime _parseDate(Object? value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      // A stamp that names its zone is normalised, so the drawer sorts
      // conversations the same way it shows them.
      if (parsed != null) return parsed.toLocal();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
