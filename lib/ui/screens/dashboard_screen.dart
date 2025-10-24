import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/daily_intake.dart';
import '../../models/scan_result.dart';
import '../../models/user_profile.dart';
import '../../services/daily_intake_service.dart';
import '../../services/storage_service.dart';
import '../../services/user_profile_service.dart';
import '../theme/app_theme.dart';
import '../../utils/constants.dart';

/// Dashboard screen showing daily nutrition intake summary
///
/// Displays:
/// - Date selector
/// - Total calories vs target (TDEE)
/// - Carb/Protein/Fat calories vs recommended
/// - List of foods eaten (editable)
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DailyIntakeService _dailyIntakeService = DailyIntakeService();
  final StorageService _storageService = StorageService();
  final UserProfileService _userProfileService = UserProfileService();

  DateTime _selectedDate = DateTime.now();
  DailyIntake? _dailyIntake;
  List<ScanResult> _scanResults = [];
  UserProfile _userProfile = UserProfile.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load user profile
      await _userProfileService.initialize();
      final profile = await _userProfileService.loadProfile();

      // Load daily intake for selected date
      final dateString = _formatDate(_selectedDate);
      final intake = await _dailyIntakeService.recalculateDailyIntake(dateString);

      // Load scan results for the date
      final scans = await _getScanResultsForDate(_selectedDate);

      setState(() {
        _userProfile = profile;
        _dailyIntake = intake;
        _scanResults = scans;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<List<ScanResult>> _getScanResultsForDate(DateTime date) async {
    final db = await _storageService.database;
    final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final startTimestamp = startOfDay.millisecondsSinceEpoch ~/ 1000;
    final endTimestamp = endOfDay.millisecondsSinceEpoch ~/ 1000;

    final results = await db.query(
      'scan_results',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [startTimestamp, endTimestamp],
      orderBy: 'timestamp ASC',
    );

    return results.map((map) => ScanResult.fromMap(map)).toList();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ko', 'KR'),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('일일 섭취 대시보드'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dailyIntake == null
              ? const Center(child: Text('데이터를 불러올 수 없습니다'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateSelector(),
                        const SizedBox(height: 24),
                        _buildCaloriesSummary(),
                        const SizedBox(height: 24),
                        _buildMacroBreakdown(),
                        const SizedBox(height: 24),
                        _buildFoodList(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildDateSelector() {
    final isToday = _formatDate(_selectedDate) == _formatDate(DateTime.now());
    final dateText = isToday
        ? '오늘 (${DateFormat('yyyy년 M월 d일').format(_selectedDate)})'
        : DateFormat('yyyy년 M월 d일').format(_selectedDate);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: _selectDate,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dateText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaloriesSummary() {
    final dailyIntake = _dailyIntake!;
    final targetCalories = (_userProfile.targetCalories ?? _userProfile.tdee ?? 2000).round();
    final percentage = dailyIntake.completionPercentage(targetCalories);
    final hasEstimated = dailyIntake.hasEstimatedData;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '전체 칼로리',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasEstimated)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '(추정)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${dailyIntake.totalCalories}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const Text(
                  ' / ',
                  style: TextStyle(fontSize: 20, color: Colors.grey),
                ),
                Text(
                  '$targetCalories kcal',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage > 100 ? Colors.red : AppTheme.primaryColor,
              ),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Text(
              '$percentage% 달성 ${percentage > 100 ? '(초과)' : ''}',
              style: TextStyle(
                fontSize: 14,
                color: percentage > 100 ? Colors.red : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBreakdown() {
    final dailyIntake = _dailyIntake!;
    final ratios = dailyIntake.macroRatios;

    // Calculate recommended calories based on user profile
    final targetCalories = (_userProfile.targetCalories ?? _userProfile.tdee ?? 2000).round();
    final recommendedRatios = _userProfile.recommendedMacroRatios;

    final recCarbCal = (targetCalories * ((recommendedRatios['carb'] ?? 40) / 100)).round();
    final recProteinCal = (targetCalories * ((recommendedRatios['protein'] ?? 30) / 100)).round();
    final recFatCal = (targetCalories * ((recommendedRatios['fat'] ?? 30) / 100)).round();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '탄단지 칼로리',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dailyIntake.formattedRatio,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            _buildMacroRow(
              '${AppConstants.carbEmoji} 탄수화물',
              dailyIntake.carbCalories,
              recCarbCal,
              Colors.orange,
            ),
            const SizedBox(height: 16),
            _buildMacroRow(
              '${AppConstants.proteinEmoji} 단백질',
              dailyIntake.proteinCalories,
              recProteinCal,
              Colors.red,
            ),
            const SizedBox(height: 16),
            _buildMacroRow(
              '${AppConstants.fatEmoji} 지방',
              dailyIntake.fatCalories,
              recFatCal,
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroRow(String label, int actual, int recommended, Color color) {
    final percentage = recommended > 0 ? ((actual / recommended) * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$actual / $recommended kcal',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (percentage / 100).clamp(0.0, 1.0),
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
        const SizedBox(height: 4),
        Text(
          '$percentage%',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildFoodList() {
    if (_scanResults.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.restaurant, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  '이 날짜에 스캔한 음식이 없습니다',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '오늘 먹은 음식',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_scanResults.length}건',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _scanResults.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final scan = _scanResults[index];
              return _buildFoodItem(scan);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItem(ScanResult scan) {
    final time = DateFormat('HH:mm').format(scan.timestamp);
    final foodName = scan.productName ?? '알 수 없는 음식';
    final servingSize = scan.servingSize ?? '-';
    final calories = scan.calories ?? 0;
    final hasLowConfidence = (scan.productNameConfidence ?? 1.0) < 0.85 ||
        (scan.caloriesConfidence ?? 1.0) < 0.85;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      onTap: () => _showEditDialog(scan),
      leading: CircleAvatar(
        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
        child: Text(
          time,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              foodName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (hasLowConfidence)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '(추정)',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        '${servingSize} • ${calories} kcal',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            scan.formattedRatio,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.edit,
            size: 18,
            color: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(ScanResult scan) async {
    final foodNameController = TextEditingController(text: scan.productName ?? '');
    final servingSizeController = TextEditingController(text: scan.servingSize ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('음식 정보 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: foodNameController,
              decoration: const InputDecoration(
                labelText: '음식명',
                hintText: '음식 이름을 입력하세요',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: servingSizeController,
              decoration: const InputDecoration(
                labelText: '제공량',
                hintText: '예: 100g, 1컵',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _updateScanResult(
        scan,
        foodNameController.text.trim(),
        servingSizeController.text.trim(),
      );
    }

    foodNameController.dispose();
    servingSizeController.dispose();
  }

  Future<void> _updateScanResult(ScanResult scan, String newFoodName, String newServingSize) async {
    try {
      // Update the scan result in database
      await _storageService.updateScanResult(
        scan.scanId,
        {
          'product_name': newFoodName.isEmpty ? null : newFoodName,
          'serving_size': newServingSize.isEmpty ? null : newServingSize,
        },
      );

      // Recalculate daily intake (in case food name affected confidence tracking)
      final dateString = _formatDate(_selectedDate);
      await _dailyIntakeService.recalculateDailyIntake(dateString);

      // Reload data to reflect changes
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('음식 정보가 수정되었습니다'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating scan result: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('수정 중 오류가 발생했습니다: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
