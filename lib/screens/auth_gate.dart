import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/screens/avatar_selection_screen.dart';
import 'package:ogrenme_asistani/screens/login_screen.dart';
import 'package:ogrenme_asistani/screens/main_screen.dart';
import 'package:ogrenme_asistani/services/assistant_profile_repository.dart';
import 'package:ogrenme_asistani/services/auth_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        return _AssistantOnboardingGate(uid: user.uid);
      },
    );
  }
}

class _AssistantOnboardingGate extends StatefulWidget {
  const _AssistantOnboardingGate({required this.uid});

  final String uid;

  @override
  State<_AssistantOnboardingGate> createState() =>
      _AssistantOnboardingGateState();
}

class _AssistantOnboardingGateState extends State<_AssistantOnboardingGate> {
  final _repository = AssistantProfileRepository();
  bool _hasProfile = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    final profile = await _repository.load(widget.uid);
    if (!mounted) return;
    setState(() {
      _hasProfile = profile != null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_hasProfile) {
      return AvatarSelectionScreen(
        onSaved: (_) => setState(() => _hasProfile = true),
      );
    }
    return const MainScreen();
  }
}
