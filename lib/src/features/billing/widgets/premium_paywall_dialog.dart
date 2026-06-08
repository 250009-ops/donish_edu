import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_branding.dart';
import '../models/subscription_info.dart';
import 'premium_upgrade_sheet.dart';

Future<void> showPremiumPaywallDialog(
  BuildContext context, {
  required String title,
  required String message,
  required SubscriptionInfo subscription,
  required Future<String> Function() onCreateCheckout,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      content: Text(
        message,
        style: GoogleFonts.inter(fontSize: 14, height: 1.45, color: const Color(0xFF4B5563)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Not now', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            showPremiumUpgradeSheet(
              context,
              subscription: subscription,
              onCreateCheckout: onCreateCheckout,
              reason: message,
            );
          },
          style: FilledButton.styleFrom(backgroundColor: AppBranding.primary),
          child: Text(
            'Upgrade',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
