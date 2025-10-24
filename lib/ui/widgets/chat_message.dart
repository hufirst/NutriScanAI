import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/scan_result.dart';
import '../../models/ratio_data.dart';
import '../../providers/scan_provider.dart';
import '../../utils/constants.dart';
import '../theme/app_theme.dart';
import 'ratio_display.dart';
import 'fullscreen_image_viewer.dart';

/// Chat message bubble widget
///
/// Displays scan results in KakaoTalk-style chat bubbles
/// - User messages (right-aligned, yellow background)
/// - AI messages (left-aligned, white background)
class ChatMessage extends StatelessWidget {
  final ScanResult scanResult;
  final bool isUser;
  final int messageIndex; // For alternating character avatars

  const ChatMessage({
    super.key,
    required this.scanResult,
    this.isUser = false,
    this.messageIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _buildAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // User message: Show image thumbnail
                if (isUser)
                  _buildUserImageThumbnail(context)
                else
                  // AI message: Show ratio and details
                  Container(
                    padding: const EdgeInsets.all(AppConstants.chatBubblePadding),
                    decoration: AppTheme.aiBubbleDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product name (최상단, 필수 표시)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                scanResult.productName ?? '식별되지 않은 음식',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: AppTheme.aiBubbleTextColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            // 낮은 신뢰도 표시
                            if (_isLowConfidence()) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '추정',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Calories with serving size
                        if (scanResult.calories != null)
                          Text(
                            '${scanResult.servingSize ?? '1회 제공량'}: ${scanResult.calories}kcal',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),

                        const SizedBox(height: 12),

                        // Ratio display with emojis
                        RatioDisplay(
                          ratio: RatioData(
                            carbRatio: scanResult.carbRatio,
                            proteinRatio: scanResult.proteinRatio,
                            fatRatio: scanResult.fatRatio,
                          ),
                        ),

                        // 영양성분 근거자료 (비율 계산 기준)
                        const SizedBox(height: 8),
                        _buildNutritionBasis(context),

                        // 추정 근거 설명
                        if (_isLowConfidence()) ...[
                          const SizedBox(height: 8),
                          Text(
                            '💡 이 음식의 일반적인 영양 정보를 기준으로 추정된 값입니다',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.orange.shade700,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ],

                        // BigQuery-powered nutrition advice
                        if (scanResult.nutritionAdvice != null && scanResult.nutritionAdvice!.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),
                              Text(
                                scanResult.nutritionAdvice!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.aiBubbleTextColor,
                                      height: 1.5,
                                    ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                // Timestamp
                Text(
                  _formatTime(scanResult.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textHint,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (isUser) {
      // User avatar: person emoji
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text(
            '👤',
            style: TextStyle(fontSize: 20),
          ),
        ),
      );
    } else {
      // AI avatar: alternating character faces (top 25% only)
      final isFemaleGenie = messageIndex % 2 == 0; // Even = female genie, Odd = male genie
      return ClipOval(
        child: Container(
          width: 40,
          height: 40,
          color: Colors.white,
          child: ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: 0.25, // Show only top 25% of the image
              child: Image.asset(
                isFemaleGenie
                    ? 'assets/images/genie_f.png'
                    : 'assets/images/genie_m.png',
                fit: BoxFit.cover,
                width: 40,
                height: 160, // 4x height to show top quarter
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildUserImageThumbnail(BuildContext context) {
    final hasImage = scanResult.imageUrl != null && File(scanResult.imageUrl!).existsSync();

    return GestureDetector(
      onTap: hasImage
          ? () {
              // 전체 화면 이미지 뷰어 열기
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => FullscreenImageViewer(
                    imagePath: scanResult.imageUrl!,
                  ),
                  fullscreenDialog: true,
                ),
              );
            }
          : null,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 200, // KakaoTalk-style thumbnail size
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: hasImage
              ? Image.file(
                  File(scanResult.imageUrl!),
                  fit: BoxFit.cover,
                )
              : Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 48,
                      color: Colors.grey,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return DateFormat('HH:mm').format(timestamp);
    } else {
      return DateFormat('yyyy/MM/dd HH:mm').format(timestamp);
    }
  }

  /// 낮은 신뢰도 데이터 확인 (신뢰도 < 0.85)
  bool _isLowConfidence() {
    const threshold = 0.85;

    return (scanResult.productNameConfidence ?? 1.0) < threshold ||
           (scanResult.caloriesConfidence ?? 1.0) < threshold ||
           (scanResult.carbohydratesConfidence ?? 1.0) < threshold ||
           (scanResult.proteinConfidence ?? 1.0) < threshold ||
           (scanResult.fatConfidence ?? 1.0) < threshold;
  }

  /// 영양성분 근거자료 표시 (비율 계산에 사용된 값들)
  Widget _buildNutritionBasis(BuildContext context) {
    final nutrients = <String>[];

    // 탄수화물
    if (scanResult.carbohydratesG != null) {
      nutrients.add('탄수화물 ${scanResult.carbohydratesG}g');
    }

    // 당류
    if (scanResult.sugarsG != null) {
      nutrients.add('당류 ${scanResult.sugarsG}g');
    }

    // 단백질
    if (scanResult.proteinG != null) {
      nutrients.add('단백질 ${scanResult.proteinG}g');
    }

    // 지방
    if (scanResult.fatG != null) {
      nutrients.add('지방 ${scanResult.fatG}g');
    }

    // 포화지방
    if (scanResult.saturatedFatG != null) {
      nutrients.add('포화지방 ${scanResult.saturatedFatG}g');
    }

    // 트랜스지방
    if (scanResult.transFatG != null) {
      nutrients.add('트랜스지방 ${scanResult.transFatG}g');
    }

    // 나트륨
    if (scanResult.sodiumMg != null) {
      nutrients.add('나트륨 ${scanResult.sodiumMg}mg');
    }

    if (nutrients.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      nutrients.join(', '),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontSize: 11,
          ),
    );
  }
}
