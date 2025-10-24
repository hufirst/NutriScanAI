import 'package:flutter/material.dart';
import '../../models/ratio_data.dart';
import '../theme/app_theme.dart';

/// Widget to display nutrition ratio with Korean text labels
///
/// Format: "탄60% 단30% 지20%"
///
/// Labels are bold, gray, and large
/// Numbers are colored based on WHO recommended ratios:
/// - Red: above recommended ratio
/// - Blue: below recommended ratio
/// - Default: within acceptable range
class RatioDisplay extends StatelessWidget {
  final RatioData ratio;
  final double fontSize;
  final bool showPercentSign;

  // WHO recommended ratios (as percentages)
  static const int _recommendedCarbRatio = 50;
  static const int _recommendedProteinRatio = 30;
  static const int _recommendedFatRatio = 20;

  const RatioDisplay({
    super.key,
    required this.ratio,
    this.fontSize = 20,
    this.showPercentSign = false,
  });

  @override
  Widget build(BuildContext context) {
    final percentSign = showPercentSign ? '%' : '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRatioItem('탄', ratio.carbRatio, _recommendedCarbRatio, percentSign),
        const SizedBox(width: 12),
        _buildRatioItem('단', ratio.proteinRatio, _recommendedProteinRatio, percentSign),
        const SizedBox(width: 12),
        _buildRatioItem('지', ratio.fatRatio, _recommendedFatRatio, percentSign),
      ],
    );
  }

  /// Determines color based on comparison with recommended ratio
  Color _getColorForValue(int value, int recommendedValue) {
    if (value > recommendedValue) {
      return Colors.red; // Above recommended
    } else if (value < recommendedValue) {
      return Colors.blue; // Below recommended
    } else {
      return AppTheme.ratioNumberStyle.color ?? Colors.black; // Exactly at recommended
    }
  }

  Widget _buildRatioItem(String label, int value, int recommendedValue, String suffix) {
    final color = _getColorForValue(value, recommendedValue);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label ('탄', '단', '지') - bold, gray, large
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize * 1.4, // 더 크게
            fontWeight: FontWeight.bold, // 굵게
            color: Colors.grey[700], // 회색
          ),
        ),
        const SizedBox(width: 4),
        // Number with colored text
        Text(
          '$value',
          style: AppTheme.ratioNumberStyle.copyWith(
            fontSize: fontSize,
            color: color,
          ),
        ),
        // Percent sign in smaller black text
        Text(
          '%',
          style: AppTheme.ratioNumberStyle.copyWith(
            fontSize: fontSize * 0.7, // 70% of number size
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
