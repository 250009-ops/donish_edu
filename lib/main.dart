import 'package:flutter/material.dart';

import 'src/app_shell.dart';

import 'src/core/config/app_branding.dart';
import 'src/core/network/api_client.dart';

import 'src/features/auth/data/auth_repository.dart';

import 'src/features/auth/login_screen.dart';

import 'src/features/onboarding/splash_screen.dart';
import 'src/features/vocab/data/word_lexicon_store.dart';



void main() {

  runApp(const DonishApp());

}



class DonishApp extends StatelessWidget {

  const DonishApp({super.key});



  @override

  Widget build(BuildContext context) {

    final baseTheme = ThemeData(

      useMaterial3: true,

      colorSchemeSeed: AppBranding.primary,

      scaffoldBackgroundColor: const Color(0xFFF5F6FA),

      textTheme: AppBranding.textTheme(),

    );



    return MaterialApp(

      title: AppBranding.displayName,

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



class _RootDecider extends StatefulWidget {

  const _RootDecider();



  @override

  State<_RootDecider> createState() => _RootDeciderState();

}



class _RootDeciderState extends State<_RootDecider>

    with SingleTickerProviderStateMixin {

  final _authRepository = AuthRepository(ApiClient.instance);



  bool _showSplash = true;

  bool _splashFinished = false;

  bool _sessionReady = false;

  bool _isAuthenticated = false;

  String? _userId;



  late final AnimationController _contentFade;



  @override

  void initState() {

    super.initState();

    _contentFade = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 500),

    );

    _restoreSession();

  }



  @override

  void dispose() {

    _contentFade.dispose();

    super.dispose();

  }



  Future<void> _restoreSession() async {

    final userId = await _authRepository.restoreSession();

    if (!mounted) return;

    setState(() {

      _sessionReady = true;

      if (userId != null) {

        _isAuthenticated = true;

        _userId = userId;

      }

    });

    _tryDismissSplash();

  }



  void _onSplashComplete() {

    _splashFinished = true;

    _tryDismissSplash();

  }



  void _tryDismissSplash() {

    if (!_showSplash || !_splashFinished || !_sessionReady) return;

    setState(() => _showSplash = false);

    _contentFade.forward(from: 0);

  }



  void _onAuthenticated(String userId) {

    setState(() {

      _isAuthenticated = true;

      _userId = userId;

    });

  }



  Future<void> _onLogOut() async {

    await _authRepository.logout();

    await WordLexiconStore.instance.clearAll();

    if (!mounted) return;

    setState(() {

      _isAuthenticated = false;

      _userId = null;

    });

  }



  Widget _buildMainContent() {

    if (!_sessionReady) {

      return const SizedBox.shrink();

    }



    if (!_isAuthenticated) {

      return LoginScreen(onAuthenticated: _onAuthenticated);

    }



    return AppShell(

      userId: _userId ?? '',

      onLogOut: _onLogOut,

    );

  }



  @override

  Widget build(BuildContext context) {

    return Stack(

      fit: StackFit.expand,

      children: [

        FadeTransition(

          opacity: CurvedAnimation(

            parent: _contentFade,

            curve: Curves.easeOut,

          ),

          child: IgnorePointer(

            ignoring: _showSplash,

            child: _buildMainContent(),

          ),

        ),

        if (_showSplash)

          SplashScreen(onComplete: _onSplashComplete),

      ],

    );

  }

}


