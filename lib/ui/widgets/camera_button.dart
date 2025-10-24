import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Floating camera button for nutrition label scanning
///
/// KakaoTalk-style yellow circular button with camera icon
class CameraButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const CameraButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: isLoading ? null : onPressed,
      backgroundColor: isLoading ? AppTheme.borderColor : AppTheme.primaryColor,
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.userBubbleTextColor),
              ),
            )
          : const Icon(
              Icons.camera_alt,
              color: AppTheme.userBubbleTextColor,
              size: 28,
            ),
    );
  }
}
