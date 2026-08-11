import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleAuthAction(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Giriş sırasında bir hata oluştu.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Giriş sırasında bir hata oluştu: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.school,
                  size: 96,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Öğrenme Asistanı',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 48),
                if (_isLoading)
                  const CircularProgressIndicator()
                else ...[
                  FilledButton.icon(
                    onPressed: () => _handleAuthAction(
                      () async => AuthService.signInWithGoogle(),
                    ),
                    icon: const Icon(Icons.login),
                    label: const Text('Google ile Giriş Yap'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => _handleAuthAction(
                      () async => AuthService.signInAnonymously(),
                    ),
                    child: const Text('Misafir olarak devam et'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
