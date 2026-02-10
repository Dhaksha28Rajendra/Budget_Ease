import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('budget_ease.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    debugPrint("🔥 DB PATH USED BY APP => $path");

    return await openDatabase(
      path,
      version: 3, // ✅ bump version to support new columns + retention
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1) STUDENT
    await db.execute('''
  CREATE TABLE Student (
    Student_id TEXT PRIMARY KEY,
    First_name TEXT NOT NULL,
    Last_name TEXT NOT NULL,
    Email TEXT NOT NULL UNIQUE,
    Password TEXT NOT NULL,
    Gender TEXT NOT NULL,

    Academic_year TEXT,
    Profile_image TEXT,

    Activation_status TEXT NOT NULL,
    Verification_code TEXT,

    is_deleted INTEGER DEFAULT 0,
    deleted_at TEXT,

    Created_at TEXT NOT NULL   -- ✅ ADD THIS LINE
  )
''');

    // 2) PROFILE_UPDATE
    await db.execute('''
      CREATE TABLE Profile_Update (
        Student_id TEXT NOT NULL,
        Profile_type TEXT NOT NULL,
        Profile_date TEXT NOT NULL,
        PRIMARY KEY (Student_id, Profile_type, Profile_date),
        FOREIGN KEY (Student_id) REFERENCES Student (Student_id) ON DELETE CASCADE
      )
    ''');

    // 3) EXPENSE (adds retention fields)
    await db.execute('''
      CREATE TABLE Expense (
        Expense_id INTEGER PRIMARY KEY AUTOINCREMENT,
        Expense_date TEXT NOT NULL,
        Category_type TEXT NOT NULL,
        Expense_amount REAL NOT NULL,
        Student_id TEXT,

        status TEXT,
        marked_at TEXT,

        FOREIGN KEY (Student_id) REFERENCES Student (Student_id)
      )
    ''');

    // 4) INCOME (adds retention fields)
    await db.execute('''
      CREATE TABLE Income (
        Income_id INTEGER PRIMARY KEY AUTOINCREMENT,
        Income_amount REAL NOT NULL,
        Source_type TEXT NOT NULL,
        Income_date TEXT NOT NULL,
        Student_id TEXT,

        status TEXT,
        marked_at TEXT,

        FOREIGN KEY (Student_id) REFERENCES Student (Student_id)
      )
    ''');

    // 5) BUDGET_PLAN (superset columns from your profile DBHelper)
    await db.execute('''
      CREATE TABLE Budget_Plan (
        Budget_id INTEGER PRIMARY KEY AUTOINCREMENT,
        Status TEXT,
        Other_allocation REAL,
        Academic_allocation REAL,
        Leisure_allocation REAL,
        Essen_allocation REAL,
        Total_Expense REAL,
        Total_Income REAL,
        Current_Essen REAL,
        Current_Leisure REAL,
        Current_Acedamic REAL,
        Current_Other REAL,
        Student_id TEXT,
        Plan_date TEXT,
        FOREIGN KEY (Student_id) REFERENCES Student (Student_id)
      )
    ''');

    // 6) DAILY EXPENSE SUMMARY (from main DBHelper)
    await db.execute('''
      CREATE TABLE DailyExpenseSummary (
        Summary_id INTEGER PRIMARY KEY AUTOINCREMENT,
        Expense_date TEXT NOT NULL,
        Total_expense REAL NOT NULL,
        Student_id TEXT,
        UNIQUE (Student_id, Expense_date)
      )
    ''');

    // 7) NOTIFICATION (from main DBHelper)
    await db.execute('''
      CREATE TABLE Notification (
        Notification_id INTEGER PRIMARY KEY AUTOINCREMENT,
        Student_id TEXT NOT NULL,
        Title TEXT NOT NULL,
        Message TEXT NOT NULL,
        Created_at TEXT NOT NULL
      )
    ''');

    debugPrint("✅ SQLITE SETUP: All tables created (v$version)");
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    debugPrint("⬆️ Upgrading DB: $oldVersion -> $newVersion");

    // Ensure tables exist (safe for users coming from partial schemas)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS DailyExpenseSummary (
        Summary_id INTEGER PRIMARY KEY AUTOINCREMENT,
        Expense_date TEXT NOT NULL,
        Total_expense REAL NOT NULL,
        Student_id TEXT,
        UNIQUE (Student_id, Expense_date)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS Notification (
        Notification_id INTEGER PRIMARY KEY AUTOINCREMENT,
        Student_id TEXT NOT NULL,
        Title TEXT NOT NULL,
        Message TEXT NOT NULL,
        Created_at TEXT NOT NULL
      )
    ''');

    // Add missing columns safely (only ADD COLUMN is supported)
    await _ensureColumn(db, 'Student', 'Academic_year', 'TEXT');
    await _ensureColumn(db, 'Student', 'Profile_image', 'TEXT');
    await _ensureColumn(db, 'Student', 'is_deleted', 'INTEGER DEFAULT 0');
    await _ensureColumn(db, 'Student', 'deleted_at', 'TEXT');

    await _ensureColumn(db, 'Expense', 'status', 'TEXT');
    await _ensureColumn(db, 'Expense', 'marked_at', 'TEXT');

    await _ensureColumn(db, 'Income', 'status', 'TEXT');
    await _ensureColumn(db, 'Income', 'marked_at', 'TEXT');

    debugPrint("✅ SQLITE UPGRADE COMPLETE");
  }

  /// Adds a column only if it does not already exist
  Future<void> _ensureColumn(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final cols = await db.rawQuery("PRAGMA table_info($table)");
    final exists = cols.any((row) => (row['name']?.toString() ?? '') == column);

    if (!exists) {
      debugPrint("➕ Adding column: $table.$column");
      await db.execute("ALTER TABLE $table ADD COLUMN $column $definition");
    }
  }

  // ✅ Debug helper
  Future<void> debugStudentSchema() async {
    final db = await database;
    final result = await db.rawQuery("PRAGMA table_info(Student)");
    debugPrint("🧪 Student Table Schema:");
    for (final row in result) {
      debugPrint(row.toString());
    }
  }
}
