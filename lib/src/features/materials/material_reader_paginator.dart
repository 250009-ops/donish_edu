import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

/// Layout metrics shared with [MaterialReaderScreen] word chips.
class MaterialReaderMetrics {
  MaterialReaderMetrics._();

  static const double horizontalPadding = 24;
  static const double pageTopPadding = 20;
  static const double pageBottomPadding = 32;

  static const double wordFontSize = 16;
  static const double wordLineHeight = 1.6;
  static const double chipHorizontalPadding = 2;
  static const double chipVerticalPadding = 1;
  static const double wrapSpacing = 4;
  static const double wrapRunSpacing = 6;
  static const double paragraphGap = 16;

  static const String hintText =
      'Purple words are already known. Tap any word for Uzbek meaning.';

  static const double titleFontSize = 24;
  static const double titleLineHeight = 1.25;
  static const double titleBottomGap = 8;
  static const double hintFontSize = 14;
  static const double hintLineHeight = 1.4;
  static const double headerBodyGap = 24;

  static TextStyle wordTextStyle() => GoogleFonts.inter(
        fontSize: wordFontSize,
        fontWeight: FontWeight.w400,
        height: wordLineHeight,
      );

  static TextStyle titleTextStyle() => GoogleFonts.inter(
        fontSize: titleFontSize,
        fontWeight: FontWeight.w700,
        height: titleLineHeight,
      );

  static TextStyle hintTextStyle() => GoogleFonts.inter(
        fontSize: hintFontSize,
        fontWeight: FontWeight.w400,
        height: hintLineHeight,
      );

  static double chipHeight(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: 'Mg', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.height + chipVerticalPadding * 2;
  }

  static double measureChipWidth(String word, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: '$word ', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width + chipHorizontalPadding * 2;
  }

  static double measureHeaderHeight({
    required String title,
    required double maxWidth,
  }) {
    double blockHeight(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: maxWidth);
      return painter.height;
    }

    return blockHeight(title, titleTextStyle()) +
        titleBottomGap +
        blockHeight(hintText, hintTextStyle()) +
        headerBodyGap;
  }
}

/// Words [startWord] (inclusive) .. [endWord] (exclusive) from one paragraph.
class ReaderWordSegment {
  const ReaderWordSegment({
    required this.paragraphIndex,
    required this.startWord,
    required this.endWord,
  });

  final int paragraphIndex;
  final int startWord;
  final int endWord;

  bool get isEmpty => startWord >= endWord;
}

/// One horizontally swiped reader page.
class ReaderPage {
  const ReaderPage({
    required this.showHeader,
    required this.segments,
  });

  final bool showHeader;
  final List<ReaderWordSegment> segments;
}

List<List<String>> wordsPerParagraph(List<String> paragraphs) {
  return paragraphs
      .map(
        (p) => p.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList(),
      )
      .toList();
}

/// Splits material paragraphs into fixed-height pages matching Wrap chip layout.
List<ReaderPage> paginateReaderContent({
  required List<String> paragraphs,
  required double contentWidth,
  required double bodyHeightFirstPage,
  required double bodyHeightOtherPages,
  TextStyle? wordStyle,
}) {
  if (paragraphs.isEmpty || contentWidth <= 0) {
    return [const ReaderPage(showHeader: true, segments: [])];
  }

  final style = wordStyle ?? MaterialReaderMetrics.wordTextStyle();
  final chipH = MaterialReaderMetrics.chipHeight(style);
  final lineStep = chipH + MaterialReaderMetrics.wrapRunSpacing;
  final allWords = wordsPerParagraph(paragraphs);

  final pages = <ReaderPage>[];
  var showHeader = true;
  var pageLimit = bodyHeightFirstPage;
  var y = 0.0;
  var x = 0.0;
  var segments = <ReaderWordSegment>[];

  void commitPage() {
    pages.add(ReaderPage(showHeader: showHeader, segments: segments));
    segments = [];
    showHeader = false;
    pageLimit = bodyHeightOtherPages;
    y = 0;
    x = 0;
  }

  bool fits(double heightNeeded) => y + heightNeeded <= pageLimit + 0.5;

  void newPageIfNeeded(double heightNeeded) {
    if (!fits(heightNeeded)) {
      if (segments.isNotEmpty) commitPage();
      if (!fits(heightNeeded) && heightNeeded > pageLimit) {
        // Single word taller than page — still render on empty page.
      }
    }
  }

  void endLine() {
    y += lineStep;
    x = 0;
  }

  void addParagraphGap() {
    if (y <= 0 && x <= 0) return;
    if (x > 0) endLine();
    if (y <= 0) return;
    final gap = MaterialReaderMetrics.paragraphGap;
    newPageIfNeeded(gap + chipH);
    if (y > 0) y += gap;
  }

  void openSegment(int pIdx, int wIdx) {
    segments = [
      ...segments,
      ReaderWordSegment(
        paragraphIndex: pIdx,
        startWord: wIdx,
        endWord: wIdx + 1,
      ),
    ];
  }

  void appendToLastSegment(int pIdx, int wIdx) {
    if (segments.isEmpty) {
      openSegment(pIdx, wIdx);
      return;
    }
    final last = segments.last;
    if (last.paragraphIndex == pIdx && last.endWord == wIdx) {
      segments[segments.length - 1] = ReaderWordSegment(
        paragraphIndex: pIdx,
        startWord: last.startWord,
        endWord: wIdx + 1,
      );
    } else {
      openSegment(pIdx, wIdx);
    }
  }

  void placeWord(int pIdx, int wIdx, String word) {
    final chipW = MaterialReaderMetrics.measureChipWidth(word, style);
    final extra = x > 0 ? MaterialReaderMetrics.wrapSpacing + chipW : chipW;

    if (x > 0 && x + extra > contentWidth + 0.5) {
      endLine();
      placeWord(pIdx, wIdx, word);
      return;
    }

    if (x == 0) {
      newPageIfNeeded(chipH);
    }

    if (x == 0) {
      openSegment(pIdx, wIdx);
    } else {
      appendToLastSegment(pIdx, wIdx);
    }

    x += extra;
  }

  for (var p = 0; p < allWords.length; p++) {
    final words = allWords[p];
    if (words.isEmpty) continue;
    if (p > 0) addParagraphGap();
    for (var w = 0; w < words.length; w++) {
      placeWord(p, w, words[w]);
    }
    if (x > 0) endLine();
  }

  if (segments.isNotEmpty) commitPage();

  if (pages.isEmpty) {
    return [const ReaderPage(showHeader: true, segments: [])];
  }
  return pages;
}
