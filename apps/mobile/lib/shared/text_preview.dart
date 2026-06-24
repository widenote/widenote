String previewText(String text, {int maxLength = 80}) {
  final trimmed = text.trim();
  if (trimmed.length <= maxLength) {
    return trimmed;
  }
  return '${trimmed.substring(0, maxLength)}...';
}
