import 'dart:convert';
import 'dart:typed_data';

/// A file or photo the user attached to a question.
///
/// [bytes] only exists for the session that picked the file — history keeps the
/// label and the type, never the payload, so `SharedPreferences` stays small.
class ChatAttachment {
  const ChatAttachment({
    required this.name,
    required this.mimeType,
    required this.size,
    this.bytes,
  });

  /// Largest single attachment accepted. Gemini takes inline data up to 20 MB
  /// per request, so this leaves room for the transcript around it.
  static const maxBytes = 8 * 1024 * 1024;

  /// Mime types Gemini can read as inline data.
  static const supportedMimeTypes = <String>{
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/heic',
    'image/heif',
    'application/pdf',
    'text/plain',
    'text/csv',
    'text/markdown',
    'text/html',
  };

  /// File extensions offered by the document picker, matching
  /// [supportedMimeTypes].
  static const supportedExtensions = <String>[
    'pdf',
    'txt',
    'csv',
    'md',
    'html',
    'png',
    'jpg',
    'jpeg',
    'webp',
    'heic',
  ];

  final String name;
  final String mimeType;

  /// Size in bytes, kept so a restored attachment can still be described.
  final int size;

  /// Raw content, or null once the attachment came back from history.
  final Uint8List? bytes;

  bool get isImage => mimeType.startsWith('image/');

  /// True when the payload is still around and can be sent to Gemini.
  bool get isSendable => bytes != null && bytes!.isNotEmpty;

  String get base64Data => base64Encode(bytes ?? Uint8List(0));

  /// Human-readable size, e.g. `1,2 MB`.
  String get readableSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(0)} KB';
    }
    return '${(size / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }

  /// Persisted without [bytes]; a restored attachment is a label only.
  Map<String, Object?> toJson() => {
    'name': name,
    'mimeType': mimeType,
    'size': size,
  };

  factory ChatAttachment.fromJson(Map<String, Object?> json) {
    return ChatAttachment(
      name: json['name'] is String ? json['name'] as String : 'Lampiran',
      mimeType: json['mimeType'] is String
          ? json['mimeType'] as String
          : 'application/octet-stream',
      size: json['size'] is int ? json['size'] as int : 0,
    );
  }
}
