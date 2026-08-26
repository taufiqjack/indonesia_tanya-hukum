import 'package:indonesia_law/core/config/env.dart';
import 'package:indonesia_law/core/consts/constants.dart';

/// A reference the assistant leaned on when answering.
///
/// Two kinds arrive: a `database` citation points at an article in the app's
/// own library and is read at `DOMAIN/article/<id>`, while a `web` citation
/// carries the address it was found at.
class Citation {
  const Citation({
    required this.id,
    this.source = 'database',
    this.title,
    this.articleNumber,
    this.type,
    this.url,
    this.domain,
    this.snippet,
  });

  final String id;
  final String source;
  final String? title;
  final String? articleNumber;
  final String? type;
  final String? url;
  final String? domain;
  final String? snippet;

  bool get isWeb => source.toLowerCase() == 'web';

  /// Where tapping the citation leads, or null when it names no readable page.
  String? get link {
    if (isWeb) {
      final address = url?.trim();
      return address == null || address.isEmpty ? null : address;
    }
    if (id.isEmpty || !Env.hasDomain) return null;
    return Env.apiUri(articlePage.replaceFirst('{id}', id)).toString();
  }

  /// Article number first — it is what a reader looks for — with the title as
  /// the fallback, and the source's own host for a web reference.
  String get label {
    final number = articleNumber?.trim();
    if (number != null && number.isNotEmpty) return number;

    final name = title?.trim();
    if (name != null && name.isNotEmpty) return name;

    final host = domain?.trim();
    if (host != null && host.isNotEmpty) return host;

    return isWeb ? 'Sumber web' : 'Rujukan';
  }

  /// Line under the label: the article's title, or the host a web reference
  /// came from. Null when it would only repeat [label].
  String? get detail {
    final name = title?.trim();
    if (name != null && name.isNotEmpty && name != label) return name;

    final host = domain?.trim();
    if (host != null && host.isNotEmpty && host != label) return host;

    return null;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'source': source,
    if (title != null) 'title': title,
    if (articleNumber != null) 'article_number': articleNumber,
    if (type != null) 'type': type,
    if (url != null) 'url': url,
    if (domain != null) 'domain': domain,
    if (snippet != null) 'snippet': snippet,
  };

  factory Citation.fromJson(Map<String, Object?> json) => Citation(
    id: json['id']?.toString() ?? '',
    source: _string(json['source']) ?? 'database',
    title: _string(json['title']),
    articleNumber: _string(json['article_number']),
    type: _string(json['type']),
    url: _string(json['url']),
    domain: _string(json['domain']),
    snippet: _string(json['snippet']),
  );

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
