import 'dart:convert';

String _s(Map<String, dynamic> j, String key, [String fallback = '']) => j[key]?.toString() ?? fallback;
double _d(Map<String, dynamic> j, String key) => (j[key] as num?)?.toDouble() ?? double.tryParse('${j[key]}') ?? 0;
int _i(Map<String, dynamic> j, String key) => (j[key] as num?)?.toInt() ?? int.tryParse('${j[key]}') ?? 0;
bool _b(Map<String, dynamic> j, String key) => j[key] == true;

final class AppUser {
  const AppUser({required this.id, required this.companyId, required this.name, required this.email, required this.role, this.active = true, this.mustChangePassword = false, this.appleLinked = false});
  final String id, companyId, name, email, role;
  final bool active, mustChangePassword, appleLinked;
  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(id: _s(j, 'id'), companyId: _s(j, 'companyId'), name: _s(j, 'name'), email: _s(j, 'email'), role: _s(j, 'role'), active: j['active'] != false, mustChangePassword: _b(j, 'mustChangePassword'), appleLinked: _b(j, 'appleLinked'));
  Map<String, dynamic> toJson() => {'id': id, 'companyId': companyId, 'name': name, 'email': email, 'role': role, 'active': active, 'mustChangePassword': mustChangePassword, 'appleLinked': appleLinked};
}

final class AuthResponse {
  const AuthResponse({required this.accessToken, required this.refreshToken, required this.expiresIn, required this.user});
  final String accessToken, refreshToken;
  final int expiresIn;
  final AppUser user;
  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(accessToken: _s(j, 'accessToken'), refreshToken: _s(j, 'refreshToken'), expiresIn: _i(j, 'expiresIn'), user: AppUser.fromJson(j['user'] as Map<String, dynamic>));
  String userJson() => jsonEncode(user.toJson());
}

final class FinanceTransaction {
  const FinanceTransaction({required this.id, required this.type, required this.amount, required this.currency, required this.description, required this.category, required this.date, this.projectName, this.associateName, this.personnelId, this.vaultName, this.fromVaultName, this.toVaultName});
  final String id, type, currency, description, category, date;
  final double amount;
  final String? projectName, associateName, personnelId, vaultName, fromVaultName, toVaultName;
  bool get isIncome => type == 'income';
  factory FinanceTransaction.fromJson(Map<String, dynamic> j) => FinanceTransaction(id: _s(j, 'id'), type: _s(j, 'type'), amount: _d(j, 'amount'), currency: _s(j, 'currency', 'TRY'), description: _s(j, 'description'), category: _s(j, 'category'), date: _s(j, 'date'), projectName: j['projectName']?.toString(), associateName: j['associateName']?.toString(), personnelId: j['personnelId']?.toString(), vaultName: j['vaultName']?.toString(), fromVaultName: j['fromVaultName']?.toString(), toVaultName: j['toVaultName']?.toString());
}

