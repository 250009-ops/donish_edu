import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';

class MaterialReaderScreen extends StatelessWidget {
  const MaterialReaderScreen({
    super.key,
    required this.materialTitle,
  });

  final String materialTitle;

  @override
  Widget build(BuildContext context) {
    // This is a placeholder text reader; you can later replace it with a real
    // PDF viewer that supports text selection.
    const sampleText =
        'Climate change is one of the most pressing global challenges. '
        'When you tap on an unknown word, Donish will show you its natural Uzbek translation.';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          materialTitle,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _TappableText(sampleText: sampleText),
      ),
    );
  }
}

class _TappableText extends StatelessWidget {
  const _TappableText({required this.sampleText});

  final String sampleText;

  @override
  Widget build(BuildContext context) {
    final words = sampleText.split(' ');
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: words
          .map(
            (w) => GestureDetector(
              onTap: () => _onWordTap(context, w),
              child: Text(
                '$w ',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _onWordTap(BuildContext context, String word) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _TranslationSheet(word: word, contextSentence: sampleText);
      },
    );
  }
}

class _TranslationSheet extends StatefulWidget {
  const _TranslationSheet({
    required this.word,
    required this.contextSentence,
  });

  final String word;
  final String contextSentence;

  @override
  State<_TranslationSheet> createState() => _TranslationSheetState();
}

class _TranslationSheetState extends State<_TranslationSheet> {
  String? _translation;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTranslation();
  }

  Future<void> _fetchTranslation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final json = await ApiClient.instance.postJson(
        '/translate',
        body: {
          'word': widget.word,
          'context_sentence': widget.contextSentence,
        },
        authenticated: true,
      );
      setState(() {
        _translation = json['translation_uz'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text(
            widget.word,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'English \u2192 Uzbek',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Text(
              _error!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.red,
              ),
            )
          else
            Text(
              _translation ?? '',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFF111827),
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _translation == null ? null : _saveToVocab,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4C6FFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Save to Vocabulary Bank'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToVocab() async {
    if (_translation == null) return;
    try {
      await ApiClient.instance.postJson(
        '/vocab',
        authenticated: true,
        body: {
          'word': widget.word,
          'translation_uz': _translation,
          'context_sentence': widget.contextSentence,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to Vocabulary Bank'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}

