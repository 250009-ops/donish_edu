import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_branding.dart';
import '../models/subscription_info.dart';

Future<void> showPremiumUpgradeSheet(
  BuildContext context, {
  required SubscriptionInfo subscription,
  required Future<String> Function() onCreateCheckout,
  String? reason,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return _PremiumUpgradeSheet(
        subscription: subscription,
        onCreateCheckout: onCreateCheckout,
        reason: reason,
      );
    },
  );
}

class _PremiumUpgradeSheet extends StatefulWidget {
  const _PremiumUpgradeSheet({
    required this.subscription,
    required this.onCreateCheckout,
    this.reason,
  });

  final SubscriptionInfo subscription;
  final Future<String> Function() onCreateCheckout;
  final String? reason;

  @override
  State<_PremiumUpgradeSheet> createState() => _PremiumUpgradeSheetState();
}

class _PremiumUpgradeSheetState extends State<_PremiumUpgradeSheet> {
  bool _loading = false;
  String? _error;

  Future<void> _continueToCheckout() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await widget.onCreateCheckout();
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        setState(() => _error = 'Could not open checkout. Try again.');
        return;
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.subscription.priceUzs;
    final formattedPrice = _formatUzs(price);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Gotcha Premium',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            if (widget.reason != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.reason!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _benefit('Unlimited PDF uploads'),
            _benefit('Unlimited word tap translations'),
            _benefit('Priority processing'),
            _benefit('Personal use · up to ${widget.subscription.limits.maxDevices} devices'),
            const SizedBox(height: 20),
            Text(
              formattedPrice,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppBranding.primary,
              ),
            ),
            Text(
              'per month · billed via Lemon Squeezy',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF6B7280),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFDC2626)),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _continueToCheckout,
              style: FilledButton.styleFrom(
                backgroundColor: AppBranding.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Continue to checkout',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            Text(
              'One account per person. Sharing login credentials is not allowed.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppBranding.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF374151)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatUzs(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '${buf.toString()} UZS';
  }
}
