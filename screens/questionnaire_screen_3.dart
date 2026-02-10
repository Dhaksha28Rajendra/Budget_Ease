import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'questionnaire_screen_2.dart';
import 'spender_type_screen.dart';

class QuestionnaireScreen3 extends StatefulWidget {
  final String fullName;
  final String studentId;
  final DateTime registrationDate;

  const QuestionnaireScreen3({
    super.key,
    required this.fullName,
    required this.studentId,
    required this.registrationDate,
  });

  @override
  State<QuestionnaireScreen3> createState() => _QuestionnaireScreen3State();
}

class _QuestionnaireScreen3State extends State<QuestionnaireScreen3> {
  String? totalSpend;

  final List<String> categories = [
    'Essentials',
    'Academic',
    'Leisure',
    'Other',
  ];

  final Map<String, TextEditingController> categoryControllers = {
    'Essentials': TextEditingController(),
    'Academic': TextEditingController(),
    'Leisure': TextEditingController(),
    'Other': TextEditingController(),
  };

  bool get allCategoriesFilled =>
      categoryControllers.values.every((c) => c.text.trim().isNotEmpty);

  String _getIncomeType(String range) {
    if (range.contains('Below LKR 10,000') ||
        range.contains('10,000 – 20,000')) {
      return 'low';
    } else if (range.contains('20,000 – 30,000')) {
      return 'medium';
    } else {
      return 'high';
    }
  }

  void _validateAndFinish() {
    if (totalSpend == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your total monthly spending'),
        ),
      );
      return;
    }

    if (!allCategoriesFilled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter percentage for all categories'),
        ),
      );
      return;
    }

    double totalPercentage = 0;

    for (var entry in categoryControllers.entries) {
      final value = double.tryParse(entry.value.text.trim());
      if (value == null || value < 0 || value > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enter valid percentage (0–100) for ${entry.key}'),
          ),
        );
        return;
      }
      totalPercentage += value;
    }

    if (totalPercentage != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Total must be exactly 100%')),
      );
      return;
    }

    final essentialsPercent = double.parse(
      categoryControllers['Essentials']!.text.trim(),
    );

    String spenderType;
    if (essentialsPercent >= 75) {
      spenderType = "impulsive";
    } else if (essentialsPercent >= 50) {
      spenderType = "balanced";
    } else {
      spenderType = "saver";
    }

    final incomeType = _getIncomeType(totalSpend!);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SpenderTypeScreen(
          spenderType: spenderType,
          incomeType: incomeType, // ✅ PASS INCOME TYPE
          fullName: widget.fullName,
          studentId: widget.studentId,
          registrationDate: widget.registrationDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/Questionnaire.jpeg', fit: BoxFit.cover),
          ),
          SafeArea(
            child: Column(
              children: [
                const LinearProgressIndicator(
                  value: 1.0,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation(AppColors.primaryBlue),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _card(
                          title:
                              'Q6: Approximately how much do you spend per month? (LKR)',
                          child: Column(
                            children: [
                              _radioTotal('Below LKR 10,000'),
                              _radioTotal('LKR 10,000 – 20,000'),
                              _radioTotal('LKR 20,000 – 30,000'),
                              _radioTotal('Above LKR 30,000'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _card(
                          title:
                              'Enter your average monthly spending for each category (%)',
                          child: Column(
                            children: categories.asMap().entries.map((entry) {
                              final index = entry.key;
                              final category = entry.value;
                              final qNo = 7 + index;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Q$qNo. $category',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: categoryControllers[category],
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: 'Enter percentage',
                                      suffixText: '%',
                                      filled: true,
                                      fillColor: AppColors.grey,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(30),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _bottomNav(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _radioTotal(String value) => RadioListTile(
    title: Text(value),
    value: value,
    groupValue: totalSpend,
    activeColor: AppColors.primaryBlue,
    onChanged: (v) => setState(() => totalSpend = v.toString()),
  );

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _bottomNav(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _validateAndFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Finish',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => QuestionnaireScreen2(
                    fullName: widget.fullName,
                    studentId: widget.studentId,
                    registrationDate: widget.registrationDate,
                  ),
                ),
              );
            },
            child: const Text('Go Back', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