final class DashboardSummary {
  const DashboardSummary({required this.todayIncome, required this.totalTodayExpense, required this.monthIncome, required this.totalMonthExpense, required this.cashBalance, required this.receivables, required this.payables, required this.overdueReceivables, required this.upcomingPayments, required this.activeProjectCount, required this.bestProjectName, required this.riskProjectName, required this.recentTransactions, this.openInvoiceCount = 0, this.openTaskCount = 0, this.overdueTaskCount = 0});
  final double todayIncome, totalTodayExpense, monthIncome, totalMonthExpense, cashBalance, receivables, payables, overdueReceivables, upcomingPayments;
  final int activeProjectCount, openInvoiceCount, openTaskCount, overdueTaskCount;
  final String bestProjectName, riskProjectName;
  final List<FinanceTransaction> recentTransactions;
  factory DashboardSummary.fromJson(Map<String, dynamic> j) => DashboardSummary(todayIncome: _d(j, 'todayIncome'), totalTodayExpense: j['totalTodayExpense'] == null ? _d(j, 'todayExpense') : _d(j, 'totalTodayExpense'), monthIncome: _d(j, 'monthIncome'), totalMonthExpense: j['totalMonthExpense'] == null ? _d(j, 'monthExpense') : _d(j, 'totalMonthExpense'), cashBalance: _d(j, 'cashBalance'), receivables: _d(j, 'receivables'), payables: _d(j, 'payables'), overdueReceivables: _d(j, 'overdueReceivables'), upcomingPayments: _d(j, 'upcomingPayments'), activeProjectCount: _i(j, 'activeProjectCount'), bestProjectName: _s(j, 'bestProjectName', '—'), riskProjectName: _s(j, 'riskProjectName', '—'), openInvoiceCount: _i(j, 'openInvoiceCount'), openTaskCount: _i(j, 'openTaskCount'), overdueTaskCount: _i(j, 'overdueTaskCount'), recentTransactions: ((j['recentTransactions'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(FinanceTransaction.fromJson).toList());
}

final class PendingAction {
  const PendingAction({required this.id, required this.kind, required this.status, required this.title, required this.summary, this.amount, this.primaryName});
  final String id, kind, status, title, summary;
  final double? amount;
  final String? primaryName;
  factory PendingAction.fromJson(Map<String, dynamic> j) {
    String? first(List<String> keys) { for (final key in keys) { if (j[key] != null && '${j[key]}'.isNotEmpty) return '${j[key]}'; } return null; }
    return PendingAction(id: _s(j, 'id'), kind: _s(j, 'kind'), status: _s(j, 'status'), title: _s(j, 'title', 'Onay Bekleyen İşlem'), summary: _s(j, 'summary'), amount: j['amount'] == null && j['totalAmount'] == null ? null : (j['amount'] as num?)?.toDouble() ?? (j['totalAmount'] as num?)?.toDouble(), primaryName: first(['projectName','associateName','personnelName','taskTitle','taskName','reminderTitle','documentTitle','vaultName','name','invoiceNumber','number']));
  }
}

final class ChatArtifact {
  const ChatArtifact({required this.id, required this.name, required this.format, required this.path});
  final String id, name, format, path;
  factory ChatArtifact.fromJson(Map<String, dynamic> j) => ChatArtifact(id: _s(j, 'id'), name: _s(j, 'name'), format: _s(j, 'format'), path: _s(j, 'path'));
}

final class ChatResponse {
  const ChatResponse({required this.reply, this.action, this.mode, this.artifacts = const []});
  final String reply;
  final PendingAction? action;
  final String? mode;
  final List<ChatArtifact> artifacts;
  factory ChatResponse.fromJson(Map<String, dynamic> j) => ChatResponse(reply: _s(j, 'reply'), action: j['action'] is Map<String,dynamic> ? PendingAction.fromJson(j['action'] as Map<String,dynamic>) : null, mode: j['mode']?.toString(), artifacts: ((j['artifacts'] as List?) ?? const []).whereType<Map<String,dynamic>>().map(ChatArtifact.fromJson).toList());
}

final class ConversationItem {
  const ConversationItem({required this.id, required this.message, required this.reply, required this.createdAt, this.actionId, this.artifacts = const []});
  final String id, message, reply, createdAt;
  final String? actionId;
  final List<ChatArtifact> artifacts;
  factory ConversationItem.fromJson(Map<String, dynamic> j) => ConversationItem(id: _s(j, 'id'), message: _s(j, 'message'), reply: _s(j, 'reply'), createdAt: _s(j, 'createdAt'), actionId: j['actionId']?.toString(), artifacts: ((j['artifacts'] as List?) ?? const []).whereType<Map<String,dynamic>>().map(ChatArtifact.fromJson).toList());
}

final class EntityRecord {
  const EntityRecord({required this.id, required this.title, required this.subtitle, required this.amount, required this.raw});
  final String id, title, subtitle;
  final double? amount;
  final Map<String, dynamic> raw;

  static EntityRecord fromJson(Map<String, dynamic> j, String endpoint) {
    String first(List<String> keys, [String fallback = 'Kayıt']) { for (final k in keys) { final v = j[k]; if (v != null && '$v'.trim().isNotEmpty) return '$v'; } return fallback; }
    double? amount; for (final k in ['balance','profit','totalAmount','remainingAmount','amount','monthlySalary','monthExpense','contractAmount']) { if (j[k] is num) { amount = (j[k] as num).toDouble(); break; } }
    final title = first(['name','title','number','email','action','fileName','description','associateName','personnelName','fromVaultName']);
    final subtitleParts = <String>[];
    for (final k in ['status','role','userName','entityType','customerName','projectName','associateName','title','type','group','reason','createdAt','dueDate','date','assignedPersonnelName','toVaultName']) {
      final v = j[k]; if (v != null && '$v'.trim().isNotEmpty && '$v' != title && !subtitleParts.contains('$v')) subtitleParts.add('$v');
    }
    return EntityRecord(id: first(['id','externalId'], '${endpoint}_${title.hashCode}'), title: title, subtitle: subtitleParts.take(3).join(' • '), amount: amount, raw: j);
  }
}
