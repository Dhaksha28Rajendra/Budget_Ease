import 'db_helper.dart';

class StudentDAO {
  /* ===============================
   REGISTER
  =============================== */

  Future<int> insertStudentWithOtp({
    required String studentId,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String gender,
    required String otp,
  }) async {
    final db = await DBHelper.instance.database;

    return db.insert('Student', {
      'Student_id': studentId,
      'First_name': firstName,
      'Last_name': lastName,
      'Email': email.toLowerCase(),
      'Password': password,
      'Gender': gender,
      'Activation_status': 'INACTIVE',
      'Verification_code': otp,

      // ✅ SAVE ACCOUNT CREATION DATE
      'Created_at': DateTime.now().toIso8601String(),
    });
  }

  /* ===============================
   CHECK EMAIL
  =============================== */

  Future<bool> isEmailExists(String email) async {
    final db = await DBHelper.instance.database;

    final res = await db.query(
      'Student',
      columns: ['Student_id'],
      where: 'Email = ?',
      whereArgs: [email.toLowerCase()],
    );

    return res.isNotEmpty;
  }

  /* ===============================
   GET STUDENT
  =============================== */

  Future<Map<String, dynamic>?> getStudentByEmail(String email) async {
    final db = await DBHelper.instance.database;

    final res = await db.query(
      'Student',
      where: 'Email = ?',
      whereArgs: [email.toLowerCase()],
      limit: 1,
    );

    return res.isEmpty ? null : res.first;
  }

  /* ===============================
   GET STUDENT BY ID
  =============================== */

  Future<Map<String, dynamic>?> getStudentById(String studentId) async {
    final db = await DBHelper.instance.database;

    final res = await db.query(
      'Student',
      where: 'Student_id = ?',
      whereArgs: [studentId],
      limit: 1,
    );

    return res.isEmpty ? null : res.first;
  }

  // ✅ NEW: Get Created_at as DateTime (used by EmptyPredictionPlanScreen)
  Future<DateTime?> getRegistrationDate(String studentId) async {
    final data = await getStudentById(studentId);
    if (data == null) return null;

    final raw = (data['Created_at'] ?? '').toString().trim();
    if (raw.isEmpty) return null;

    // Handles both:
    // "2026-02-09T11:15:35.123" (ISO)
    // "2026-02-09 11:15:35"     (sqlite datetime)
    final iso = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');

    return DateTime.tryParse(iso);
  }

  /* ===============================
   ACTIVATE ACCOUNT
  =============================== */

  Future<void> activateStudent(String studentId) async {
    final db = await DBHelper.instance.database;

    await db.update(
      'Student',
      {'Activation_status': 'ACTIVE', 'Verification_code': null},
      where: 'Student_id = ?',
      whereArgs: [studentId],
    );
  }

  /* ===============================
   LOGIN
  =============================== */

  Future<Map<String, dynamic>?> loginStudent(
    String email,
    String password,
  ) async {
    final db = await DBHelper.instance.database;

    final res = await db.query(
      'Student',
      where: 'Email = ? AND Password = ? AND Activation_status = ?',
      whereArgs: [email.toLowerCase(), password, 'ACTIVE'],
      limit: 1,
    );

    return res.isEmpty ? null : res.first;
  }

  /* ===============================
   OTP MANAGEMENT
  =============================== */

  Future<void> updateOtpByEmail(String email, String otp) async {
    final db = await DBHelper.instance.database;

    await db.update(
      'Student',
      {'Verification_code': otp},
      where: 'Email = ?',
      whereArgs: [email.toLowerCase()],
    );
  }

  Future<void> clearOtpByEmail(String email) async {
    final db = await DBHelper.instance.database;

    await db.update(
      'Student',
      {'Verification_code': null},
      where: 'Email = ?',
      whereArgs: [email.toLowerCase()],
    );
  }

  /* ===============================
   PASSWORD RESET
  =============================== */

  Future<void> updatePasswordByEmail(String email, String newPassword) async {
    final db = await DBHelper.instance.database;

    await db.update(
      'Student',
      {'Password': newPassword, 'Verification_code': null},
      where: 'Email = ?',
      whereArgs: [email.toLowerCase()],
    );
  }

  /* ===============================
   PROFILE
  =============================== */

  Future<Map<String, dynamic>?> getProfileByEmail(String email) async {
    return getStudentByEmail(email);
  }

  Future<int> updateProfileByEmail({
    required String email,
    required String firstName,
    required String lastName,
    required String academicYear,
    String? profileImagePath,
  }) async {
    final db = await DBHelper.instance.database;

    return db.update(
      'Student',
      {
        'First_name': firstName,
        'Last_name': lastName,
        'Academic_year': academicYear,
        'Profile_image': profileImagePath,
      },
      where: 'Email = ?',
      whereArgs: [email.toLowerCase()],
    );
  }

  Future<void> clearProfileImageByEmail(String email) async {
    final db = await DBHelper.instance.database;

    await db.update(
      'Student',
      {'Profile_image': null},
      where: 'Email = ?',
      whereArgs: [email.toLowerCase()],
    );
  }

  /* ===============================
   DELETE / RETENTION
  =============================== */

  Future<void> purgeAfter90Days() async {
    final db = await DBHelper.instance.database;

    final cutoffDate = DateTime.now().subtract(const Duration(days: 90));

    await db.delete(
      'Student',
      where: 'is_deleted = 1 AND deleted_at IS NOT NULL AND deleted_at < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  Future<void> softDeleteAccountKeepRecords90Days(String email) async {
    final db = await DBHelper.instance.database;

    await db.update(
      'Student',
      {'is_deleted': 1, 'deleted_at': DateTime.now().toIso8601String()},
      where: 'Email = ?',
      whereArgs: [email.toLowerCase()],
    );
  }

  Future<int> deleteStudentByEmail(String email) async {
    final db = await DBHelper.instance.database;

    return db.delete(
      'Student',
      where: 'Email = ?',
      whereArgs: [email.toLowerCase()],
    );
  }
}
