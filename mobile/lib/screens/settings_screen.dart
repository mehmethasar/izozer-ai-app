import 'package:flutter/material.dart';
import 'package:mazdek_ai/app/app_scope.dart';
import 'package:mazdek_ai/core/config/app_config.dart';
import 'package:mazdek_ai/screens/account_privacy_screen.dart';
import 'package:mazdek_ai/screens/admin_screen.dart';
import 'package:mazdek_ai/screens/integration_settings_screen.dart';
import 'package:mazdek_ai/screens/password_change_screen.dart';
import 'package:mazdek_ai/widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final server = TextEditingController();
  Map<String, dynamic>? health;
  Map<String, dynamic>? integrations;
  bool busy = false;
  String? message;
  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => load()); }
  @override void dispose() { server.dispose(); super.dispose(); }

  Future<void> load() async {
    final state = AppScope.of(context);
    server.text = await state.settings.apiBaseUrl();
    setState(() => busy = true);
    try {
      final h = await state.api.health();
      Map<String, dynamic>? i;
      if (['owner', 'admin'].contains(state.user?.role)) i = await state.api.integrationStatus();
      if (mounted) setState(() { health = h; integrations = i; });
    } catch (e) { if (mounted) setState(() => message = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> saveServer() async {
    setState(() { busy = true; message = null; });
    try {
      final state = AppScope.of(context);
      await state.settings.setApiBaseUrl(server.text);
      health = await state.api.health();
      if (mounted) setState(() => message = 'Sunucu bağlantısı başarılı.');
    } catch (e) { if (mounted) setState(() => message = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> sync() async {
    setState(() { busy = true; message = null; });
    try {
      final result = await AppScope.of(context).api.syncKolayBi();
      if (mounted) setState(() => message = 'Senkronizasyon tamamlandı: ${result['associates'] ?? 0} cari, ${result['invoices'] ?? 0} fatura.');
    } catch (e) { if (mounted) setState(() => message = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> changeNotifications(bool enabled) async {
    final state = AppScope.of(context);
    setState(() => busy = true);
    try {
      if (enabled) {
        final granted = await state.notifications.requestPermissions();
        if (granted) {
          await state.notifications.initializeRemote();
          await state.notifications.scheduleDailySummary();
          await state.notifications.synchronizeOperationalNotifications();
          message = state.notifications.firebaseReady ? 'Yerel ve uzaktan bildirimler etkin.' : 'Yerel bildirimler etkin. Firebase dosyaları bağlandığında uzaktan bildirim de açılacak.';
        } else {
          message = 'Bildirim izni verilmedi.';
        }
      } else {
        await state.notifications.disable();
        message = 'Bildirimler kapatıldı ve cihaz kaydı temizlendi.';
      }
      if (mounted) setState(() {});
    } catch (e) { if (mounted) setState(() => message = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final openai = integrations?['openai'] as Map<String, dynamic>?;
    final kolaybi = integrations?['kolaybi'] as Map<String, dynamic>?;
    final apns = integrations?['apns'] as Map<String, dynamic>?;
    final fcm = integrations?['fcm'] as Map<String, dynamic>?;
    final isAdmin = ['owner', 'admin'].contains(state.user?.role);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
      if (state.notificationWarning != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: StatusBanner(text: state.notificationWarning!, icon: Icons.notifications_off_outlined, warning: true)),
      if (message != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: StatusBanner(text: message!, warning: message!.toLowerCase().contains('hata'))),
      if (AppConfig.allowsCustomApiUrl) ...[
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Geliştirme sunucusu', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 12),
          TextField(controller: server, decoration: const InputDecoration(labelText: 'API adresi')), const SizedBox(height: 10),
          FilledButton.tonalIcon(onPressed: busy ? null : saveServer, icon: const Icon(Icons.network_check), label: const Text('Kaydet ve Bağlantıyı Test Et')),
          if (health != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('${health!['service'] ?? 'Mazdek API'} • ${health!['status'] ?? ''} • v${health!['version'] ?? ''}')),
        ]))),
        const SizedBox(height: 12),
      ],
      Card(child: Column(children: [
        ListTile(title: const Text('Görünüm'), subtitle: Text(state.themeMode == 'system' ? 'Sistem ayarı' : state.themeMode == 'dark' ? 'Koyu' : 'Açık'), leading: const Icon(Icons.contrast), trailing: DropdownButton<String>(value: state.themeMode, underline: const SizedBox.shrink(), items: const [DropdownMenuItem(value: 'system', child: Text('Sistem')), DropdownMenuItem(value: 'light', child: Text('Açık')), DropdownMenuItem(value: 'dark', child: Text('Koyu'))], onChanged: (v) { if (v != null) state.setTheme(v); })),
        FutureBuilder<bool>(future: state.tokens.biometricEnabled, builder: (context, snap) => SwitchListTile(value: snap.data ?? false, onChanged: busy ? null : (v) async { final messenger = ScaffoldMessenger.of(context); try { await state.setBiometric(v); if (mounted) setState(() {}); } catch (e) { if (mounted) messenger.showSnackBar(SnackBar(content: Text(e.toString()))); } }, secondary: const Icon(Icons.fingerprint), title: const Text('Biyometrik uygulama kilidi'), subtitle: const Text('Face ID, Touch ID veya Android biyometri'))),
        FutureBuilder<bool>(future: state.settings.notificationsEnabled(), builder: (context, snap) => SwitchListTile(value: snap.data ?? false, onChanged: busy ? null : changeNotifications, secondary: const Icon(Icons.notifications_active_outlined), title: const Text('Bildirimler'), subtitle: Text(state.notifications.firebaseReady ? 'FCM/APNs cihaz kaydı aktif' : 'Kilit ekranında ayrıntı göstermeyen günlük rapor ve vade hatırlatmaları'))),
        ListTile(leading: const Icon(Icons.password), title: const Text('Şifre Değiştir'), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PasswordChangeScreen()))),
        ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('Hesap ve Gizlilik'), subtitle: const Text('Apple bağlantısı, veri dışa aktarma ve hesap silme'), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AccountPrivacyScreen()))),
      ])),
      if (integrations != null) ...[
        const SizedBox(height: 12),
        Row(children: [Expanded(child: Text('Entegrasyonlar', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), TextButton.icon(onPressed: () async { await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const IntegrationSettingsScreen())); await load(); }, icon: const Icon(Icons.tune), label: const Text('Kurulum'))]),
        _IntegrationTile(icon: Icons.auto_awesome, name: 'OpenAI', active: openai?['configured'] == true, detail: openai?['model']?.toString() ?? 'Yerel motor aktif'),
        _IntegrationTile(icon: Icons.sync, name: 'KolayBi', active: kolaybi?['configured'] == true, detail: kolaybi?['environment']?.toString() ?? 'Bağlı değil', action: kolaybi?['configured'] == true ? TextButton(onPressed: busy ? null : sync, child: const Text('Eşitle')) : null),
        _IntegrationTile(icon: Icons.apple, name: 'iOS APNs', active: apns?['configured'] == true, detail: apns?['environment']?.toString() ?? 'Yapılandırılmadı'),
        _IntegrationTile(icon: Icons.android, name: 'Android FCM', active: fcm?['configured'] == true, detail: fcm?['projectId']?.toString() ?? 'Yapılandırılmadı'),
      ],
      if (isAdmin) ...[
        const SizedBox(height: 12),
        Card(child: ListTile(leading: const Icon(Icons.admin_panel_settings_outlined), title: const Text('Yönetim ve Denetim'), subtitle: const Text('Kullanıcılar, sistem hazırlığı, denetim ve yedekler'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AdminScreen())))),
      ],
      const SizedBox(height: 12),
      Card(child: Column(children: [ListTile(leading: const Icon(Icons.person_outline), title: Text(state.user?.name ?? ''), subtitle: Text('${state.user?.email ?? ''} • ${state.user?.role ?? ''}')), ListTile(leading: const Icon(Icons.logout), title: const Text('Oturumu Kapat'), onTap: state.logout)])),
      if (busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
    ]);
  }
}

class _IntegrationTile extends StatelessWidget {
  const _IntegrationTile({required this.icon, required this.name, required this.active, required this.detail, this.action});
  final IconData icon;
  final String name, detail;
  final bool active;
  final Widget? action;
  @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: CircleAvatar(child: Icon(icon)), title: Text(name), subtitle: Text(detail), trailing: action ?? Icon(active ? Icons.check_circle : Icons.remove_circle_outline, color: active ? Colors.green : Theme.of(context).colorScheme.outline)));
}
