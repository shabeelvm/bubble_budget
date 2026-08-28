import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/db_service.dart';
import '../services/settings_service.dart';

enum ReportPeriod { monthly, yearly }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DBService _dbService = DBService();
  final SettingsService _settings = SettingsService();
  
  ReportPeriod _selectedPeriod = ReportPeriod.monthly;
  DateTime _focusedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildPeriodToggle(),
          _buildDateSelector(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _selectedPeriod == ReportPeriod.monthly 
                ? _buildMonthlyReport() 
                : _buildYearlyReport(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton('Monthly', ReportPeriod.monthly),
          _buildToggleButton('Yearly', ReportPeriod.yearly),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, ReportPeriod period) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = period),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    final label = _selectedPeriod == ReportPeriod.monthly 
        ? DateFormat('MMMM yyyy').format(_focusedDate)
        : DateFormat('yyyy').format(_focusedDate);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.blueAccent),
            onPressed: () => _adjustDate(-1),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.blueAccent),
            onPressed: () => _adjustDate(1),
          ),
        ],
      ),
    );
  }

  void _adjustDate(int delta) {
    setState(() {
      if (_selectedPeriod == ReportPeriod.monthly) {
        _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + delta);
      } else {
        _focusedDate = DateTime(_focusedDate.year + delta);
      }
    });
  }

  Widget _buildMonthlyReport() {
    return FutureBuilder(
      future: Future.wait([
        _dbService.getCategorySpendingForMonth(_focusedDate.year, _focusedDate.month),
        _dbService.getDailySpendingForMonth(_focusedDate.year, _focusedDate.month),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final categoryData = snapshot.data![0] as List<Map<String, dynamic>>;
        final dailyData = snapshot.data![1] as Map<int, double>;

        final totalSpent = categoryData.fold<double>(0, (sum, item) => sum + (item['total'] as double));
        final daysInMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 0).day;
        final dailyAvg = totalSpent / (DateTime.now().month == _focusedDate.month ? DateTime.now().day : daysInMonth);

        return Column(
          children: [
            _buildKPIs([
              _KPI(label: 'Total Spent', value: '${_settings.currencySymbol}${totalSpent.toStringAsFixed(0)}'),
              _KPI(label: 'Daily Avg', value: '${_settings.currencySymbol}${dailyAvg.toStringAsFixed(0)}'),
              _KPI(label: 'Top Cat', value: categoryData.isNotEmpty ? categoryData[0]['category_name'] : '-'),
            ]),
            const SizedBox(height: 24),
            _buildBarChart(dailyData, daysInMonth, 'Daily Spending'),
            const SizedBox(height: 24),
            _buildCategoryBreakdown(categoryData),
          ],
        );
      },
    );
  }

  Widget _buildYearlyReport() {
    return FutureBuilder(
      future: Future.wait([
        _dbService.getCategorySpendingForYear(_focusedDate.year),
        _dbService.getMonthlySpendingForYear(_focusedDate.year),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final categoryData = snapshot.data![0] as List<Map<String, dynamic>>;
        final monthlyData = snapshot.data![1] as Map<int, double>;

        final totalSpent = categoryData.fold<double>(0, (sum, item) => sum + (item['total'] as double));
        final monthlyAvg = totalSpent / 12;

        return Column(
          children: [
            _buildKPIs([
              _KPI(label: 'Annual Total', value: '${_settings.currencySymbol}${totalSpent.toStringAsFixed(0)}'),
              _KPI(label: 'Monthly Avg', value: '${_settings.currencySymbol}${monthlyAvg.toStringAsFixed(0)}'),
              _KPI(label: 'Top Cat', value: categoryData.isNotEmpty ? categoryData[0]['category_name'] : '-'),
            ]),
            const SizedBox(height: 24),
            _buildBarChart(monthlyData, 12, 'Monthly Trend'),
            const SizedBox(height: 24),
            _buildCategoryBreakdown(categoryData),
          ],
        );
      },
    );
  }

  Widget _buildKPIs(List<_KPI> kpis) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: kpis.map((kpi) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(kpi.label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              Text(kpi.value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildBarChart(Map<int, double> data, int itemCount, String title) {
    final maxVal = data.values.isEmpty ? 1.0 : data.values.reduce((a, b) => a > b ? a : b);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(itemCount, (index) {
                final val = data[index + 1] ?? 0.0;
                final heightFactor = val / (maxVal == 0 ? 1 : maxVal);
                
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    height: (heightFactor * 100).clamp(2.0, 100.0),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withAlpha(val == 0 ? 30 : 180),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(List<Map<String, dynamic>> categoryData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category Breakdown', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...categoryData.map((cat) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: Color(int.parse(cat['color_hex'], radix: 16)),
              shape: BoxShape.circle,
            ),
          ),
          title: Text(cat['category_name'], style: const TextStyle(color: Colors.white)),
          subtitle: Text('${cat['count']} transactions', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          trailing: Text(
            '${_settings.currencySymbol}${cat['total'].toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        )),
      ],
    );
  }
}

class _KPI {
  final String label;
  final String value;
  _KPI({required this.label, required this.value});
}
