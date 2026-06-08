import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/app_branding.dart';

Future<void> showDeviceLimitDialog(
  BuildContext context, {
  required int maxDevices,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Device limit reached',
        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      content: Text(
        'This account is already signed in on $maxDevices devices. '
        'Log out on another device, or open Gotcha on a device that is already authorized and choose '
        '"Free other devices" from your profile menu.',
        style: GoogleFonts.inter(fontSize: 14, height: 1.45, color: const Color(0xFF4B5563)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('OK', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        ),
        FilledButton(
          onPressed: () async {
            final uri = Uri.parse('https://t.me/${AppConfig.telegramBotUsername}');
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          style: FilledButton.styleFrom(backgroundColor: AppBranding.primary),
          child: Text(
            'Open Telegram',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
