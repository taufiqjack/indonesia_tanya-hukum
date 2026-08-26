import 'package:flutter/material.dart';
import 'package:indonesia_law/core/models/citation.dart';
import 'package:indonesia_law/core/pages/article/article_web_view.dart';

/// References under an answer: the articles it rests on, each opening in the
/// in-app reader.
///
/// Kept compact — a row per reference, article number first — so a long list
/// of them never pushes the answer itself off the screen.
class CitationList extends StatelessWidget {
  const CitationList({super.key, required this.citations});

  static const _surface = Color(0xFF121212);
  static const _border = Color(0x1AFFFFFF);

  final List<Citation> citations;

  @override
  Widget build(BuildContext context) {
    if (citations.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 14,
                color: Colors.white.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 6),
              Text(
                'Rujukan Pasal',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final citation in citations)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _CitationTile(citation: citation),
            ),
        ],
      ),
    );
  }
}

class _CitationTile extends StatelessWidget {
  const _CitationTile({required this.citation});

  final Citation citation;

  void _open(BuildContext context) {
    final link = citation.link;
    if (link == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleWebView(url: link, title: citation.label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = citation.detail;

    return Material(
      color: CitationList._surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CitationList._border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                citation.isWeb
                    ? Icons.public_rounded
                    : Icons.gavel_rounded,
                size: 15,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      citation.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.open_in_new_rounded,
                size: 15,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
