import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

import '../core/app_colors.dart';
import '../data/database/expense_dao.dart';
import '../data/database/income_dao.dart';
import '../main.dart'; // 🔔 RouteObserver
import 'add_income_screen.dart';
import 'add_expense_screen.dart';
import 'empty_prediction_plan_screen.dart';
import 'history_screen.dart';
import 'prediction_plan_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';

import '../services/session_manager.dart';
import '../data/database/student_dao.dart';
import 'dart:io';

class DashboardScreen extends StatefulWidget {
  final String fullName;
  final String studentId;

  // (kept to avoid breaking other code, but not used for prediction now)
  final DateTime registrationDate;

  const DashboardScreen({
    super.key,
    required this.fullName,
    required this.studentId,
    required this.registrationDate,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

// ================= INTERNAL MODEL =================
class _DashboardHistoryItem {
  final String title;
  final String subtitle;
  final String amount;
  final String date;
  final bool isIncome;

  _DashboardHistoryItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.isIncome,
  });
}

class _DashboardScreenState extends State<DashboardScreen> with RouteAware {
  String? _profileImagePath;
  final ExpenseDAO _expenseDAO = ExpenseDAO();
  final IncomeDao _incomeDAO = IncomeDao();

  Map<String, double> _predictedAllocations = {
    'Essentials': 0.0,
    'Leisure': 0.0,
    'Academics': 0.0,
    'Others': 0.0,
  };

  Map<String, double> _categoryTotals = const {
    'Essentials': 0.0,
    'Leisure': 0.0,
    'Academics': 0.0,
    'Others': 0.0,
  };

  int _touchedIndex = -1;

