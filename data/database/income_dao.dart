import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';
import '../models/income_model.dart';

class IncomeDao {
  final DBHelper _dbHelper = DBHelper.instance;

  // =============================
  // INSERT INCOME
  // =============================
  Future<int> insertIncome(IncomeModel income) async {
    final Database db = await _dbHelper.database;
    return db.insert(
      'Income',
      income.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // =============================
  // GET INCOME BY STUDENT
  // =============================
  Future<List<IncomeModel>> getIncomeByStudent(String studentId) async {
    final Database db = await _dbHelper.database;

    final result = await db.query(
      'Income',
      where: 'Student_id = ?',
      whereArgs: [studentId],
      orderBy: 'Income_date DESC',
    );

    return result.map((e) => IncomeModel.fromMap(e)).toList();
  }

  // ==========================================================
  // GET CURRENT MONTH TOTAL INCOME
  // ==========================================================
  Future<double> getCurrentMonthTotalIncome(String studentId) async {
    final Database db = await _dbHelper.database;
    final now = DateTime.now();
    final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final result = await db.rawQuery(
      '''
      SELECT SUM(Income_amount) AS total 
      FROM Income 
      WHERE Student_id = ? 
        AND strftime('%Y-%m', Income_date) = ?
      ''',
      [studentId, yearMonth],
    );

    final total = result.first['total'];
    return total == null ? 0.0 : (total as num).toDouble();
  }

  // =============================
  // CHECK IF USER HAS ANY INCOME
  // =============================
  Future<bool> hasAnyIncome(String studentId) async {
    final Database db = await _dbHelper.database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM Income WHERE Student_id = ?',
      [studentId],
    );

    return (result.first['count'] as int) > 0;
  }

  // =============================
  // GET TOTAL INCOME (LIFETIME)
  // =============================
  Future<double> getTotalIncome(String studentId) async {
    final Database db = await _dbHelper.database;

    final result = await db.rawQuery(
      'SELECT SUM(Income_amount) AS total FROM Income WHERE Student_id = ?',
      [studentId],
    );

    final total = result.first['total'];
    return total == null ? 0.0 : (total as num).toDouble();
  }

  // ==========================================================
  // GET INCOME TRANSACTIONS BY MONTH (NOT GROUPED)
  // ==========================================================
  Future<List<Map<String, dynamic>>> getIncomeTransactionsByMonth({
    required String studentId,
    required int year,
    required int month,
  }) async {
    final Database db = await _dbHelper.database;
    final String monthStr = month.toString().padLeft(2, '0');

    return db.rawQuery(
      '''
      SELECT Income_amount, Source_type, Income_date
      FROM Income
      WHERE Student_id = ?
        AND strftime('%Y', Income_date) = ?
        AND strftime('%m', Income_date) = ?
      ORDER BY Income_date ASC
      ''',
      [studentId, year.toString(), monthStr],
    );
  }

  // ==========================================================
  // 🔮 GET PREDICTED PLAN (DYNAMIC & ACCURATE)
  // ==========================================================
  Future<Map<String, double>> getPredictedPlan(String studentId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // 1. Get Monthly Income (FULL income from Add Income screen)
    final double incomeTotal = await getCurrentMonthTotalIncome(studentId);

    // 2. Get Monthly Expenses
    final expenseResult = await db.rawQuery(
      "SELECT SUM(Expense_amount) as total FROM Expense WHERE Student_id = ? AND strftime('%Y-%m', Expense_date) = ?",
      [studentId, yearMonth],
    );

    final double expenseTotal = expenseResult.first['total'] == null
        ? 0.0
        : (expenseResult.first['total'] as num).toDouble();

    // 3. Remaining balance
    // ignore: unused_local_variable
    final double availableToPlan = incomeTotal - expenseTotal;

    if (incomeTotal <= 0) {
      return {
        'totalIncome': 0.0,
        'essential': 0.0,
        'academic': 0.0,
        'leisure': 0.0,
        'other': 0.0,
      };
    }

    // 4. Allocate based on TOTAL INCOME (not remaining)
    return {
      'totalIncome': incomeTotal, // 🔥 THIS goes to center
      'essential': incomeTotal * 0.50,
      'academic': incomeTotal * 0.20,
      'leisure': incomeTotal * 0.20,
      'other': incomeTotal * 0.10,
    };
  }

  // =============================
  // GET INCOME BY MONTH (GROUPED)
  // =============================
  Future<List<Map<String, dynamic>>> getIncomeByMonth({
    required String studentId,
    required int year,
    required int month,
  }) async {
    final Database db = await _dbHelper.database;
    final String monthStr = month.toString().padLeft(2, '0');

    return db.rawQuery(
      '''
      SELECT Source_type, SUM(Income_amount) AS total
      FROM Income
      WHERE Student_id = ?
        AND strftime('%Y', Income_date) = ?
        AND strftime('%m', Income_date) = ?
      GROUP BY Source_type
      ''',
      [studentId, year.toString(), monthStr],
    );
  }

  // =============================
  // GET TRANSACTIONS BY MONTH & SOURCE
  // =============================
  Future<List<Map<String, dynamic>>> getIncomeTransactionsByMonthAndSource({
    required String studentId,
    required String monthKey, // YYYY-MM
    required String sourceType,
  }) async {
    final Database db = await _dbHelper.database;

    return db.rawQuery(
      '''
      SELECT *
      FROM Income
      WHERE Student_id = ?
        AND strftime('%Y-%m', Income_date) = ?
        AND Source_type = ?
      ORDER BY Income_date DESC
      ''',
      [studentId, monthKey, sourceType],
    );
  }

  Future<Map<String, double>> getPredictionAllocations(String studentId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // 1. Monthly Income
    final incomeRes = await db.rawQuery(
      "SELECT SUM(Income_amount) as total FROM Income WHERE Student_id = ? AND strftime('%Y-%m', Income_date) = ?",
      [studentId, yearMonth],
    );

    final double incomeTotal = incomeRes.first['total'] == null
        ? 0.0
        : (incomeRes.first['total'] as num).toDouble();

    if (incomeTotal <= 0) {
      return {
        'Essentials': 0.0,
        'Academics': 0.0,
        'Leisure': 0.0,
        'Others': 0.0,
      };
    }

    return {
      'Essentials': incomeTotal * 0.50,
      'Academics': incomeTotal * 0.20,
      'Leisure': incomeTotal * 0.20,
      'Others': incomeTotal * 0.10,
    };
  }

  // =============================
  // DELETE INCOME
  // =============================
  Future<int> deleteIncome(int incomeId) async {
    final Database db = await _dbHelper.database;
    return db.delete('Income', where: 'Income_id = ?', whereArgs: [incomeId]);
  }
}
