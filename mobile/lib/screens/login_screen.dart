import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mazdek_ai/app/app_scope.dart';
import 'package:mazdek_ai/core/config/app_config.dart';
import 'package:mazdek_ai/core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final server = TextEditingController();
  bool obscure = true;
  bool testing = false;
  String? serverResult;

  @override
  void initState() {
    super.initState();
    if (AppConfig.allowsCustomApiUrl) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadServer());
    }
  }

  Future<void> _loadServer() async {
    server.text = await AppScope.of(context).settings.apiBaseUrl();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    server.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    setState(() {
      testing = true;
      serverResult = null;
    });
    try {
      final state = AppScope.of(context);
      await state.settings.setApiBaseUrl(server.text);
      final health = await state.api.health();
      if (mounted) {
        setState(() {
          serverResult = '${health['service'] ?? 'Mazdek API'} • ${health['status'] ?? 'ok'}';
        });
      }
    } catch (e) {
      if (mounted) setState(() => serverResult = e.toString());
    } finally {
      if (mounted) setState(() => testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final appleAvailable = Platform.isIOS ||
        (Platform.isAndroid && AppConfig.appleServiceId.isNotEmpty && AppConfig.appleRedirectUri.isNotEmpty);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: AppTheme.orange, borderRadius: BorderRadius.circular(18)),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Mazdek',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gelir-gider, proje, cari, personel ve raporlarınız tek yapay zekâ sohbetinde.',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.email_outlined)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: obscure,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => state.login(email.text, password.text),
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                  ),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: state.busy ? null : () => state.login(email.text, password.text),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: state.busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Giriş Yap'),
                    ),
                  ),
                  if (appleAvailable) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: state.busy ? null : state.appleLogin,
                      icon: const Icon(Icons.apple),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Apple ile Giriş Yap'),
                      ),
                    ),
                  ],
                  if (AppConfig.allowsCustomApiUrl) ...[
                    const SizedBox(height: 22),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Geliştirme sunucusu'),
                      leading: const Icon(Icons.dns_outlined),
                      children: [
                        TextField(
                          controller: server,
                          autocorrect: false,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'API adresi',
                            hintText: 'http://10.0.2.2:8787',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonalIcon(
                            onPressed: testing ? null : _saveAndTest,
                            icon: const Icon(Icons.network_check),
                            label: Text(testing ? 'Kontrol ediliyor' : 'Kaydet ve Test Et'),
                          ),
                        ),
                        if (serverResult != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Align(alignment: Alignment.centerLeft, child: Text(serverResult!)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
