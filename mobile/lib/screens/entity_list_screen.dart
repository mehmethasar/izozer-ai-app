import 'package:flutter/material.dart';
import 'package:mazdek_ai/app/app_scope.dart';
import 'package:mazdek_ai/models/models.dart';
import 'package:mazdek_ai/screens/record_detail_screen.dart';
import 'package:mazdek_ai/widgets/common.dart';

class EntityListScreen extends StatefulWidget {
  const EntityListScreen({required this.title, required this.endpoint, required this.icon, required this.onAskAi, super.key});
  final String title;
  final String endpoint;
  final IconData icon;
  final ValueChanged<String> onAskAi;

  @override State<EntityListScreen> createState() => _EntityListScreenState();
}

class _EntityListScreenState extends State<EntityListScreen> {
  List<EntityRecord> records = const [];
  bool loading = true;
  bool offline = false;
  String query = '';
  String? error;

  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => load()); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await AppScope.of(context).api.records(widget.endpoint);
      if (!mounted) return;
      setState(() { records = result.data; offline = result.fromCache; });
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => loading = false); }
  }

  @override Widget build(BuildContext context) {
    if (loading && records.isEmpty) return const LoadingPane();
    if (error != null && records.isEmpty) return ErrorPane(message: error!, onRetry: load);
    final filtered = records.where((item) => '${item.title} ${item.subtitle}'.toLowerCase().contains(query.toLowerCase())).toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
        if (offline) const Padding(padding: EdgeInsets.only(bottom: 10), child: StatusBanner(text: 'Çevrimdışı önbellek gösteriliyor.', icon: Icons.cloud_off, warning: true)),
        TextField(onChanged: (value) => setState(() => query = value), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: '${widget.title} içinde ara')),
        const SizedBox(height: 12),
        if (filtered.isEmpty) EmptyState(title: 'Kayıt bulunamadı', message: 'Yeni kayıtları yapay zekâ sohbetinden oluşturabilirsiniz.', icon: widget.icon)
        else ...filtered.map((item) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(child: Icon(widget.icon)),
            title: Text(item.title),
            subtitle: item.subtitle.isEmpty ? null : Text(item.subtitle),
            trailing: item.amount == null ? const Icon(Icons.chevron_right) : Text(money(item.amount!), style: const TextStyle(fontWeight: FontWeight.w800)),
            onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => RecordDetailScreen(record: item, endpoint: widget.endpoint, icon: widget.icon, onAskAi: widget.onAskAi))),
          ),
        )),
      ]),
    );
  }
}
