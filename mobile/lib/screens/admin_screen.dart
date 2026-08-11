import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mazdek_ai/app/app_scope.dart';
import 'package:mazdek_ai/models/models.dart';
import 'package:mazdek_ai/widgets/common.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  bool busy = true;
  List<EntityRecord> users = const [];
  List<EntityRecord> audit = const [];
  List<EntityRecord> backups = const [];
  Map<String, dynamic>? readiness;
  String? error;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = AppScope.of(context).api;
      final results = await Future.wait<dynamic>([
        api.users(),
        api.auditLogs(),
        api.backups(),
        api.readiness(),
      ]);
      if (!mounted) return;
      setState(() {
        users = results[0] as List<EntityRecord>;
        audit = results[1] as List<EntityRecord>;
        backups = results[2] as List<EntityRecord>;
        readiness = results[3] as Map<String, dynamic>;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> action(bool backup) async {
    setState(() => busy = true);
    try {
      final api = AppScope.of(context).api;
      final result = backup
          ? await api.createBackup()
          : await api.runMaintenance();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              backup
                  ? 'Yedek oluşturuldu.'
                  : 'Bakım tamamlandı: ${jsonEncode(result)}',
            ),
          ),
        );
      }
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget recordList(List<EntityRecord> records, IconData icon) {
    return RefreshIndicator(
      onRefresh: load,
      child: records.isEmpty
          ? ListView(
              children: [
                EmptyState(
                  title: 'Kayıt yok',
                  message: 'Bu bölümde henüz kayıt bulunmuyor.',
                  icon: icon,
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: records.length,
              itemBuilder: (_, index) {
                final item = records[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(icon)),
                    title: Text(item.title),
                    subtitle: Text(item.subtitle),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(item.title),
                        content: SingleChildScrollView(
                          child: SelectableText(
                            const JsonEncoder.withIndent('  ').convert(item.raw),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Kapat'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yönetim ve Denetim'),
        bottom: TabBar(
          controller: tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Hazırlık'),
            Tab(text: 'Kullanıcılar'),
            Tab(text: 'Denetim'),
            Tab(text: 'Yedekler'),
          ],
        ),
      ),
      body: busy && readiness == null
          ? const LoadingPane()
          : Column(
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: StatusBanner(text: error!, warning: true),
                  ),
                if (busy) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: TabBarView(
                    controller: tabs,
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: SelectableText(
                                const JsonEncoder.withIndent(' ')
                                    .convert(readiness ?? {}),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: busy ? null : () => action(false),
                            icon: const Icon(Icons.cleaning_services),
                            label: const Text('Bakım İşlemini Çalıştır'),
                          ),
                        ],
                      ),
                      recordList(users, Icons.manage_accounts_outlined),
                      recordList(audit, Icons.policy_outlined),
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: FilledButton.icon(
                              onPressed: busy ? null : () => action(true),
                              icon: const Icon(Icons.backup),
                              label: const Text('Şimdi Yedek Oluştur'),
                            ),
                          ),
                          Expanded(
                            child: recordList(
                              backups,
                              Icons.inventory_2_outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
