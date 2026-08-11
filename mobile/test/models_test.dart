import 'package:flutter_test/flutter_test.dart';
import 'package:mazdek_ai/models/models.dart';

void main() {
  test('dashboard personel dahil gideri okur', () {
    final dashboard = DashboardSummary.fromJson({
      'todayIncome': 1000,
      'todayExpense': 200,
      'totalTodayExpense': 350,
      'monthIncome': 5000,
      'monthExpense': 1000,
      'totalMonthExpense': 1600,
      'cashBalance': 3400,
      'receivables': 700,
      'payables': 200,
      'overdueReceivables': 100,
      'upcomingPayments': 50,
      'activeProjectCount': 2,
      'bestProjectName': 'Shell',
      'riskProjectName': 'Ambar',
      'recentTransactions': <Map<String,dynamic>>[],
    });
    expect(dashboard.totalTodayExpense, 350);
    expect(dashboard.totalMonthExpense, 1600);
  });

  test('bekleyen işlem tutarı ve adı okunur', () {
    final action = PendingAction.fromJson({'id':'a1','kind':'add_transaction','status':'pending','title':'Gider','summary':'Vinç','amount':12500,'projectName':'Shell'});
    expect(action.amount, 12500);
    expect(action.primaryName, 'Shell');
  });
}
