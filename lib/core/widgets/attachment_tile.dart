import 'package:flutter/material.dart';
import 'package:indonesia_law/core/models/chat_attachment.dart';

/// Square thumbnail for one attachment: the photo itself when it is an image,
/// a typed icon otherwise.
///
/// [onRemove] is only passed by the composer — sent bubbles are read-only.
class AttachmentThumbnail extends StatelessWidget {
  const AttachmentThumbnail({
    super.key,
    required this.attachment,
    this.size = 72,
    this.onRemove,
  });

  final ChatAttachment attachment;
  final double size;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final bytes = attachment.bytes;
    final showsImage = attachment.isImage && bytes != null;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x26FFFFFF)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: showsImage
                    ? Image.memory(bytes, fit: BoxFit.cover)
                    : _FileFace(attachment: attachment),
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: -6,
              right: -6,
              child: _RemoveBadge(onTap: onRemove!, label: attachment.name),
            ),
        ],
      ),
    );
  }
}

/// Icon plus extension, shown when there is no image to preview.
class _FileFace extends StatelessWidget {
  const _FileFace({required this.attachment});

  final ChatAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          iconFor(attachment),
          size: 22,
          color: Colors.white.withValues(alpha: 0.75),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            labelFor(attachment),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _RemoveBadge extends StatelessWidget {
  const _RemoveBadge({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Hapus lampiran $label',
      child: Material(
        color: const Color(0xFF2A2A2A),
        shape: const CircleBorder(side: BorderSide(color: Color(0x40FFFFFF))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Name and size on one line, used inside a sent bubble where the file has no
/// preview worth showing.
class AttachmentNameRow extends StatelessWidget {
  const AttachmentNameRow({super.key, required this.attachment});

  final ChatAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          iconFor(attachment),
          size: 15,
          color: Colors.white.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            attachment.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12.5,
            ),
          ),
        ),
        if (attachment.size > 0) ...[
          const SizedBox(width: 6),
          Text(
            attachment.readableSize,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11.5,
            ),
          ),
        ],
      ],
    );
  }
}

IconData iconFor(ChatAttachment attachment) {
  if (attachment.isImage) return Icons.image_outlined;
  return switch (attachment.mimeType) {
    'application/pdf' => Icons.picture_as_pdf_outlined,
    'text/csv' => Icons.table_chart_outlined,
    _ => Icons.description_outlined,
  };
}

/// Extension in caps, e.g. `PDF`. Falls back to the name when there is none.
String labelFor(ChatAttachment attachment) {
  final dot = attachment.name.lastIndexOf('.');
  if (dot <= 0 || dot == attachment.name.length - 1) return attachment.name;
  return attachment.name.substring(dot + 1).toUpperCase();
}
