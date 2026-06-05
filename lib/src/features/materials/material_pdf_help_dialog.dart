import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';

/// Explains PDF upload limits and server-side PDF extraction.
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
          'Gotcha reads your PDF on our server (text extraction + OCR for scans). It works for digital PDFs and scanned pages.\n\n'
          'Works well:\n'
          '• PDFs from Word, Google Docs, or websites.\n'
          '• Scans and photos saved as PDF (clear text helps).\n\n'
          'May fail or need editing:\n'
          '• Blurry or very low-contrast scans.\n'
          '• Password-protected or corrupted files.\n\n'
          'Limits: PDF only, up to about 30 pages and 10 MB. Extraction can take 1–2 minutes.',
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
        msg.contains('no text we can read') ||
        msg.contains('could not find readable text');
    final unreadablePdf = error.code == 'pdf_unreadable' ||
        (msg.contains('Could not read this PDF') && !noExtractableText) ||
        msg.contains('Could not extract text');
    final tooLarge = error.code == 'payload_too_large' ||
        error.statusCode == 413 ||
        msg.toLowerCase().contains('too large');
    final textractUnavailable = error.code == 'textract_not_configured' ||
        error.code == 'textract_timeout';

    if (tooLarge) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'PDF too large',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Text(
              'This file is larger than we can accept (about 10 MB). '
              'Try a shorter PDF, fewer pages, or export with lower image quality.\n\n'
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

    if (textractUnavailable) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Extraction unavailable',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Text(
              'Text extraction is temporarily unavailable or took too long. '
              'Try again in a moment, or use a smaller PDF (fewer pages).\n\n'
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
              'We could not detect readable text in this file. '
              'Try a clearer scan, re-export the PDF, or another copy of the document.\n\n'
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
