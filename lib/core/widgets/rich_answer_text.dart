import 'package:flutter/material.dart';

/// Renders the subset of Markdown that Gemini answers actually use:
/// `**bold**`, `*italic*`, `` `code` ``, `#` headings and `-`/`1.` lists.
///
/// A full Markdown package would be overkill here — answers are short prose.
class RichAnswerText extends StatelessWidget {
  const RichAnswerText({
    super.key,
    required this.text,
    required this.color,
    this.fontSize = 15,
  });

  final String text;
  final Color color;
  final double fontSize;

  static final _bulletPattern = RegExp(r'^\s*[-*•]\s+');
  static final _numberedPattern = RegExp(r'^\s*(\d+)[.)]\s+');
  static final _headingPattern = RegExp(r'^\s*(#{1,6})\s+');

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(color: color, fontSize: fontSize, height: 1.55);
    final blocks = <Widget>[];

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        blocks.add(const SizedBox(height: 8));
        continue;
      }

      final heading = _headingPattern.firstMatch(line);
      if (heading != null) {
        blocks.add(
          Padding(
            padding: EdgeInsets.only(top: blocks.isEmpty ? 0 : 6, bottom: 2),
            child: Text.rich(
              _inline(
                line.substring(heading.end),
                base.copyWith(
                  fontSize: fontSize + 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
        continue;
      }

      final numbered = _numberedPattern.firstMatch(line);
      if (numbered != null) {
        blocks.add(
          _ListRow(
            marker: '${numbered.group(1)}.',
            style: base,
            content: _inline(line.substring(numbered.end), base),
          ),
        );
        continue;
      }

      if (_bulletPattern.hasMatch(line)) {
        blocks.add(
          _ListRow(
            marker: '•',
            style: base,
            content: _inline(
              line.substring(_bulletPattern.firstMatch(line)!.end),
              base,
            ),
          ),
        );
        continue;
      }

      blocks.add(Text.rich(_inline(line, base)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  /// Splits a line into styled spans for `**bold**`, `*italic*` and `` `code` ``.
  static TextSpan _inline(String line, TextStyle base) {
    final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`');
    final spans = <InlineSpan>[];
    var index = 0;

    for (final match in pattern.allMatches(line)) {
      if (match.start > index) {
        spans.add(TextSpan(text: line.substring(index, match.start)));
      }

      if (match.group(1) != null) {
        spans.add(
          TextSpan(
            text: match.group(1),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (match.group(2) != null) {
        spans.add(
          TextSpan(
            text: match.group(2),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: match.group(3),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: base.fontSize! - 1,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        );
      }
      index = match.end;
    }

    if (index < line.length) {
      spans.add(TextSpan(text: line.substring(index)));
    }

    return TextSpan(style: base, children: spans);
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.marker,
    required this.style,
    required this.content,
  });

  final String marker;
  final TextStyle style;
  final TextSpan content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 22, child: Text(marker, style: style)),
          Expanded(child: Text.rich(content)),
        ],
      ),
    );
  }
}
