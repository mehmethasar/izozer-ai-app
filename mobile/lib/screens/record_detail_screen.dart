import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mazdek_ai/app/app_scope.dart';
import 'package:mazdek_ai/models/models.dart';
import 'package:mazdek_ai/widgets/common.dart';

class RecordDetailScreen extends StatefulWidget {
  const RecordDetailScreen({required this.record, required this.endpoint, required this.icon, required this.onAskAi, super.key});
  final EntityRecord record;
  final String endpoint;
  final IconData icon;
  final ValueChanged<String> onAskAi;
  @override State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;

  String? detailEndpoint() {
    if (widget.endpoint.startsWith('/api/projects')) return '/api/projects/${widget.record.id}';
    if (widget.endpoint.startsWith('/api/associates')) return '/api/associates/${widget.record.id}/statement';
    if (widget.endpoint.startsWith('/api/personnel') && !widget.endpoint.startsWith('/api/personnel-expenses')) return '/api/personnel/${widget.record.id}';
    return null;
  }

  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => load()); }
  Future<void> load() async {
    final endpoint = detailEndpoint();
    if (endpoint == null) { if (mounted) setState(() { data = widget.record.raw; loading = false; }); return; }
    try { final result = await AppScope.of(context).api.detail(endpoint); if (mounted) setState(() => data = result); }
    catch (e) { if (mounted) setState(() { data = widget.record.raw; error = e.toString(); }); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Map<String, dynamic> get primary {
    final value = data ?? widget.record.raw;
    if (value['associate'] is Map<String, dynamic>) return {...value['associate'] as Map<String, dynamic>, 'totalIncome': value['totalIncome'], 'totalExpense': value['totalExpense']};
    return value;
  }

  static const labels = <String, String>{
    'name': 'Ad', 'title': 'Başlık / Görev', 'customerName': 'Müşteri', 'status': 'Durum', 'progress': 'İlerleme',
    'contractAmount': 'Sözleşme bedeli', 'budget': 'Bütçe', 'income': 'Toplam gelir', 'expense': 'Toplam gider',
    'personnelCost': 'Personel maliyeti', 'profit': 'Kâr / zarar', 'budgetUsage': 'Bütçe kullanımı', 'balance': 'Cari bakiye',
    'receivable': 'Alacak', 'payable': 'Borç', 'monthlySalary': 'Aylık ücret', 'monthExpense': 'Bu ay personel gideri',
    'totalExpense': 'Toplam gider', 'totalIncome': 'Toplam tahsilat', 'phone': 'Telefon', 'email': 'E-posta',
    'startDate': 'Başlangıç', 'endDate': 'Bitiş', 'dueDate': 'Vade', 'dueAt': 'Hatırlatma zamanı', 'address': 'Adres',
    'notes': 'Notlar', 'description': 'Açıklama', 'priority': 'Öncelik', 'type': 'Tür', 'number': 'Numara',
    'remainingAmount': 'Kalan tutar', 'totalAmount': 'Toplam tutar', 'date': 'Tarih', 'createdAt': 'Oluşturulma',
    'openTaskCount': 'Açık görev', 'overdueTaskCount': 'Geciken görev', 'projectNames': 'Projeler', 'active': 'Aktif',
  };
  static const hidden = {'id','externalId','createdBy','updatedBy','sourceFileName','originalFileName','source','officialDocumentCreated','archivedAt','notificationSentAt','lastDueNotificationDate','projectIds'};
  static const moneyKeys = {'contractAmount','budget','income','expense','personnelCost','profit','balance','receivable','payable','monthlySalary','monthExpense','totalExpense','totalIncome','remainingAmount','totalAmount','amount','taxAmount'};
  static const percentKeys = {'progress','budgetUsage'};

  String valueText(String key, dynamic value) {
    if (value == null) return '—';
    if (moneyKeys.contains(key) && value is num) return money(value.toDouble());
    if (percentKeys.contains(key) && value is num) return '%${(value.toDouble() * 100).toStringAsFixed(0)}';
    if (value is bool) return value ? 'Evet' : 'Hayır';
    if (value is List) return value.map((e) => '$e').join(', ');
    if ((key.endsWith('Date') || key.endsWith('At') || key == 'date') && value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return DateFormat('dd.MM.yyyy HH:mm').format(parsed.toLocal());
    }
    return '$value';
  }

  bool _isNestedCollection(dynamic value) => value is Map || (value is List && value.any((item) => item is Map));

  List<MapEntry<String, dynamic>> scalarEntries() => primary.entries
      .where((entry) => !hidden.contains(entry.key) && entry.value != null && !_isNestedCollection(entry.value))
      .toList();

  Widget overviewCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [CircleAvatar(radius: 25, child: Icon(widget.icon)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.record.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), if (widget.record.subtitle.isNotEmpty) Text(widget.record.subtitle)]))]),
          const Divider(height: 28),
          ...scalarEntries().map((entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: Text(labels[entry.key] ?? _humanize(entry.key), style: TextStyle(color: Theme.of(context).colorScheme.outline))), const SizedBox(width: 12), Expanded(flex: 3, child: Text(valueText(entry.key, entry.value), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700)))]),
          )),
        ],
      ),
    ),
  );

  Iterable<MapEntry<String, List<dynamic>>> listSections() sync* {
    for (final entry in (data ?? const <String, dynamic>{}).entries) {
      if (entry.value is List && (entry.value as List).isNotEmpty) yield MapEntry(entry.key, entry.value as List<dynamic>);
    }
  }

  Widget listCard(MapEntry<String, List<dynamic>> section) {
    final items = section.value.whereType<Map<String, dynamic>>().take(50).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_sectionTitle(section.key), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ...items.map((item) {
            final record = EntityRecord.fromJson(item, section.key);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 18, child: Icon(_sectionIcon(section.key), size: 19)),
              title: Text(record.title),
              subtitle: record.subtitle.isEmpty ? null : Text(record.subtitle),
              trailing: record.amount == null ? null : Text(money(record.amount!), style: const TextStyle(fontWeight: FontWeight.w800)),
            );
          }),
          if (section.value.length > 50) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('İlk 50 kayıt gösteriliyor. Toplam ${section.value.length} kayıt.')),
        ]),
      ),
    );
  }

  String _sectionTitle(String key) => const {'transactions':'Finansal Hareketler','personnelExpenses':'Personel Giderleri','invoices':'Fatura Takibi','tasks':'Görevler','documents':'Belgeler','expenses':'Personel Giderleri'}[key] ?? _humanize(key);
  IconData _sectionIcon(String key) => const {'transactions':Icons.receipt_long_outlined,'personnelExpenses':Icons.payments_outlined,'invoices':Icons.description_outlined,'tasks':Icons.task_alt_outlined,'documents':Icons.folder_outlined,'expenses':Icons.payments_outlined}[key] ?? Icons.list_alt;
  String _humanize(String value) => value.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}').trim();

  void askAi() {
    final prompt = '${widget.record.title} kaydını mevcut verilerle analiz et; finansal durumu, riskleri, yaklaşan işleri ve önerilen sonraki adımları açıkla.';
    Navigator.pop(context);
    widget.onAskAi(prompt);
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.record.title), actions: [IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh), tooltip: 'Yenile')]),
    body: loading ? const LoadingPane() : ListView(padding: const EdgeInsets.all(16), children: [
      if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusBanner(text: 'Ayrıntılar yenilenemedi; mevcut kayıt gösteriliyor. $error', warning: true)),
      overviewCard(),
      ...listSections().map((section) => Padding(padding: const EdgeInsets.only(top: 10), child: listCard(section))),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: askAi, icon: const Icon(Icons.auto_awesome), label: const Text('Bu Kayıtla İlgili Yapay Zekâya Sor')),
    ]),
  );
}
