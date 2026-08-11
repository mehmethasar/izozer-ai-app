import 'package:flutter/material.dart';
import 'package:mazdek_ai/app/app_scope.dart';
import 'package:mazdek_ai/models/models.dart';
import 'package:mazdek_ai/widgets/common.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardSummary? summary;
  bool loading = true;
  bool offline = false;
  String? error;

  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => load()); }
  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { final result = await AppScope.of(context).api.dashboard(); if (mounted) setState(() { summary = result.data; offline = result.fromCache; }); }
    catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => loading = false); }
  }

  @override Widget build(BuildContext context) {
    if (loading && summary == null) return const LoadingPane();
    if (error != null && summary == null) return ErrorPane(message: error!, onRetry: load);
    final s = summary!;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
        if (offline) const Padding(padding: EdgeInsets.only(bottom: 12), child: StatusBanner(text: 'Bağlantı yok. Son güvenli veriler salt okunur gösteriliyor.', icon: Icons.cloud_off_outlined, warning: true)),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 560 ? 2 : 1;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          final cards = [
            _Metric('Bugünkü Gelir', money(s.todayIncome), Icons.trending_up, Colors.green),
            _Metric('Bugünkü Gider', money(s.totalTodayExpense), Icons.trending_down, Colors.red),
            _Metric('Kasa ve Banka', money(s.cashBalance), Icons.account_balance_wallet_outlined, Colors.blue),
            _Metric('Toplam Alacak', money(s.receivables), Icons.call_received, Colors.teal),
            _Metric('Toplam Borç', money(s.payables), Icons.call_made, Colors.deepOrange),
            _Metric('Vadesi Geçen', money(s.overdueReceivables), Icons.warning_amber, Colors.amber.shade800),
            _Metric('Aktif Projeler', '${s.activeProjectCount}', Icons.business_center_outlined, Colors.purple),
            _Metric('Açık Görevler', '${s.openTaskCount}', Icons.task_alt, Colors.indigo),
          ];
          return Wrap(spacing: 12, runSpacing: 12, children: cards.map((e) => SizedBox(width: width, child: e)).toList());
        }),
        const SizedBox(height: 18),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Aylık Durum', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 14), _Line('Gelir', money(s.monthIncome), Colors.green), const SizedBox(height: 10), _Line('Gider', money(s.totalMonthExpense), Colors.red), const Divider(height: 26), _Line('Net', money(s.monthIncome - s.totalMonthExpense), s.monthIncome >= s.totalMonthExpense ? Colors.green : Colors.red)]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Proje Değerlendirmesi', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 12), ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.star_outline)), title: const Text('En iyi proje'), subtitle: Text(s.bestProjectName)), ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.warning_amber)), title: const Text('Dikkat gereken proje'), subtitle: Text(s.riskProjectName))]))),
        const SizedBox(height: 18),
        Text('Son Hareketler', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 10),
        if (s.recentTransactions.isEmpty) const EmptyState(title: 'Henüz hareket yok', message: 'Yapay zekâ sohbetinden gelir veya gider ekleyebilirsiniz.')
        else ...s.recentTransactions.take(8).map((tx) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: CircleAvatar(child: Icon(tx.isIncome ? Icons.arrow_downward : Icons.arrow_upward)), title: Text(tx.description.isEmpty ? tx.category : tx.description), subtitle: Text([tx.projectName, tx.associateName, tx.date].whereType<String>().where((e) => e.isNotEmpty).join(' • ')), trailing: Text('${tx.isIncome ? '+' : '-'}${money(tx.amount)}', style: TextStyle(fontWeight: FontWeight.w800, color: tx.isIncome ? Colors.green : Colors.red))))),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.title, this.value, this.icon, this.color);
  final String title, value;
  final IconData icon;
  final Color color;
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: Theme.of(context).colorScheme.outline)), const SizedBox(height: 4), Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))]))])));
}
class _Line extends StatelessWidget { const _Line(this.label, this.value, this.color); final String label, value; final Color color; @override Widget build(BuildContext context) => Row(children: [Expanded(child: Text(label)), Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color))]); }
