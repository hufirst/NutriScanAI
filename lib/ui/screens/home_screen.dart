import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/scan_provider.dart';
import '../../services/camera_service.dart';
import '../../services/user_profile_service.dart';
import '../../models/user_profile.dart';
import '../widgets/camera_button.dart';
import '../widgets/chat_message.dart';
import '../theme/app_theme.dart';
import '../../utils/error_handler.dart';
import 'camera_screen.dart';
import 'settings_screen.dart';
import 'dashboard_screen.dart';

/// Main home screen with chat interface
///
/// Layout: Portrait 1:2 ratio
/// - Top 1/3: Fixed info area (logo, title)
/// - Bottom 2/3: Scrollable chat messages
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  final _userProfileService = UserProfileService();
  UserProfile _userProfile = UserProfile.empty();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    await _userProfileService.initialize();
    final profile = await _userProfileService.loadProfile();
    setState(() {
      _userProfile = profile;
    });
  }

  Future<void> _launchWHOUrl() async {
    final Uri url = Uri.parse('https://www.who.int/news-room/fact-sheets/detail/healthy-diet');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('웹페이지를 열 수 없습니다: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _handleScan() async {
    try {
      // Create new camera service for this scan
      final cameraService = CameraService();

      // Navigate to camera screen (camera will be initialized there)
      final imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(cameraService: cameraService),
        ),
      );

      // Dispose camera after use
      await cameraService.dispose();

      // If user cancelled, return
      if (imagePath == null || !mounted) return;

      // Process the image (common logic)
      await _processImage(imagePath);
    } catch (e) {
      debugPrint('Scan error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.formatUserMessage(e)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _handleImagePick() async {
    try {
      final ImagePicker picker = ImagePicker();

      // Pick image from gallery
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Optimize image quality
      );

      // If user cancelled, return
      if (image == null || !mounted) return;

      // Process the image (common logic)
      await _processImage(image.path);
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.formatUserMessage(e)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  /// Common image processing logic for both camera and gallery
  Future<void> _processImage(String imagePath) async {
    // Scan image using provider
    final scanProvider = context.read<ScanProvider>();
    final result = await scanProvider.scanImage(imagePath);

    if (result != null && mounted) {
      // Scroll to bottom to show new message
      _scrollToBottom();

      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('스캔 완료!'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // Use WidgetsBinding to ensure scroll happens after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
    // Reload profile when returning from settings
    await _loadUserProfile();
  }

  Future<void> _openDashboard() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DashboardScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topSectionHeight = screenHeight * 0.3;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top 1/3: Fixed info area
            Container(
              height: topSectionHeight,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  // Title with Dashboard and Settings buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Dashboard button (left)
                      IconButton(
                        icon: const Icon(Icons.dashboard, color: AppTheme.textPrimary),
                        onPressed: _openDashboard,
                        tooltip: '대시보드',
                      ),
                      // Title (50% larger)
                      Text(
                        '탄단지니',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      // Settings button (right)
                      IconButton(
                        icon: const Icon(Icons.settings, color: AppTheme.textPrimary),
                        onPressed: _openSettings,
                        tooltip: '설정',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Subtitle (50% larger)
                  Text(
                    '영양성분표를 촬영하면 탄단지 비율을 알려드려요',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // WHO Recommended Ratios with Characters (no background)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Left character (50% larger)
                      Image.asset(
                        'assets/images/character_left.png',
                        width: 75,
                        height: 98,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 12),
                      // Center content
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '추천 영양소 칼로리 비율',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                          ),
                          const SizedBox(height: 6),
                          _buildMacroRatios(),
                          const SizedBox(height: 6),
                          // Source link (50% larger)
                          _buildSourceLink(),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Right character (50% larger)
                      Image.asset(
                        'assets/images/character_right.png',
                        width: 75,
                        height: 98,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Divider
            const Divider(height: 1),

            // Bottom 2/3: Chat messages
            Expanded(
              flex: 2,
              child: Consumer<ScanProvider>(
                builder: (context, scanProvider, child) {
                  // Show loading indicator
                  if (scanProvider.isScanning) {
                    return _buildLoadingState(scanProvider.scanProgress);
                  }

                  // Show chat messages (empty state handled inside _buildChatList)
                  return _buildChatList(scanProvider);
                },
              ),
            ),
          ],
        ),
      ),

      // Floating action buttons (camera + image picker)
      floatingActionButton: Consumer<ScanProvider>(
        builder: (context, scanProvider, child) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Camera button
                FloatingActionButton(
                  heroTag: 'camera_button',
                  onPressed: scanProvider.isScanning ? null : _handleScan,
                  backgroundColor: scanProvider.isScanning
                      ? AppTheme.primaryColor.withOpacity(0.5)
                      : AppTheme.primaryColor,
                  child: scanProvider.isScanning
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(Icons.camera_alt, size: 28),
                ),
                const SizedBox(width: 16),
                // Image picker button
                FloatingActionButton(
                  heroTag: 'image_picker_button',
                  onPressed: scanProvider.isScanning ? null : _handleImagePick,
                  backgroundColor: scanProvider.isScanning
                      ? AppTheme.primaryColor.withOpacity(0.5)
                      : AppTheme.primaryColor,
                  child: const Icon(Icons.image, size: 28),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildMacroRatios() {
    final ratios = _userProfile.recommendedMacroRatios;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildRatioLabel('🥖', '탄수화물', '${ratios['carbs']}%'),
        const SizedBox(width: 12),
        _buildRatioLabel('🍗', '단백질', '${ratios['protein']}%'),
        const SizedBox(width: 12),
        _buildRatioLabel('🥑', '지방', '${ratios['fat']}%'),
      ],
    );
  }

  Widget _buildSourceLink() {
    final hasHealthGoal = _userProfile.healthGoal != null;
    final goalLabels = {
      'lose': '체중 감량',
      'maintain': '체중 유지',
      'gain': '체중 증량',
      'muscle': '근육 증가',
      'health': '건강 유지',
    };

    return InkWell(
      onTap: _launchWHOUrl,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hasHealthGoal
                ? '📌 ${goalLabels[_userProfile.healthGoal] ?? 'WHO 가이드라인'} 기준'
                : '📌 WHO 가이드라인',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              decoration: TextDecoration.underline,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.open_in_new,
            size: 14,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildRatioLabel(String emoji, String name, String percentage) {
    // 첫 글자 ('탄', '단', '지')와 나머지 부분 분리
    final firstChar = name.isNotEmpty ? name[0] : '';
    final restChars = name.length > 1 ? name.substring(1) : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: firstChar,
                style: const TextStyle(
                  fontSize: 16, // 더 크게 (기존 12 -> 16)
                  fontWeight: FontWeight.bold, // 굵게
                  color: Colors.black, // 검은색
                  fontFamily: 'Roboto', // 기본 폰트
                ),
              ),
              TextSpan(
                text: restChars,
                style: const TextStyle(
                  fontSize: 12, // 8 * 1.5 = 12
                  color: AppTheme.textSecondary,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
        ),
        Text(
          emoji,
          style: const TextStyle(fontSize: 21), // 14 * 1.5 = 21
        ),
        Text(
          percentage,
          style: const TextStyle(
            fontSize: 17, // 11 * 1.5 ≈ 17
            fontWeight: FontWeight.bold,
            color: Colors.black, // 노란색에서 검정색으로 변경
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            size: 64,
            color: AppTheme.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            '아래 버튼을 눌러\n영양성분표를 촬영해보세요',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(double progress) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: progress > 0 ? progress : null,
              strokeWidth: 6,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '분석 중...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            progress > 0
                ? '${(progress * 100).toInt()}% 완료'
                : '영양성분표를 읽고 있어요',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(ScanProvider scanProvider) {
    final history = scanProvider.scanHistory;

    // If loading history, show loading indicator
    if (scanProvider.isLoadingHistory && history.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // If no history, show empty state
    if (history.isEmpty) {
      return _buildEmptyState();
    }

    // Scroll to bottom after building the list
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && history.isNotEmpty) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      itemCount: history.length * 2, // Each scan has 2 messages (user image + AI response)
      reverse: false, // Normal order: oldest at top, newest at bottom
      itemBuilder: (context, index) {
        final scanIndex = index ~/ 2;
        final isUserMessage = index % 2 == 0; // Even indices = user image (sent first), Odd = AI response (comes after)

        // Reverse the order: history is stored newest-first, but we want to display oldest-first
        final result = history[history.length - 1 - scanIndex];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ChatMessage(
            scanResult: result,
            isUser: isUserMessage,
            messageIndex: scanIndex, // Pass scan index for alternating avatars
          ),
        );
      },
    );
  }
}
