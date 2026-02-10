import 'db_helper.dart';

class ProfileUpdateDAO {
  /* ===============================
    INSERT PROFILE UPDATE
  =============================== */
  Future<int> insertProfileUpdate({
    required String studentId,
    required String profileType,
    required String profileDate,
  }) async {
    final db = await DBHelper.instance.database;

    return await db.insert('Profile_Update', {
      'Student_id': studentId,
      'Profile_type': profileType,
      'Profile_date': profileDate,
    });
  }

  /* ===============================
    GET PROFILE UPDATES
  =============================== */
  Future<List<Map<String, dynamic>>> getUpdates(String studentId) async {
    final db = await DBHelper.instance.database;

    return await db.query(
      'Profile_Update',
      where: 'Student_id = ?',
      whereArgs: [studentId],
      orderBy: 'Profile_date DESC', // Latest updates first
    );
  }
}
