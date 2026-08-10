import 'package:flutter/material.dart';
import 'package:mazdek_ai/app/app_scope.dart';
import 'package:mazdek_ai/core/theme/app_theme.dart';
import 'package:mazdek_ai/screens/admin_screen.dart';
import 'package:mazdek_ai/screens/chat_screen.dart';
import 'package:mazdek_ai/screens/dashboard_screen.dart';
import 'package:mazdek_ai/screens/entity_list_screen.dart';
import 'package:mazdek_ai/screens/settings_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  @override State<ShellScreen> createState() => _ShellScreenState();
}

class _MenuItem {
  const _MenuItem(this.keyName, this.title, this.icon, [this.endpoint]);
  final String keyName, title;
  final IconData icon;
  final String? endpoint;
}

const _baseMenu = <_MenuItem>[
  _MenuItem('dashboard', 'Genel Bakış', Icons.dashboard_outlined),
  _MenuItem('chat', 'Yapay Zekâ', Icons.auto_awesome),
  _MenuItem('transactions', 'Gelir ve Giderler', Icons.receipt_long_outlined, '/api/transactions'),
  _MenuItem('projects', 'Projeler', Icons.business_center_outlined, '/api/projects'),
  _MenuItem('associates', 'Cariler', Icons.handshake_outlined, '/api/associates'),
  _MenuItem('invoices', 'Fatura Takibi', Icons.description_outlined, '/api/invoices'),
  _MenuItem('personnel', 'Personeller', Icons.groups_outlined, '/api/personnel'),
  _MenuItem('expenses', 'Personel Giderleri', Icons.payments_outlined, '/api/personnel-expenses?limit=1000'),
  _MenuItem('vaults', 'Kasa ve Bankalar', Icons.account_balance_wallet_outlined, '/api/vaults'),
  _MenuItem('transfers', 'İç Transferler', Icons.swap_horiz, '/api/vault-transfers?limit=100'),
  _MenuItem('tasks', 'Görevler', Icons.task_alt_outlined, '/api/tasks'),
  _MenuItem('reminders', 'Hatırlatmalar', Icons.notifications_active_outlined, '/api/reminders'),
  _MenuItem('documents', 'Belge Arşivi', Icons.folder_copy_outlined, '/api/documents'),
  _MenuItem('reports', 'Raporlar', Icons.analytics_outlined, '/api/reports/daily'),
  _MenuItem('settings', 'Ayarlar', Icons.settings_outlined),
];

class _ShellScreenState extends State<ShellScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String selected = 'dashboard';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final target = AppScope.of(context).consumeNavigationTarget();
    if (target != null) selected = target;
  }

  List<_MenuItem> menu(BuildContext context) {
    final role = AppScope.of(context).user?.role;
    return [..._baseMenu, if (role == 'owner' || role == 'admin') const _MenuItem('admin', 'Yönetim ve Denetim', Icons.admin_panel_settings_outlined)];
  }

  Widget screen(List<_MenuItem> items) {
    final item = items.firstWhere((e) => e.keyName == selected, orElse: () => items.first);
    return switch (item.keyName) {
      'dashboard' => const DashboardScreen(),
      'chat' => const ChatScreen(),
      'settings' => const SettingsScreen(),
      'admin' => const AdminScreen(),
      _ => EntityListScreen(title: item.title, endpoint: item.endpoint!, icon: item.icon, onAskAi: (prompt) { AppScope.of(context).prepareChat(prompt); setState(() => selected = 'chat'); }),
    };
  }

  @override Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = menu(context);
    if (!items.any((e) => e.keyName == selected)) selected = 'dashboard';
    final current = items.firstWhere((e) => e.keyName == selected);
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: Text(current.title), actions: [if (selected != 'chat') IconButton(tooltip: 'Yapay Zekâya Sor', onPressed: () => setState(() => selected = 'chat'), icon: const Icon(Icons.auto_awesome)), const SizedBox(width: 4)]),
      drawer: NavigationDrawer(
        selectedIndex: items.indexWhere((e) => e.keyName == selected),
        onDestinationSelected: (index) { setState(() => selected = items[index].keyName); Navigator.pop(context); },
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 14), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: AppTheme.orange, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.auto_awesome, color: Colors.white)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Mazdek', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), Text(state.user?.name ?? '', overflow: TextOverflow.ellipsis)]))])),
          const Divider(),
          for (final item in items) NavigationDrawerDestination(icon: Icon(item.icon), label: Text(item.title)),
          const Divider(), ListTile(leading: const Icon(Icons.logout), title: const Text('Oturumu Kapat'), onTap: state.logout), const SizedBox(height: 16),
        ],
      ),
      body: Column(
        children: [
          if (state.offline)
            MaterialBanner(
              content: const Text('Çevrimdışı görünüm: son güvenli veriler gösteriliyor; yeni işlem ve onaylar bağlantı gelene kadar uygulanamaz.'),
              leading: const Icon(Icons.cloud_off_outlined),
              actions: [
                TextButton(
                  onPressed: () async {
                    try {
                      await state.reloadUser();
                      if (mounted) setState(() {});
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sunucu bağlantısı henüz kurulamadı.')));
                      }
                    }
                  },
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          Expanded(child: screen(items)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected == 'dashboard' ? 0 : selected == 'chat' ? 1 : 2,
        onDestinationSelected: (index) { if (index == 0) setState(() => selected = 'dashboard'); if (index == 1) setState(() => selected = 'chat'); if (index == 2) _scaffoldKey.currentState?.openDrawer(); },
        destinations: const [NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Genel Bakış'), NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Yapay Zekâ'), NavigationDestination(icon: Icon(Icons.menu), label: 'İşlemler')],
      ),
    );
  }
}
