import 'package:flutter/material.dart';
import 'package:mazdek_ai/app/app_scope.dart';

class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({this.requiredChange = false, super.key});
  final bool requiredChange;

  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final current = TextEditingController();
  final next = TextEditingController();
  final repeat = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    repeat.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (next.text != repeat.text) {
      setState(() => error = 'Yeni şifreler eşleşmiyor.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final state = AppScope.of(context);
      await state.api.changePassword(current.text, next.text);
      await state.reloadUser();
      if (!widget.requiredChange && mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.requiredChange ? null : AppBar(title: const Text('Şifre Değiştir')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.password, size: 58, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 18),
                  Text(
                    widget.requiredChange ? 'Geçici şifrenizi değiştirin' : 'Şifrenizi değiştirin',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'Mevcut şifre')),
                  const SizedBox(height: 12),
                  TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'Yeni güçlü şifre')),
                  const SizedBox(height: 12),
                  TextField(controller: repeat, obscureText: true, decoration: const InputDecoration(labelText: 'Yeni şifre tekrar')),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: const Padding(padding: EdgeInsets.all(12), child: Text('Şifreyi Güncelle')),
                  ),
                  if (widget.requiredChange)
                    TextButton(onPressed: AppScope.of(context).logout, child: const Text('Oturumu Kapat')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
