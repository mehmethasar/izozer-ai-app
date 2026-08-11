import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:mazdek_ai/app/app_scope.dart';
import 'package:mazdek_ai/core/config/app_config.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AccountPrivacyScreen extends StatefulWidget {
  const AccountPrivacyScreen({super.key});
  @override State<AccountPrivacyScreen> createState() => _AccountPrivacyScreenState();
}

class _AccountPrivacyScreenState extends State<AccountPrivacyScreen> {
  bool busy = false;
  String? message;

  String nonce([int length = 32]) {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> exportData() async {
    setState(() => busy = true);
    try {
      final file = await AppScope.of(context).api.exportAccountData();
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Mazdek hesap verileri'));
    } catch (e) { if (mounted) setState(() => message = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> toggleApple() async {
    final state = AppScope.of(context);
    setState(() => busy = true);
    try {
      if (state.user?.appleLinked == true) {
        await state.api.unlinkApple();
        message = 'Apple hesabı bağlantısı kaldırıldı.';
      } else {
        final raw = nonce();
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: const [AppleIDAuthorizationScopes.email],
          nonce: sha256.convert(utf8.encode(raw)).toString(),
          webAuthenticationOptions: Platform.isAndroid && AppConfig.appleServiceId.isNotEmpty && AppConfig.appleRedirectUri.isNotEmpty ? WebAuthenticationOptions(clientId: AppConfig.appleServiceId, redirectUri: Uri.parse(AppConfig.appleRedirectUri)) : null,
        );
        final identityToken = credential.identityToken;
        if (identityToken == null) throw Exception('Apple kimlik belirteci alınamadı.');
        await state.api.linkApple(identityToken: identityToken, nonce: raw, authorizationCode: credential.authorizationCode);
        message = 'Apple hesabı güvenli şekilde bağlandı.';
      }
      await state.reloadUser();
      if (mounted) setState(() {});
    } catch (e) { if (mounted) setState(() => message = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> deleteAccount() async {
    final appState = AppScope.of(context);
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final approved = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Hesabı Kalıcı Sil'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Kişisel oturum, sohbet ve cihaz kayıtları silinir. Yasal mali kayıtlar kullanıcı kimliğinden ayrılarak korunur.'), const SizedBox(height: 14),
        TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Mevcut şifre')), const SizedBox(height: 10),
        TextField(controller: confirmation, decoration: const InputDecoration(labelText: 'HESABIMI SİL yazın')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kalıcı Sil'))],
    ));
    if (approved != true) return;
    setState(() => busy = true);
    try {
      await appState.api.deleteAccount(currentPassword: password.text, confirmation: confirmation.text);
      if (mounted) await appState.logout();
    } catch (e) { if (mounted) setState(() => message = e.toString()); }
    finally { password.dispose(); confirmation.dispose(); if (mounted) setState(() => busy = false); }
  }

  @override Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Hesap ve Gizlilik')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (message != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(message!)),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.person_outline), title: Text(state.user?.name ?? ''), subtitle: Text(state.user?.email ?? '')),
          ListTile(leading: const Icon(Icons.apple), title: Text(state.user?.appleLinked == true ? 'Apple hesabını ayır' : 'Apple hesabını bağla'), subtitle: const Text('Sonraki girişlerde Apple ile güvenli oturum açın.'), onTap: busy ? null : toggleApple),
          ListTile(leading: const Icon(Icons.download_for_offline_outlined), title: const Text('Kişisel verilerimi dışa aktar'), subtitle: const Text('Hesap, sohbet ve size bağlı kayıtları JSON olarak indirin.'), onTap: busy ? null : exportData),
        ])),
        const SizedBox(height: 12),
        Card(color: Theme.of(context).colorScheme.errorContainer, child: ListTile(leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error), title: const Text('Hesabımı kalıcı sil'), subtitle: const Text('Bu işlem geri alınamaz.'), onTap: busy ? null : deleteAccount)),
        if (busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
      ]),
    );
  }
}
