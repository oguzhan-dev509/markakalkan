String? resolveInitialCounterfeitTwinSlug(Uri uri) {
  final fragment = uri.fragment.trim();
  if (fragment.isNotEmpty) {
    final fragmentUri = Uri.tryParse(
      fragment.startsWith('/') ? fragment : '/$fragment',
    );
    final slug = _counterfeitTwinSlugFromSegments(
      fragmentUri?.pathSegments ?? const <String>[],
    );
    if (slug != null) {
      return slug;
    }
  }

  return _counterfeitTwinSlugFromSegments(uri.pathSegments);
}

String? _counterfeitTwinSlugFromSegments(List<String> rawSegments) {
  final segments = rawSegments
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);

  if (segments.length != 2 || segments.first != 'sahte-ikiz') {
    return null;
  }

  final slug = segments.last.trim();
  return slug.isEmpty ? null : slug;
}
