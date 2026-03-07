import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'src/app_shell.dart';
import 'src/features/auth/login_screen.dart';

void main() {
  runApp(const DonishApp());
}

class DonishApp extends StatelessWidget {
  const DonishApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF4C6FFF),
      scaffoldBackgroundColor: const Color(0xFFF5F6FA),
      textTheme: GoogleFonts.interTextTheme(),
    );

    return MaterialApp(
      title: 'Donish',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        appBarTheme: baseTheme.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: const Color(0xFF1B2559),
        ),
      ),
      home: const _RootDecider(),
    );
  }
}

/// In a real app we would check secure storage for a token.
/// For now, always show login then navigate to shell on success.
class _RootDecider extends StatefulWidget {
  const _RootDecider();

  @override
  State<_RootDecider> createState() => _RootDeciderState();
}

class _RootDeciderState extends State<_RootDecider> {
  bool _isAuthenticated = false;

  void _onAuthenticated() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return LoginScreen(onAuthenticated: _onAuthenticated);
    }
    return const AppShell();
  }
}

