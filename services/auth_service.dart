import 'dart:math';
import '../data/database/student_dao.dart';
import '../data/models/student_model.dart';

class AuthService {
  final StudentDAO _dao = StudentDAO();

  /// ===============================
  /// REGISTER STUDENT
  /// ===============================
  Future<String?> registerStudent({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String gender,
  }) async {
    // Check if email already exists
    final exists = await _dao.isEmailExists(email);
    if (exists) return null;

    final String studentId = _generateStudentId();
    final String otp = _generateOtp();

    await _dao.insertStudentWithOtp(
      studentId: studentId,
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
      gender: gender,
      otp: otp,
    );

    return studentId;
  }

  /// ===============================
  /// VERIFY OTP (REGISTRATION)
  /// ===============================
  Future<bool> verifyOtp({
    required String email,
    required String enteredOtp,
  }) async {
    final Map<String, dynamic>? data = await _dao.getStudentByEmail(email);

    if (data == null) return false;

    final String? storedOtp = data['Verification_code'];
    if (storedOtp == null || storedOtp != enteredOtp) return false;

    await _dao.activateStudent(data['Student_id']);

    // Optional safety: clear OTP after verification
    await _dao.clearOtpByEmail(email);

    return true;
  }

  /// ===============================
  /// LOGIN (ONLY ACTIVE USERS)
  /// ===============================
  Future<StudentModel?> loginStudent({
    required String email,
    required String password,
  }) async {
    final Map<String, dynamic>? data = await _dao.loginStudent(email, password);

    if (data == null) return null;

    return StudentModel.fromMap(data);
  }

  /// ===============================
  /// GET STUDENT BY EMAIL
  /// ===============================
  Future<StudentModel?> getStudentByEmail(String email) async {
    final Map<String, dynamic>? data = await _dao.getStudentByEmail(email);

    if (data == null) return null;

    return StudentModel.fromMap(data);
  }

  /// ===============================
  /// FORGOT PASSWORD – SEND OTP
  /// ===============================
  Future<bool> sendResetOtp(String email) async {
    final exists = await _dao.isEmailExists(email);
    if (!exists) return false;

    final String otp = _generateOtp();
    await _dao.updateOtpByEmail(email, otp);

    return true;
  }

  /// ===============================
  /// VERIFY OTP (FORGOT PASSWORD)
  /// ===============================
  Future<bool> verifyResetOtp({
    required String email,
    required String enteredOtp,
  }) async {
    final Map<String, dynamic>? data = await _dao.getStudentByEmail(email);

    if (data == null) return false;

    final String? storedOtp = data['Verification_code'];
    if (storedOtp == null || storedOtp != enteredOtp) return false;

    // Clear OTP after successful verification
    await _dao.clearOtpByEmail(email);

    return true;
  }

  /// ===============================
  /// RESET PASSWORD
  /// ===============================
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    await _dao.updatePasswordByEmail(email, newPassword);
  }

  /// ===============================
  /// HELPERS
  /// ===============================
  String _generateStudentId() {
    final random = Random();
    return 'STD${DateTime.now().millisecondsSinceEpoch}${random.nextInt(1000)}';
  }

  // ✅ Added (your profile-related helper) — does not change main logic
  String _generateOtp() => (1000 + Random().nextInt(9000)).toString();
}
