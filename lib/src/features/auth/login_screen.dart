import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/auth_repository.dart';
import '../../core/config/app_branding.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../billing/widgets/device_limit_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onAuthenticated});

  /// Called when authentication succeeds with the numeric user ID.
  final void Function(String userId) onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository(ApiClient.instance);
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final result = await _authRepository.login(
        id: _idController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      widget.onAuthenticated(result.userId);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (e.code == 'device_limit_reached') {
        await showDeviceLimitDialog(context, maxDevices: 3);
        return;
      }
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        final detail = e.toString().replaceFirst(RegExp(r'^\w+Exception:\s*'), '');
        _errorMessage = detail.isNotEmpty
            ? detail
            : 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _openTelegramBot() async {
    final uri = Uri.parse(
      'https://t.me/${AppConfig.telegramBotUsername}',
    );
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showLaunchError(uri.toString());
      }
    } catch (_) {
      if (mounted) _showLaunchError(uri.toString());
    }
  }

  void _showLaunchError(String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not open. Copy and open in browser: $url'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppBranding.primary,
              AppBranding.primaryLight,
              Color(0xFFE8D9FF),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLogoBlock(),
                const SizedBox(height: 32),
                _buildCard(context),
                const SizedBox(height: 16),
                Text(
                  'Secure verification powered by Telegram',
                  style: AppBranding.wordmark(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoBlock() {
    return Text(
      AppBranding.displayName,
      style: AppBranding.wordmark(
        fontSize: 52,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sign in to ${AppBranding.displayName}',
              style: AppBranding.wordmark(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1B2559),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Use the ID and password you got from our Telegram bot.',
              style: AppBranding.wordmark(
                fontSize: 13,
                color: const Color(0xFF6B7280),
                fontWeight: FontWeight.w400,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: AppBranding.wordmark(
                  fontSize: 13,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
            const SizedBox(height: 20),
            TextFormField(
              controller: _idController,
              decoration: _inputDecoration('ID'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your ID';
                }
                if (int.tryParse(value.trim()) == null) {
                  return 'ID must be numbers only';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: _inputDecoration('Password').copyWith(
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
              obscureText: _obscurePassword,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Ink(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF8840FE), Color(0xFF9B5FFF)],
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Center(
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Text(
                    'Don’t have an account yet?',
                    style: AppBranding.wordmark(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _TelegramBotButton(onPressed: _openTelegramBot),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF8840FE),
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

class _TelegramBotButton extends StatelessWidget {
  const _TelegramBotButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppBranding.primary,
          backgroundColor: AppBranding.primary.withOpacity(0.08),
          side: const BorderSide(color: AppBranding.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/telegram.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppBranding.primary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Open Telegram Bot',
              style: AppBranding.wordmark(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppBranding.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

