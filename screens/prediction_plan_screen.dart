import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../core/app_colors.dart';
import '../data/database/income_dao.dart';

class PredictionPlanScreen extends StatefulWidget {
  final String studentId;
  const PredictionPlanScreen({super.key, required this.studentId});

  @override
  State<PredictionPlanScreen> createState() => _PredictionPlanScreenState();
}

class _PredictionPlanScreenState extends State<PredictionPlanScreen> {
  final IncomeDao _incomeDao = IncomeDao();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FutureBuilder<Map<String, double>>(
        future: _incomeDao.getPredictedPlan(widget.studentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              (snapshot.data!['totalIncome'] ?? 0) <= 0) {
            return _buildNoDataState(context);
          }

          final data = snapshot.data!;
          final double total = data['totalIncome']!;

          return Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildPieChartCard(total, data),
                      const SizedBox(height: 30),

                      _buildCategoryItem(
                        "Essentials (50%)",
                        0.5,
                        data['essential']!,
                        const Color(0xFF6366F1),
                        Icons.shopping_bag,
                      ),

                      _buildCategoryItem(
                        "Academics (20%)",
                        0.2,
                        data['academic']!,
                        const Color(0xFF8B5CF6),
                        Icons.school,
                      ),

                      _buildCategoryItem(
                        "Leisure (20%)",
                        0.2,
                        data['leisure']!,
                        const Color(0xFFEC4899),
                        Icons.coffee,
                      ),

                      _buildCategoryItem(
                        "Other (10%)",
                        0.1,
                        data['other']!,
                        const Color(0xFFF59E0B),
                        Icons.more_horiz,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ================= PIE CHART =================

  Widget _buildPieChartCard(double total, Map<String, double> data) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Text(
            "Allocation Overview",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 55,
                    sections: [
                      PieChartSectionData(
                        value: data['essential']!,
                        color: const Color(0xFF6366F1),
                        radius: 20,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: data['academic']!,
                        color: const Color(0xFF8B5CF6),
                        radius: 20,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: data['leisure']!,
                        color: const Color(0xFFEC4899),
                        radius: 20,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: data['other']!,
                        color: const Color(0xFFF59E0B),
                        radius: 20,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),

                // CENTER TEXT
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Total",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      "Rs. ${total.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 🔥 LEGEND ROW
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _legendItem("Essentials", const Color(0xFF6366F1)),
              _legendItem("Academics", const Color(0xFF8B5CF6)),
              _legendItem("Leisure", const Color(0xFFEC4899)),
              _legendItem("Other", const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  // ================= CATEGORY CARD =================

  Widget _buildCategoryItem(
    String title,
    double percent,
    double amt,
    Color color,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(title)),
              Text("Rs. ${amt.toStringAsFixed(0)}"),
            ],
          ),
          const SizedBox(height: 10),
          LinearPercentIndicator(
            percent: percent,
            progressColor: color,
            backgroundColor: Colors.grey[200]!,
            lineHeight: 8,
            barRadius: const Radius.circular(10),
            animation: true,
          ),
        ],
      ),
    );
  }

  // ================= HEADER =================

  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        color: AppColors.primaryBlue,
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const Text(
              "Prediction Plan",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ================= NO DATA =================

  Widget _buildNoDataState(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        const Expanded(
          child: Center(
            child: Text(
              "Add income / Check balance to see plan",
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