  String _normalizeCategory(String raw) {
    final c = raw.toLowerCase().trim();
    if (c.startsWith('essential')) return 'Essentials';
    if (c.startsWith('leisure')) return 'Leisure';
    if (c.startsWith('academic')) return 'Academics';
    if (c.startsWith('other')) return 'Others';
    return 'Others';
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase().trim()) {
      case 'essentials':
        return Colors.red;
      case 'leisure':
        return Colors.orange;
      case 'academics':
        return Colors.blue;
      case 'others':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  double _currentMonthIncome = 0.0;
  double _currentMonthExpense = 0.0;
  bool _loadingTotals = true;

  final List<_DashboardHistoryItem> _history = [];
  bool _loadingHistory = true;

  void _goToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  Future<void> _loadPredictedAllocations() async {
    final allocations = await _incomeDAO.getPredictionAllocations(
      widget.studentId,
    );

    if (!mounted) return;

    setState(() {
      _predictedAllocations = allocations;
    });
  }

  Future<void> _loadCurrentMonthTotals() async {
    setState(() => _loadingTotals = true);

    final income = await _incomeDAO.getCurrentMonthTotalIncome(
      widget.studentId,
    );
    final expense = await _expenseDAO.getCurrentMonthTotalExpense(
      widget.studentId,
    );

    if (!mounted) return;

    setState(() {
      _currentMonthIncome = income;
      _currentMonthExpense = expense;
      _loadingTotals = false;
    });
  }

  Future<void> _loadCategoryTotals() async {
    final data = await _expenseDAO.getCurrentMonthCategoryTotals(
      widget.studentId,
    );
    if (!mounted) return;

    final Map<String, double> merged = {
      'Essentials': 0.0,
      'Leisure': 0.0,
      'Academics': 0.0,
      'Others': 0.0,
    };

    data.forEach((rawKey, value) {
      final key = _normalizeCategory(rawKey);
      final double v = (value).toDouble();
      merged[key] = (merged[key] ?? 0.0) + v;
    });

    setState(() {
      _categoryTotals = merged;
    });
  }

  Future<void> _loadProfileImage() async {
    final email = SessionManager.currentEmail;
    if (email == null || email.trim().isEmpty) return;

    final dao = StudentDAO();
    final data = await dao.getProfileByEmail(email);
    if (!mounted || data == null) return;

    final img = (data['Profile_image'] ?? '').toString().trim();

    setState(() {
      _profileImagePath = img.isNotEmpty ? img : null;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardHistory();
    _loadCurrentMonthTotals();
    _loadCategoryTotals();
    _loadPredictedAllocations(); // ✅ ADD THIS LINE
    _loadProfileImage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadDashboardHistory();
    _loadCurrentMonthTotals();
    _loadCategoryTotals();
    _loadPredictedAllocations(); // ✅ ADD THIS LINE
    _loadProfileImage();
  }

  Future<void> _loadDashboardHistory() async {
    _history.clear();
    setState(() => _loadingHistory = true);

    final expenses = await _expenseDAO.getAllExpensesByStudent(
      widget.studentId,
    );
    final incomes = await _incomeDAO.getIncomeByStudent(widget.studentId);

    for (final e in expenses) {
      _history.add(
        _DashboardHistoryItem(
          title: e['Category_type'],
          subtitle: 'Expense',
          amount: 'Rs. ${e['Expense_amount']}',
          date: e['Expense_date'],
          isIncome: false,
        ),
      );
    }

    for (final i in incomes) {
      _history.add(
        _DashboardHistoryItem(
          title: i.sourceType,
          subtitle: 'Income',
          amount: 'Rs. ${i.incomeAmount}',
          date: i.incomeDate,
          isIncome: true,
        ),
      );
    }

    _history.sort((a, b) => b.date.compareTo(a.date));
    setState(() => _loadingHistory = false);
  }

  // ✅ NEW: decide prediction availability using Created_at from DB
  Future<bool> _isPredictionAvailableFromDb() async {
    final dao = StudentDAO();
    final reg = await dao.getRegistrationDate(widget.studentId);
    if (reg == null) return false;

    final days = DateTime.now().difference(reg).inDays;
    return days >= 30;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/MainScreens.jpeg', fit: BoxFit.cover),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    _topBar(),
                    const SizedBox(height: 22),
                    _actionButtons(),
                    const SizedBox(height: 28),
                    _budgetCard(),
                    const SizedBox(height: 22),
                    _expenseDistribution(),
                    const SizedBox(height: 24),
                    _historySection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: _goToProfile,
            child: CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primaryBlue,
              backgroundImage:
                  _profileImagePath != null &&
                      File(_profileImagePath!).existsSync()
                  ? FileImage(File(_profileImagePath!))
                  : null,
              child: _profileImagePath == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: _goToProfile,
              child: Text(
                widget.fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
          ),
          const Icon(Icons.notifications_none, size: 28),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _circleButton("Income", Icons.account_balance_wallet, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddIncomeScreen(studentId: widget.studentId),
              ),
            );
          }),
          _circleButton("Expense", Icons.money_off, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddExpenseScreen(studentId: widget.studentId),
              ),
            );
          }),
          _circleButton("Predicted Plan", Icons.insights, () {
            _navigateToPrediction(context, widget.studentId);
          }),
          _circleButton("Analytics", Icons.bar_chart, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AnalyticsScreen(studentId: widget.studentId),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _circleButton(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 68,
            width: 68,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryBlue,
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // ✅ UPDATED NAVIGATION: uses DB Created_at automatically
  void _navigateToPrediction(BuildContext context, String studentId) async {
    final available = await _isPredictionAvailableFromDb();

    if (!mounted) return;

    if (available) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PredictionPlanScreen(studentId: studentId),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmptyPredictionPlanScreen(studentId: studentId),
        ),
      );
    }
  }

  Widget _budgetCard() {
    final bool hasIncome = _currentMonthIncome > 0;
    final double remaining = _currentMonthIncome - _currentMonthExpense;

    final double progressValue = !hasIncome
        ? 1.0
        : (remaining / _currentMonthIncome).clamp(0.0, 1.0);

    final String progressText = !hasIncome
        ? "100%"
        : "${(progressValue * 100).toInt()}%";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 170,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Monthly Budget",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _budgetRow(
                    "Total Budget",
                    _loadingTotals ? "—" : "Rs. ${_currentMonthIncome.toInt()}",
                  ),
                  _budgetRow(
                    "Total Spent",
                    _loadingTotals
                        ? "—"
                        : "Rs. ${_currentMonthExpense.toInt()}",
                  ),
                ],
              ),
            ),
            const Spacer(),
            Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 80,
                      width: 80,
                      child: CircularProgressIndicator(
                        value: progressValue,
                        strokeWidth: 7,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    Text(
                      progressText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text("Remaining", style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _budgetRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _expenseDistribution() {
    final orderedKeys = ['Essentials', 'Leisure', 'Academics', 'Others'];

    final double totalExpense = _categoryTotals.values.fold(
      0.0,
      (a, b) => a + b,
    );
    final bool hasData = totalExpense > 0.0;

    final List<PieChartSectionData> sections = hasData
        ? List.generate(orderedKeys.length, (i) {
            final String key = orderedKeys[i];
            final double value = (_categoryTotals[key] ?? 0.0).toDouble();
            final double percent = totalExpense == 0.0
                ? 0.0
                : ((value / totalExpense) * 100).toDouble();
            final bool isTouched = i == _touchedIndex;
            final double safePercent = percent <= 0.0 ? 0.01 : percent;

            return PieChartSectionData(
              value: safePercent,
              title: percent < 5 ? '' : '${percent.toStringAsFixed(0)}%',
              color: _categoryColor(key),
              radius: isTouched ? 42 : 35,
              titleStyle: TextStyle(
                fontSize: isTouched ? 13 : 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          })
        : [
            PieChartSectionData(
              value: 1.0,
              color: Colors.grey.shade300,
              radius: 35,
              title: '',
            ),
          ];

    double remainingFor(String category) {
      final allocated = _predictedAllocations[category] ?? 0.0;
      final spent = _categoryTotals[category] ?? 0.0;

      final remaining = allocated - spent;
      return remaining < 0 ? 0 : remaining;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  height: 160,
                  width: 160,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 50,
                      sectionsSpace: 3,
                      sections: sections,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (!event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null) {
                            setState(() => _touchedIndex = -1);
                            return;
                          }
                          setState(() {
                            _touchedIndex =
                                response.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Remaining Allocation",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _remainingRow(
                          "Essentials",
                          Colors.red,
                          remainingFor('Essentials'),
                        ),
                        _remainingRow(
                          "Leisure",
                          Colors.orange,
                          remainingFor('Leisure'),
                        ),
                        _remainingRow(
                          "Academics",
                          Colors.blue,
                          remainingFor('Academics'),
                        ),
                        _remainingRow(
                          "Others",
                          Colors.purple,
                          remainingFor('Others'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _Legend(color: Colors.red, label: "Essentials"),
                SizedBox(width: 16),
                _Legend(color: Colors.orange, label: "Leisure"),
                SizedBox(width: 16),
                _Legend(color: Colors.blue, label: "Academics"),
                SizedBox(width: 16),
                _Legend(color: Colors.purple, label: "Others"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _remainingRow(String label, Color color, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            _currentMonthIncome == 0 ? "—" : "Rs. ${amount.toInt()}",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _historySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                "History",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          HistoryScreen(studentId: widget.studentId),
                    ),
                  );
                },
                child: const Text("View more"),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loadingHistory)
            const CircularProgressIndicator()
          else
            ..._history.take(4).map(_historyTile),
        ],
      ),
    );
  }

  Widget _historyTile(_DashboardHistoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 6,
            backgroundColor: item.isIncome
                ? Colors.green
                : AppColors.primaryBlue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(item.subtitle, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.amount,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(item.date, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
