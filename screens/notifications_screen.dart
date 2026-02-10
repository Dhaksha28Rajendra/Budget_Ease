import 'package:flutter/material.dart';
import '../data/database/notification_dao.dart';
import '../core/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  final String studentId;

  const NotificationsScreen({super.key, required this.studentId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationDAO _dao = NotificationDAO();
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final data = await _dao.getNotificationsByStudent(widget.studentId);
    if (!mounted) return;

    setState(() {
      _notifications = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: AppColors.primaryBlue,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? const Center(child: Text("No notifications yet"))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final n = _notifications[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.notifications),
                    title: Text(n['Title']),
                    subtitle: Text(n['Message']),
                    trailing: Text(
                      n['Created_at']
                          .toString()
                          .substring(0, 16)
                          .replaceAll('T', ' '),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
