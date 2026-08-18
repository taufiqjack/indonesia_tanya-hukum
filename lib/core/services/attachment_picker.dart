import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:indonesia_law/core/models/chat_attachment.dart';
import 'package:path/path.dart' as p;

/// Raised when a file cannot be attached; carries a message meant to be shown
/// to the user as-is.
class AttachmentException implements Exception {
  const AttachmentException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Where an attachment comes from.
enum AttachmentSource { camera, gallery, file }

/// Turns a picked photo or document into a [ChatAttachment].
///
/// Every path reads the bytes eagerly: the request to Gemini needs them inline,
/// and the temporary file the platform hands back may be gone by then.
class AttachmentPicker {
  /// [images] is only passed in by tests; `FilePicker` exposes statics only, so
  /// the document path has no seam to inject.
  AttachmentPicker({ImagePicker? images}) : _images = images ?? ImagePicker();

  /// Photos are downscaled before upload — a full-resolution camera shot is
  /// several megabytes for no gain in readability.
  static const _maxImageDimension = 2048.0;
  static const _imageQuality = 85;

  final ImagePicker _images;

  /// Returns the picked attachment, or null when the user backed out.
  Future<ChatAttachment?> pick(AttachmentSource source) {
    return switch (source) {
      AttachmentSource.camera => _pickImage(ImageSource.camera),
      AttachmentSource.gallery => _pickImage(ImageSource.gallery),
      AttachmentSource.file => _pickFile(),
    };
  }

  Future<ChatAttachment?> _pickImage(ImageSource source) async {
    final XFile? picked;
    try {
      picked = await _images.pickImage(
        source: source,
        maxWidth: _maxImageDimension,
        maxHeight: _maxImageDimension,
        imageQuality: _imageQuality,
      );
    } on Object catch (error) {
      throw AttachmentException(_pickerMessage(error, source));
    }
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    return _build(
      name: p.basename(picked.name.isEmpty ? picked.path : picked.name),
      mimeType: picked.mimeType ?? _mimeFromName(picked.name, picked.path),
      bytes: bytes,
    );
  }

  Future<ChatAttachment?> _pickFile() async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        dialogTitle: 'Pilih berkas',
        type: FileType.custom,
        allowedExtensions: ChatAttachment.supportedExtensions,
      );
    } on Object catch (error) {
      throw AttachmentException(_pickerMessage(error, null));
    }
    if (file == null) return null;

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on Object {
      throw const AttachmentException(
        'Berkas tidak dapat dibaca. Coba pilih berkas lain.',
      );
    }

    return _build(
      name: file.name,
      mimeType: _mimeFromName(file.name, file.path),
      bytes: bytes,
    );
  }

  ChatAttachment _build({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) {
    if (bytes.isEmpty) {
      throw const AttachmentException('Berkas kosong, tidak ada yang dikirim.');
    }
    if (bytes.length > ChatAttachment.maxBytes) {
      throw AttachmentException(
        'Ukuran berkas melebihi '
        '${ChatAttachment.maxBytes ~/ (1024 * 1024)} MB. '
        'Pilih berkas yang lebih kecil.',
      );
    }
    if (!ChatAttachment.supportedMimeTypes.contains(mimeType)) {
      throw const AttachmentException(
        'Jenis berkas ini belum didukung. Gunakan gambar, PDF, atau teks.',
      );
    }

    return ChatAttachment(
      name: name.trim().isEmpty ? 'Lampiran' : name.trim(),
      mimeType: mimeType,
      size: bytes.length,
      bytes: bytes,
    );
  }

  /// `image_picker` and `file_picker` only report the path on some platforms,
  /// so the extension is the reliable signal.
  String _mimeFromName(String name, String? path) {
    final extension = p
        .extension(name.contains('.') ? name : (path ?? name))
        .replaceFirst('.', '')
        .toLowerCase();

    return switch (extension) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      'md' => 'text/markdown',
      'html' || 'htm' => 'text/html',
      _ => 'application/octet-stream',
    };
  }

  String _pickerMessage(Object error, ImageSource? source) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission') || text.contains('denied')) {
      return source == ImageSource.camera
          ? 'Izin kamera ditolak. Aktifkan lewat pengaturan aplikasi.'
          : 'Izin akses berkas ditolak. Aktifkan lewat pengaturan aplikasi.';
    }
    if (source == ImageSource.camera && text.contains('camera')) {
      return 'Kamera tidak tersedia di perangkat ini.';
    }
    return 'Gagal membuka pemilih berkas. Coba lagi.';
  }
}
