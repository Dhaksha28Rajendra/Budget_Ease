import 'dart:io';

import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'delete_account_screen.dart';
import 'privacy_security_screen.dart';

import '../data/database/student_dao.dart';
import '../services/session_manager.dart';
import '../data/database/db_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StudentDAO _dao = StudentDAO();

  String fullName = "Loading...";
  String emailText = "";
  String? profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    await DBHelper.instance.debugStudentSchema();
    final email = SessionManager.currentEmail;

    if (email == null || email.trim().isEmpty) {
      setState(() {
        fullName = "Guest";
        emailText = "";
        profileImagePath = null;
      });
      return;
    }

    final data = await _dao.getProfileByEmail(email);
    if (!mounted) return;

    final first = (data?['First_name'] ?? '').toString().trim();
    final last = (data?['Last_name'] ?? '').toString().trim();
    final img = (data?['Profile_image'] ?? '').toString().trim();

    setState(() {
      fullName = ("$first $last").trim().isEmpty
          ? "User"
          : ("$first $last").trim();
      emailText = (data?['Email'] ?? email).toString();
      profileImagePath = img.isNotEmpty ? img : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        profileImagePath != null &&
        profileImagePath!.isNotEmpty &&
        File(profileImagePath!).existsSync();

    return Scaffold(
      body: Stack(
        children: [
          /// ✅ SAME BACKGROUND IMAGE YOU USED
          Positioned.fill(
            child: Image.asset('assets/MainScreens.jpeg', fit: BoxFit.cover),
          ),

          /// slight overlay for readability
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.05)),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topBar(context),
                  const SizedBox(height: 10),

                  /// ✅ BLUE BANNER (smaller)
                  _bannerCard(),

                  const SizedBox(height: 16),

                  /// ✅ BIGGER PROFILE CARD
                  _profileMiniCard(hasImage: hasImage),

                  const SizedBox(height: 18),

                  _tile(
                    icon: Icons.edit_outlined,
                    title: "Edit Profile",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      ).then((_) => _loadProfile());
                    },
                  ),

                  _tile(
                    icon: Icons.security_outlined,
                    title: "Privacy & Security",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacySecurityScreen(),
                        ),
                      );
                    },
                  ),

                  _tile(
                    icon: Icons.info_outline,
                    title: "About Us",
                    onTap: () => _showAboutDialog(context),
                  ),

                  _tile(
                    icon: Icons.delete_outline,
                    title: "Delete Account",
                    isDestructive: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DeleteAccountScreen(),
                        ),
                      );
                    },
                  ),

                  _tile(
                    icon: Icons.logout,
                    title: "Logout",
                    isDestructive: true,
                    onTap: () => _showLogoutDialog(context),
                  ),

                  const SizedBox(height: 26),
                  _footer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= TOP BAR =================
  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(
              Icons.arrow_back,
              size: 26,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          "Account",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  // ================= BLUE BANNER =================
  Widget _bannerCard() {
    return Container(
      height: 85, // ✅ slightly smaller
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.primaryBlue, // ✅ BLUE ONLY
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          "Welcome!\nManage your profile and security settings",
          style: TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ================= PROFILE CARD =================
  Widget _profileMiniCard({required bool hasImage}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36, // ✅ BIGGER IMAGE
            backgroundColor: AppColors.primaryBlue,
            backgroundImage: hasImage
                ? FileImage(File(profileImagePath!))
                : null,
            child: !hasImage
                ? const Icon(Icons.person, size: 36, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 19, // ✅ BIGGER NAME
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  emailText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= TILE =================
  Widget _tile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: isDestructive ? Colors.red : Colors.black87),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: isDestructive ? Colors.red : Colors.black,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= FOOTER =================
  Widget _footer() {
    return Column(
      children: [
        Text(
          "Made with ❤️ in Sri Lanka",
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "App version: 1.0.0",
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ================= DIALOGS =================
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'About Budget Ease',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryBlue,
          ),
        ),
        content: const Text(
          'Budget Ease helps you manage your finances smartly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: AppColors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Logout',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryBlue,
          ),
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              SessionManager.clear();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
