import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'email_verification_screen.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();

  bool acceptTerms = false;

  String? selectedGender;
  String? selectedYear;

  final List<String> genders = ['Female', 'Male', 'Other'];
  final List<String> years = ['Year 1', 'Year 2', 'Year 3', 'Year 4'];

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final FocusNode passwordFocus = FocusNode();

  bool showRules = false;

  bool hasMinLength = false;
  bool hasUpper = false;
  bool hasLower = false;
  bool hasNumber = false;
  bool hasSpecial = false;

  bool showPassword = false;
  bool showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    passwordFocus.addListener(() {
      setState(() {
        showRules = passwordFocus.hasFocus;
      });
    });
  }

  void checkPassword(String password) {
    setState(() {
      hasMinLength = password.length >= 8;
      hasUpper = RegExp(r'[A-Z]').hasMatch(password);
      hasLower = RegExp(r'[a-z]').hasMatch(password);
      hasNumber = RegExp(r'[0-9]').hasMatch(password);
      hasSpecial = RegExp(r'[!@#$%^&*_]').hasMatch(password);
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================= TERMS POPUP =================
  void _showTermsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Terms & Conditions",
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
          ),
          content: SizedBox(
            height: 350,
            child: SingleChildScrollView(
              child: Text(
                """
Welcome to Budget_Ease. By creating an account and using this application, you agree to the following Terms and Conditions.

1. Acceptance of Terms

By registering and using Budget_Ease, you confirm that you have read, understood, and agreed to these Terms & Conditions. If you do not agree, please do not use the application.

2. Purpose of the App

Budget_Ease is designed to help users manage personal finances, track expenses, plan budgets, and gain insights into spending habits.
The app is intended for personal use only and should not be considered professional financial or investment advice.

3. User Responsibilities

As a user, you agree to:
• Provide accurate and truthful information during registration.
• Keep your login credentials confidential.
• Use the app only for lawful purposes.
• Be responsible for all activities carried out through your account.

4. Data Privacy & Security

Budget_Ease collects and stores only the data necessary to provide its services.
Your financial data is stored securely and will not be shared with third parties without your consent, except where required by law.
You are responsible for safeguarding your device and account access.

5. Accuracy of Information

While Budget_Ease aims to provide accurate calculations and insights, we do not guarantee that all results will be error-free.
Users are encouraged to verify important financial decisions independently.

6. Account Termination

Budget_Ease reserves the right to:
• Suspend or terminate accounts that violate these Terms.
• Remove access if misuse, fraud, or harmful activity is detected.
Users may delete their account at any time from the app settings.

7. App Updates & Changes

We may update the app, features, or these Terms & Conditions from time to time.
Continued use of the app after updates indicates acceptance of the revised terms.

8. Limitation of Liability

Budget_Ease is not responsible for:
• Financial losses arising from user decisions.
• Data loss caused by device issues, third-party services, or user negligence.
Use of the app is at your own risk.

9. Governing Law

These Terms & Conditions are governed by the applicable laws of your country or region.

10. Contact Us

intellectsrjtaslk@gmail.com
""",
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => acceptTerms = true);
                },
                child: const Text(
                  "I read and understood",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ================= BACKEND CONNECTED =================
  Future<void> _validateAndProceed() async {
    if (firstNameController.text.trim().isEmpty ||
        lastNameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty ||
        confirmPasswordController.text.trim().isEmpty ||
        selectedGender == null ||
        selectedYear == null) {
      _showError("Missing fields found");
      return;
    }

    if (!_isValidEmail(emailController.text.trim())) {
      _showError("Enter a valid email address");
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      _showError("Passwords do not match");
      return;
    }

    if (!(hasMinLength && hasUpper && hasLower && hasNumber && hasSpecial)) {
      _showError("Password does not meet security rules");
      return;
    }

    if (!acceptTerms) {
      _showError("Please accept Terms & Conditions");
      return;
    }

    final studentId = await _authService.registerStudent(
      firstName: firstNameController.text.trim(),
      lastName: lastNameController.text.trim(),
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
      gender: selectedGender!,
    );

    if (!mounted) return;

    if (studentId == null) {
      _showError("Email already registered");
      return;
    }

    // ✅ profile-related addition (from your second code)
    SessionManager.currentEmail = emailController.text.trim().toLowerCase();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EmailVerificationScreen(email: emailController.text.trim()),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ✅ keeps your MAIN screen background logic, but with the mirror effect added
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(3.14159),
            child: Positioned.fill(
              child: Image.asset('assets/background.jpg', fit: BoxFit.cover),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.topRight,
                    child: Image.asset(
                      'assets/Intellects_Logo.png',
                      height: 100,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Create your Account',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField("First Name", firstNameController),
                  _buildTextField("Last Name", lastNameController),
                  _buildDropdown(
                    "Gender",
                    selectedGender,
                    genders,
                    (v) => setState(() => selectedGender = v),
                  ),
                  _buildDropdown(
                    "Academic Year",
                    selectedYear,
                    years,
                    (v) => setState(() => selectedYear = v),
                  ),
                  _buildTextField("Email", emailController),
                  _buildPasswordField(),
                  if (showRules) _buildRules(),
                  _buildConfirmPassword(),
                  _termsRow(),
                  const SizedBox(height: 16),
                  _signUpButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= SMALL UI HELPERS =================
  Widget _termsRow() {
    return Row(
      children: [
        Checkbox(
          value: acceptTerms,
          activeColor: AppColors.primaryBlue,
          onChanged: (v) => setState(() => acceptTerms = v!),
        ),
        Expanded(
          child: GestureDetector(
            onTap: _showTermsDialog,
            child: const Text(
              "Accept Terms and Conditions",
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryBlue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _signUpButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _validateAndProceed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          "Sign Up",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        decoration: _inputDecoration(hint),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: passwordController,
        focusNode: passwordFocus,
        obscureText: !showPassword,
        onChanged: checkPassword,
        decoration: _inputDecoration("Password").copyWith(
          suffixIcon: IconButton(
            icon: Icon(
              showPassword ? Icons.visibility : Icons.visibility_off,
              color: AppColors.primaryBlue,
            ),
            onPressed: () => setState(() => showPassword = !showPassword),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmPassword() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: confirmPasswordController,
        obscureText: !showConfirmPassword,
        decoration: _inputDecoration("Confirm Password").copyWith(
          suffixIcon: IconButton(
            icon: Icon(
              showConfirmPassword ? Icons.visibility : Icons.visibility_off,
              color: AppColors.primaryBlue,
            ),
            onPressed: () =>
                setState(() => showConfirmPassword = !showConfirmPassword),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String hint,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField(
        value: value,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
        decoration: _inputDecoration(hint),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.grey,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildRules() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rule("Minimum 8 characters", hasMinLength),
        _rule("1 Uppercase letter", hasUpper),
        _rule("1 Lowercase letter", hasLower),
        _rule("1 Number", hasNumber),
        _rule("1 Special character", hasSpecial),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _rule(String text, bool ok) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.circle,
          size: 14,
          color: ok ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
