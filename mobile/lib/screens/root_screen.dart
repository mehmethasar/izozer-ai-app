import 'package:flutter/material.dart';
import 'package:mazdek_ai/app/app_scope.dart';
import 'package:mazdek_ai/screens/login_screen.dart';
import 'package:mazdek_ai/screens/password_change_screen.dart';
import 'package:mazdek_ai/screens/shell_screen.dart';

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});
  @override Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.initialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!state.authenticated) return const LoginScreen();
    if (state.locked) return const _LockScreen();
    if (state.user?.mustChangePassword == true) return const PasswordChangeScreen(requiredChange: true);
    return const ShellScreen();
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen();
  @override Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(body: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.lock_person_outlined, size: 76), const SizedBox(height: 18), Text('Mazdek Kilitli', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 8), const Text('Finansal verileri görüntülemek için kimliğinizi doğrulayın.', textAlign: TextAlign.center), const SizedBox(height: 22), FilledButton.icon(onPressed: state.busy ? null : state.unlock, icon: const Icon(Icons.fingerprint), label: const Text('Kilidi Aç')), TextButton(onPressed: state.logout, child: const Text('Oturumu Kapat'))])))));
  }
}
