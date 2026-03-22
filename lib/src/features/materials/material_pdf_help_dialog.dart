import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';

/// Explains text-based PDFs vs scans (proactive help + reusable for “About”).
void showPdfMaterialsHelpDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        'Which PDFs work?',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Text(
          'Donish reads real text inside your PDF—not pictures of pages.\n\n'
          'Works well:\n'
          '• PDFs exported from Word, Google Docs, or websites that offer a download.\n'
          '• “Print to PDF” from anything where you can select and copy text.\n\n'
          'Often fails:\n'
          '• Scans or photos saved as PDF (image-only pages).\n'
          '• Files that need OCR (we do not support OCR yet).\n\n'
          'Limits: text-based PDF, up to about 10 pages and 4 MB.',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.45,
            color: const Color(0xFF374151),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child:
              Text('Got it', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

void showMaterialUploadError(BuildContext context, Object error) {
  if (error is ApiException) {
    final msg = error.message;
    final noExtractableText = error.code == 'pdf_no_extractable_text' ||
        msg.contains('No readable text') ||
        msg.contains('no text we can read');
    final unreadablePdf = error.code == 'pdf_unreadable' ||
        (msg.contains('Could not read this PDF') && !noExtractableText);

    if (noExtractableText) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'No text found in this PDF',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Text(
              'This file looks like a scan or image-only PDF: there are no words for us to read. '
              'Donish does not use OCR (photo-to-text) yet.\n\n'
              'Try:\n'
              '• A PDF downloaded from a source that provides real text.\n'
              '• Export or “Print to PDF” from Word, Google Docs, or similar.\n'
              '• Another version of the same content if you have one.\n\n'
              'Details: ${error.message}',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                color: const Color(0xFF374151),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('OK', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      return;
    }
    if (unreadablePdf) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Could not read this PDF',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Text(
              'The file might be corrupted, password-protected, or not a valid PDF. '
              'Try re-downloading it or exporting again from the original app.\n\n'
              'Details: ${error.message}',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                color: const Color(0xFF374151),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('OK', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      return;
    }
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        error.toString(),
        style: GoogleFonts.inter(),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
