import 'package:flutter/material.dart';

/// Bottom inset so floating snackbars sit above the center-docked FAB + nav bar.
const double kDonishSnackBarBottomMargin = 96;

void showDonishSnackBar(
  BuildContext context, {
  required String message,
  Color? backgroundColor,
  Duration duration = const Duration(seconds: 2),
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, kDonishSnackBarBottomMargin),
        backgroundColor: backgroundColor,
      ),
    );
}
