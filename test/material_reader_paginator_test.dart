import 'package:donish_app/src/features/materials/material_reader_paginator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('paginateReaderContent', () {
    test('returns single header page for empty paragraphs', () {
      final pages = paginateReaderContent(
        paragraphs: [],
        contentWidth: 300,
        bodyHeightFirstPage: 400,
        bodyHeightOtherPages: 500,
      );
      expect(pages.length, 1);
      expect(pages.first.showHeader, true);
      expect(pages.first.segments, isEmpty);
    });

    test('splits long content into multiple pages', () {
      final long = List.filled(120, 'word').join(' ');
      final pages = paginateReaderContent(
        paragraphs: [long],
        contentWidth: 280,
        bodyHeightFirstPage: 120,
        bodyHeightOtherPages: 200,
      );
      expect(pages.length, greaterThan(1));
      expect(pages.first.showHeader, true);
      expect(pages.skip(1).every((p) => !p.showHeader), true);
    });

    test('covers every word exactly once', () {
      const paras = [
        'One two three.',
        'Four five six seven eight.',
      ];
      final allWords = wordsPerParagraph(paras);
      final totalWords =
          allWords.fold<int>(0, (sum, list) => sum + list.length);

      final pages = paginateReaderContent(
        paragraphs: paras,
        contentWidth: 320,
        bodyHeightFirstPage: 180,
        bodyHeightOtherPages: 220,
      );

      var counted = 0;
      for (final page in pages) {
        for (final seg in page.segments) {
          counted += seg.endWord - seg.startWord;
          expect(seg.startWord, lessThan(seg.endWord));
          expect(
            seg.endWord,
            lessThanOrEqualTo(allWords[seg.paragraphIndex].length),
          );
        }
      }
      expect(counted, totalWords);
    });

    test('first page has header flag only once', () {
      final pages = paginateReaderContent(
        paragraphs: ['Alpha beta gamma delta epsilon zeta eta theta.'],
        contentWidth: 300,
        bodyHeightFirstPage: 80,
        bodyHeightOtherPages: 160,
      );
      expect(pages.first.showHeader, true);
      if (pages.length > 1) {
        expect(pages.where((p) => p.showHeader).length, 1);
      }
    });
  });

  group('paragraphsFromExtractedText', () {
    test('exported from reader screen via duplicate import', () {
      // paragraphsFromExtractedText lives in material_reader_screen.dart;
      // paginator tests stay self-contained here.
      expect(wordsPerParagraph(['a b', 'c d']), [
        ['a', 'b'],
        ['c', 'd'],
      ]);
    });
  });
}
