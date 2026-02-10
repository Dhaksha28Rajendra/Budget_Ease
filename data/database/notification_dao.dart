import 'package:budget_ease/data/database/db_helper.dart';

class NotificationDAO {
  Future<void> insertNotification({
    required String studentId,
    required String title,
    required String message,
  }) async {
    final db = await DBHelper.instance.database;

    await db.insert('Notification', {
      'Student_id': studentId,
      'Title': title,
      'Message': message,
      'Created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getNotificationsByStudent(
    String studentId,
  ) async {
    final db = await DBHelper.instance.database;

    return await db.query(
      'Notification',
      where: 'Student_id = ?',
      whereArgs: [studentId],
      orderBy: 'Created_at DESC',
    );
  }

  Future<bool> hasAnyNotifications(String studentId) async {
    final db = await DBHelper.instance.database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM Notification WHERE Student_id = ?',
      [studentId],
    );

    return (result.first['count'] as int) > 0;
  }
}
