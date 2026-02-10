import 'package:budget_ease/data/database/db_helper.dart';
import 'package:sqflite/sqflite.dart';

class ExpenseDAO {
  // =============================
  // INSERT EXPENSE
  // =============================
  Future<int> insertExpense({
    required String studentId,
    required String category,
    required double amount,
    required String date, // YYYY-MM-DD
  }) async {
    final Database db = await DBHelper.instance.database;

    return await db.insert('Expense', {
      'Student_id': studentId,
      'Category_type': category,
      'Expense_amount': amount,
      'Expense_date': date,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ==========================================================
  // GET EXPENSE BY MONTH (Analytics & Donut Chart)
  // UPDATED: Now uses SUM and GROUP BY for chart data
  // ==========================================================
  Future<List<Map<String, dynamic>>> getExpenseByMonth({
    required String studentId,
    required int year,
    required int month,
  }) async {
    final db = await DBHelper.instance.database;

    return await db.rawQuery(
      '''
      SELECT Category_type, SUM(Expense_amount) as total
      FROM Expense
      WHERE Student_id = ?
        AND strftime('%Y', Expense_date) = ?
        AND strftime('%m', Expense_date) = ?
      GROUP BY Category_type
      ''',
      [studentId, year.toString(), month.toString().padLeft(2, '0')],
    );
  }

  // =====================================
  // ✅ EXPENSE DETAILS BY CATEGORY (Modal + PDF)
  // =====================================
  Future<List<Map<String, dynamic>>> getExpenseTransactionsByMonthAndCategory({
    required String studentId,
    required String monthKey, // yyyy-MM
    required String categoryType,
  }) async {
    final db = await DBHelper.instance.database;

    return await db.rawQuery(
      '''
      SELECT
        Expense_date AS date,
        Expense_amount AS amount,
        Category_type AS subCategory
      FROM Expense
      WHERE Student_id = ?
        AND Category_type = ?
        AND strftime('%Y-%m', Expense_date) = ?
      ORDER BY Expense_date DESC
      ''',
      [studentId, categoryType, monthKey],
    );
  }

  // ==========================================================
  // ✅ NEW: GET EXPENSE TRANSACTIONS BY MONTH (NOT GROUPED)
  // Needed for Analytics daily chart + accurate totals
  // ==========================================================
  Future<List<Map<String, dynamic>>> getExpenseTransactionsByMonth({
    required String studentId,
    required int year,
    required int month,
  }) async {
    final db = await DBHelper.instance.database;
    final String monthStr = month.toString().padLeft(2, '0');

    return await db.rawQuery(
      '''
      SELECT Expense_amount, Category_type, Expense_date
      FROM Expense
      WHERE Student_id = ?
        AND strftime('%Y', Expense_date) = ?
        AND strftime('%m', Expense_date) = ?
      ORDER BY Expense_date ASC
      ''',
      [studentId, year.toString(), monthStr],
    );
  }

  // ==========================================================
  // GET CURRENT MONTH TOTAL EXPENSE
  // UPDATED: Optimized strftime query for Prediction Plan balance
  // ==========================================================
  Future<double> getCurrentMonthTotalExpense(String studentId) async {
    final db = await DBHelper.instance.database;
    final now = DateTime.now();
    final String currentMonth =
        "${now.year}-${now.month.toString().padLeft(2, '0')}";

    final result = await db.rawQuery(
      '''
      SELECT SUM(Expense_amount) as total 
      FROM Expense 
      WHERE Student_id = ? 
      AND strftime('%Y-%m', Expense_date) = ?
      ''',
      [studentId, currentMonth],
    );

    final total = result.first['total'];
    return total == null ? 0.0 : (total as num).toDouble();
  }

  // =====================================
  // REMAINING HELPER METHODS
  // =====================================

  Future<Map<String, double>> getCurrentMonthExpenseByCategory(
    String studentId,
  ) async {
    final db = await DBHelper.instance.database;
    final now = DateTime.now();
    final monthStart = DateTime(
      now.year,
      now.month,
      1,
    ).toIso8601String().substring(0, 10);
    final monthEnd = DateTime(
      now.year,
      now.month + 1,
      0,
    ).toIso8601String().substring(0, 10);

    final result = await db.rawQuery(
      '''
      SELECT Category_type, SUM(Expense_amount) as total
      FROM Expense
      WHERE Student_id = ?
        AND Expense_date BETWEEN ? AND ?
      GROUP BY Category_type
      ''',
      [studentId, monthStart, monthEnd],
    );

    final Map<String, double> data = {
      'Essentials': 0,
      'Leisure': 0,
      'Academics': 0,
      'Others': 0,
    };
    for (final row in result) {
      final category = row['Category_type'] as String;
      final amount = (row['total'] as num?)?.toDouble() ?? 0.0;
      if (data.containsKey(category)) data[category] = amount;
    }
    return data;
  }

  Future<Map<String, double>> getCurrentMonthCategoryTotals(
    String studentId,
  ) async {
    final db = await DBHelper.instance.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).toIso8601String();
    final end = DateTime(now.year, now.month + 1, 0).toIso8601String();

    final result = await db.rawQuery(
      '''
      SELECT Category_type, SUM(Expense_amount) as total
      FROM Expense
      WHERE Student_id = ?
        AND Expense_date BETWEEN ? AND ?
      GROUP BY Category_type
      ''',
      [studentId, start, end],
    );

    final map = {
      'Essentials': 0.0,
      'Leisure': 0.0,
      'Academics': 0.0,
      'Others': 0.0,
    };
    for (final row in result) {
      map[row['Category_type'] as String] = (row['total'] as num).toDouble();
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> getExpensesByDate(
    String studentId,
    String date,
  ) async {
    final Database db = await DBHelper.instance.database;
    return await db.query(
      'Expense',
      where: 'Student_id = ? AND Expense_date = ?',
      whereArgs: [studentId, date],
      orderBy: 'Expense_id DESC',
    );
  }

  Future<bool> hasAnyExpense(String studentId) async {
    final db = await DBHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM Expense WHERE Student_id = ?',
      [studentId],
    );
    return (result.first['count'] as int) > 0;
  }

  Future<List<Map<String, dynamic>>> getAllExpensesByStudent(
    String studentId,
  ) async {
    final Database db = await DBHelper.instance.database;
    return await db.query(
      'Expense',
      where: 'Student_id = ?',
      whereArgs: [studentId],
      orderBy: 'Expense_date DESC',
    );
  }

  // =============================
  // DELETE EXPENSE
  // =============================
  Future<int> deleteExpense(int expenseId) async {
    final Database db = await DBHelper.instance.database;
    return await db.delete(
      'Expense',
      where: 'Expense_id = ?',
      whereArgs: [expenseId],
    );
  }
}
