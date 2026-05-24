String normalizeTappedWord(String raw) {
  return raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r"^[^A-Za-z'’-]+|[^A-Za-z'’-]+$"), '');
}
