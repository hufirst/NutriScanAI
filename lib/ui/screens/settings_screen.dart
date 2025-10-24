import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../models/user_profile.dart';
import '../../services/user_profile_service.dart';
import '../../providers/scan_provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

/// Settings screen for user profile management
///
/// Allows users to input personal information for personalized
/// health recommendations while minimizing privacy concerns:
/// - Gender, birth year/month (not exact birthdate)
/// - Height, weight (for BMI calculation)
/// - Activity level, health goal
/// - Dietary restrictions, health conditions (optional)
class SettingsScreen extends StatefulWidget {
  final bool isFirstSetup;

  const SettingsScreen({
    super.key,
    this.isFirstSetup = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userProfileService = UserProfileService();
  bool _isLoading = true;
  bool _isSaving = false;

  // Form controllers
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  // Form values
  String? _gender;
  int? _birthYear;
  int? _birthMonth;
  String? _activityLevel;
  String? _healthGoal;
  String? _dietaryRestriction;
  String? _healthCondition;

  // Calculated values (read-only)
  double? _bmi;
  double? _bmr;
  double? _tdee;
  double? _targetCalories;
  double? _recommendedProtein;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _userProfileService.initialize();
    await _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final profile = await _userProfileService.loadProfile();

      setState(() {
        _gender = profile.gender;
        _birthYear = profile.birthYear;
        _birthMonth = profile.birthMonth;
        _heightController.text = profile.heightCm?.toStringAsFixed(1) ?? '';
        _weightController.text = profile.weightKg?.toStringAsFixed(1) ?? '';
        _activityLevel = profile.activityLevel;
        _healthGoal = profile.healthGoal;
        _dietaryRestriction = profile.dietaryRestriction ?? 'none';
        _healthCondition = profile.healthCondition ?? 'none';

        // Update calculated values
        _updateCalculatedValues(profile);
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateCalculatedValues(UserProfile profile) {
    setState(() {
      _bmi = profile.bmi;
      _bmr = profile.bmr;
      _tdee = profile.tdee;
      _targetCalories = profile.targetCalories;
      _recommendedProtein = profile.recommendedProteinG;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profile = UserProfile(
        gender: _gender,
        birthYear: _birthYear,
        birthMonth: _birthMonth,
        heightCm: double.tryParse(_heightController.text),
        weightKg: double.tryParse(_weightController.text),
        activityLevel: _activityLevel,
        healthGoal: _healthGoal,
        dietaryRestriction: _dietaryRestriction,
        healthCondition: _healthCondition,
      );

      final success = await _userProfileService.saveProfile(profile);

      if (success && mounted) {
        // Update calculated values
        _updateCalculatedValues(profile);

        // 첫 설정인 경우 홈 화면으로 이동
        if (widget.isFirstSetup) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('프로필이 저장되었습니다!'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프로필 저장에 실패했습니다.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// 모든 스캔 기록 삭제 (확인 후 진행)
  Future<void> _deleteAllScanData() async {
    // 확인 대화상자 표시
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모든 스캔 기록 삭제'),
        content: const Text(
          '모든 스캔 기록과 이미지를 삭제하시겠습니까?\n\n'
          '이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    // 사용자가 취소한 경우
    if (confirmed != true || !mounted) return;

    try {
      // ScanProvider를 통해 데이터베이스 기록 삭제
      final scanProvider = context.read<ScanProvider>();
      await scanProvider.clearHistory();

      // 이미지 파일 삭제
      final appDir = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${appDir.path}/images');
      if (await imageDir.exists()) {
        await imageDir.delete(recursive: true);
        debugPrint('✅ Deleted all scan images');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모든 스캔 기록이 삭제되었습니다'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error deleting scan data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 실패: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.isFirstSetup ? '초기 설정' : '설정'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.userBubbleTextColor,
        automaticallyImplyLeading: !widget.isFirstSetup, // 첫 설정 시 뒤로가기 버튼 숨김
        actions: [
          if (!_isLoading)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppTheme.userBubbleTextColor,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveProfile,
              tooltip: '저장',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    _buildInfoBanner(),
                    const SizedBox(height: 24),

                    // Basic Information Section
                    _buildSectionHeader('기본 정보', Icons.person),
                    const SizedBox(height: 12),
                    _buildGenderField(),
                    const SizedBox(height: 16),
                    _buildBirthYearField(),
                    const SizedBox(height: 16),
                    _buildBirthMonthField(),
                    const SizedBox(height: 24),

                    // Physical Measurements Section
                    _buildSectionHeader('신체 정보', Icons.straighten),
                    const SizedBox(height: 12),
                    _buildHeightField(),
                    const SizedBox(height: 16),
                    _buildWeightField(),
                    const SizedBox(height: 16),
                    if (_bmi != null) _buildBMICard(),
                    const SizedBox(height: 24),

                    // Lifestyle Section
                    _buildSectionHeader('생활 습관', Icons.directions_run),
                    const SizedBox(height: 12),
                    _buildActivityLevelField(),
                    const SizedBox(height: 16),
                    _buildHealthGoalField(),
                    const SizedBox(height: 16),
                    if (_tdee != null || _targetCalories != null) _buildCaloriesCard(),
                    const SizedBox(height: 24),

                    // Health Management Section
                    _buildSectionHeader('건강 관리', Icons.favorite),
                    const SizedBox(height: 12),
                    _buildDietaryRestrictionField(),
                    const SizedBox(height: 16),
                    _buildHealthConditionField(),
                    const SizedBox(height: 32),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: AppTheme.userBubbleTextColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: AppTheme.userBubbleTextColor,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                '저장',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Delete all scan data button
                    _buildDeleteDataSection(),

                    const SizedBox(height: 16),

                    // Privacy notice
                    _buildPrivacyNotice(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDeleteDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('데이터 관리', Icons.delete_outline),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: AppTheme.errorColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '위험 영역',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '모든 스캔 기록과 저장된 이미지가 영구적으로 삭제됩니다. '
                '이 작업은 되돌릴 수 없습니다.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _deleteAllScanData,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('모든 스캔 기록 삭제'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: BorderSide(color: AppTheme.errorColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryDark.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AppTheme.primaryDark,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '사용자 정보를 입력하면 개인화된 건강 조언을 받을 수 있습니다.',
              style: TextStyle(
                color: AppTheme.userBubbleTextColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryDark, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildGenderField() {
    return DropdownButtonFormField<String>(
      value: _gender,
      decoration: const InputDecoration(
        labelText: '성별 *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person),
      ),
      items: const [
        DropdownMenuItem(value: 'male', child: Text('남성')),
        DropdownMenuItem(value: 'female', child: Text('여성')),
        DropdownMenuItem(value: 'other', child: Text('기타')),
      ],
      onChanged: (value) => setState(() => _gender = value),
      validator: (value) => value == null ? '성별을 선택해주세요' : null,
    );
  }

  Widget _buildBirthYearField() {
    final currentYear = DateTime.now().year;
    final years = List.generate(100, (index) => currentYear - index);

    return DropdownButtonFormField<int>(
      value: _birthYear,
      decoration: const InputDecoration(
        labelText: '생년 *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.calendar_today),
      ),
      items: years
          .map((year) => DropdownMenuItem(
                value: year,
                child: Text('$year년'),
              ))
          .toList(),
      onChanged: (value) => setState(() => _birthYear = value),
      validator: (value) => value == null ? '생년을 선택해주세요' : null,
    );
  }

  Widget _buildBirthMonthField() {
    return DropdownButtonFormField<int>(
      value: _birthMonth,
      decoration: const InputDecoration(
        labelText: '생월 *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.calendar_month),
      ),
      items: List.generate(12, (index) => index + 1)
          .map((month) => DropdownMenuItem(
                value: month,
                child: Text('$month월'),
              ))
          .toList(),
      onChanged: (value) => setState(() => _birthMonth = value),
      validator: (value) => value == null ? '생월을 선택해주세요' : null,
    );
  }

  Widget _buildHeightField() {
    return TextFormField(
      controller: _heightController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: const InputDecoration(
        labelText: '키 (cm) *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.height),
        suffixText: 'cm',
        hintText: '예: 175.0',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return '키를 입력해주세요';
        final height = double.tryParse(value);
        if (height == null) return '유효한 숫자를 입력해주세요';
        if (height < 50 || height > 250) return '유효한 범위(50-250cm)를 입력해주세요';
        return null;
      },
      onChanged: (value) {
        // Recalculate BMI on change
        final profile = UserProfile(
          gender: _gender,
          birthYear: _birthYear,
          birthMonth: _birthMonth,
          heightCm: double.tryParse(_heightController.text),
          weightKg: double.tryParse(_weightController.text),
          activityLevel: _activityLevel,
          healthGoal: _healthGoal,
          dietaryRestriction: _dietaryRestriction,
          healthCondition: _healthCondition,
        );
        _updateCalculatedValues(profile);
      },
    );
  }

  Widget _buildWeightField() {
    return TextFormField(
      controller: _weightController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: const InputDecoration(
        labelText: '몸무게 (kg) *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.monitor_weight),
        suffixText: 'kg',
        hintText: '예: 70.0',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return '몸무게를 입력해주세요';
        final weight = double.tryParse(value);
        if (weight == null) return '유효한 숫자를 입력해주세요';
        if (weight < 20 || weight > 300) return '유효한 범위(20-300kg)를 입력해주세요';
        return null;
      },
      onChanged: (value) {
        // Recalculate BMI on change
        final profile = UserProfile(
          gender: _gender,
          birthYear: _birthYear,
          birthMonth: _birthMonth,
          heightCm: double.tryParse(_heightController.text),
          weightKg: double.tryParse(_weightController.text),
          activityLevel: _activityLevel,
          healthGoal: _healthGoal,
          dietaryRestriction: _dietaryRestriction,
          healthCondition: _healthCondition,
        );
        _updateCalculatedValues(profile);
      },
    );
  }

  Widget _buildBMICard() {
    if (_bmi == null) return const SizedBox.shrink();

    final profile = UserProfile(
      gender: _gender,
      birthYear: _birthYear,
      birthMonth: _birthMonth,
      heightCm: double.tryParse(_heightController.text),
      weightKg: double.tryParse(_weightController.text),
      activityLevel: _activityLevel,
      healthGoal: _healthGoal,
      dietaryRestriction: _dietaryRestriction,
      healthCondition: _healthCondition,
    );

    final bmiCategory = profile.bmiCategory ?? '';
    final bmiCategoryKorean = {
      'underweight': '저체중',
      'normal': '정상',
      'overweight': '과체중',
      'obese': '비만',
    };

    final bmiColor = {
      'underweight': Colors.blue,
      'normal': AppTheme.successColor,
      'overweight': Colors.orange,
      'obese': AppTheme.errorColor,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (bmiColor[bmiCategory] ?? Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (bmiColor[bmiCategory] ?? Colors.grey).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: bmiColor[bmiCategory],
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'BMI 계산 결과',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'BMI: ${_bmi!.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: bmiColor[bmiCategory],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: bmiColor[bmiCategory],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  bmiCategoryKorean[bmiCategory] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLevelField() {
    return DropdownButtonFormField<String>(
      value: _activityLevel,
      decoration: const InputDecoration(
        labelText: '활동 수준',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.directions_run),
        hintText: '선택 (권장)',
      ),
      items: const [
        DropdownMenuItem(value: 'sedentary', child: Text('앉아서 생활 (운동 거의 안함)')),
        DropdownMenuItem(value: 'light', child: Text('가벼운 활동 (주 1-3회 운동)')),
        DropdownMenuItem(value: 'moderate', child: Text('보통 활동 (주 3-5회 운동)')),
        DropdownMenuItem(value: 'active', child: Text('활발한 활동 (주 6-7회 운동)')),
        DropdownMenuItem(value: 'very_active', child: Text('매우 활발 (하루 2회 운동)')),
      ],
      onChanged: (value) {
        setState(() => _activityLevel = value);
        // Recalculate TDEE
        final profile = UserProfile(
          gender: _gender,
          birthYear: _birthYear,
          birthMonth: _birthMonth,
          heightCm: double.tryParse(_heightController.text),
          weightKg: double.tryParse(_weightController.text),
          activityLevel: value,
          healthGoal: _healthGoal,
          dietaryRestriction: _dietaryRestriction,
          healthCondition: _healthCondition,
        );
        _updateCalculatedValues(profile);
      },
    );
  }

  Widget _buildHealthGoalField() {
    return DropdownButtonFormField<String>(
      value: _healthGoal,
      decoration: const InputDecoration(
        labelText: '건강 목표',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.flag),
        hintText: '선택 (권장)',
      ),
      items: const [
        DropdownMenuItem(value: 'lose', child: Text('체중 감량')),
        DropdownMenuItem(value: 'maintain', child: Text('체중 유지')),
        DropdownMenuItem(value: 'gain', child: Text('체중 증량')),
        DropdownMenuItem(value: 'muscle', child: Text('근육 증가')),
        DropdownMenuItem(value: 'health', child: Text('건강 유지')),
      ],
      onChanged: (value) {
        setState(() => _healthGoal = value);
        // Recalculate target calories
        final profile = UserProfile(
          gender: _gender,
          birthYear: _birthYear,
          birthMonth: _birthMonth,
          heightCm: double.tryParse(_heightController.text),
          weightKg: double.tryParse(_weightController.text),
          activityLevel: _activityLevel,
          healthGoal: value,
          dietaryRestriction: _dietaryRestriction,
          healthCondition: _healthCondition,
        );
        _updateCalculatedValues(profile);
      },
    );
  }

  Widget _buildCaloriesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryDark.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department,
                color: AppTheme.primaryDark,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '1일 권장 칼로리',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_bmr != null)
            _buildCalorieRow('기초 대사량 (BMR)', _bmr!),
          if (_tdee != null)
            _buildCalorieRow('활동 대사량 (TDEE)', _tdee!),
          if (_targetCalories != null)
            _buildCalorieRow('목표 칼로리', _targetCalories!, highlight: true),
          if (_recommendedProtein != null) ...[
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '권장 단백질',
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  '${_recommendedProtein!.toStringAsFixed(0)}g/일',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalorieRow(String label, double value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: highlight ? 15 : 14,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${value.toStringAsFixed(0)} kcal',
            style: TextStyle(
              fontSize: highlight ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: highlight ? AppTheme.primaryDark : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryRestrictionField() {
    return DropdownButtonFormField<String>(
      value: _dietaryRestriction,
      decoration: const InputDecoration(
        labelText: '식이 제한',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.restaurant),
        hintText: '선택사항',
      ),
      items: const [
        DropdownMenuItem(value: 'none', child: Text('없음')),
        DropdownMenuItem(value: 'vegetarian', child: Text('채식주의자')),
        DropdownMenuItem(value: 'vegan', child: Text('비건')),
        DropdownMenuItem(value: 'lactose', child: Text('유당불내증')),
        DropdownMenuItem(value: 'gluten', child: Text('글루텐 프리')),
      ],
      onChanged: (value) => setState(() => _dietaryRestriction = value),
    );
  }

  Widget _buildHealthConditionField() {
    return DropdownButtonFormField<String>(
      value: _healthCondition,
      decoration: const InputDecoration(
        labelText: '건강 상태',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.health_and_safety),
        hintText: '선택사항',
      ),
      items: const [
        DropdownMenuItem(value: 'none', child: Text('없음')),
        DropdownMenuItem(value: 'diabetes', child: Text('당뇨')),
        DropdownMenuItem(value: 'hypertension', child: Text('고혈압')),
        DropdownMenuItem(value: 'hyperlipidemia', child: Text('고지혈증')),
      ],
      onChanged: (value) => setState(() => _healthCondition = value),
    );
  }

  Widget _buildPrivacyNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.privacy_tip,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                '개인정보 보호',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '입력하신 정보는 기기 내에만 저장되며 외부로 전송되지 않습니다. '
            '개인화된 건강 조언 생성에만 사용됩니다.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
