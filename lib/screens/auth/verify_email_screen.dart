import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/utils/app_failure.dart';
import 'package:bookswaphub/data/providers/providers.dart';

/// Signed in but email not verified yet. Protected pages stay locked until it is.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _busy = false;
  DateTime? _lastBackPressTime;

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _check() async {
    setState(() => _busy = true);
    try {
      final ok = await ref.read(authRepositoryProvider).refreshVerification();
      if (!ok && mounted) _toast('Not verified yet. Open the link in the email first.');
      // When verified, the router redirects to /home automatically.
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(authRepositoryProvider).sendVerificationEmail();
      if (mounted) _toast('Verification email sent.');
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentEmailProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: Text('✉️', style: TextStyle(fontSize: 64))),
                const SizedBox(height: 16),
                Text('Verify your email',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Text(
                  'We sent a link to $email. Open it, then come back and tap the button below.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(fontSize: 16, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _busy ? null : _check,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(_busy ? 'Checking...' : "I've verified my email"),
                ),
                TextButton(onPressed: _resend, child: const Text('Resend email')),
                TextButton(
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  child: const Text('Use a different account'),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
