import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/scan_provider.dart';
import 'providers/history_provider.dart';
import 'providers/settings_provider.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'services/user_profile_service.dart';

/// TanDanGenie - 영양 비율 스캔 앱
///
/// Main entry point for the application
void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Warning: .env file not found or failed to load: $e');
    debugPrint('Make sure to create a .env file with your API keys before running the app');
  }

  runApp(const TanDanGenieApp());
}

class TanDanGenieApp extends StatelessWidget {
  const TanDanGenieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScanProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp(
        title: 'TanDanGenie',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        // Localization 설정
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ko', 'KR'), // 한국어
          Locale('en', 'US'), // 영어
        ],
        locale: const Locale('ko', 'KR'), // 기본 로케일
        home: const InitialRouteScreen(),
      ),
    );
  }
}

/// Initial route screen that checks user profile and redirects accordingly
class InitialRouteScreen extends StatefulWidget {
  const InitialRouteScreen({super.key});

  @override
  State<InitialRouteScreen> createState() => _InitialRouteScreenState();
}

class _InitialRouteScreenState extends State<InitialRouteScreen> {
  final UserProfileService _profileService = UserProfileService();
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkProfileAndNavigate();
  }

  Future<void> _checkProfileAndNavigate() async {
    try {
      // Initialize profile service
      await _profileService.initialize();

      // Load user profile
      final profile = await _profileService.loadProfile();

      // Check if profile is complete (basic fields required)
      if (!profile.isBasicComplete) {
        // Navigate to settings screen for first-time setup
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const SettingsScreen(isFirstSetup: true),
            ),
          );
        }
      } else {
        // Navigate to home screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking profile: $e');
      // On error, go to home screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show splash screen while checking
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Center(
                child: Text(
                  '🥖🍗🥑',
                  style: TextStyle(fontSize: 48),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // App title
            const Text(
              'TanDanGenie',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '영양 비율 스캔 앱',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 48),
            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder home screen (REPLACED by HomeScreen in Phase 3)
///
/// This will be replaced with actual chat UI in Phase 3 (User Story 1)
class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TanDanGenie'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo placeholder
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(60),
                ),
                child: const Center(
                  child: Text(
                    '🥖🍗🥑',
                    style: TextStyle(fontSize: 48),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // App title
              Text(
                'TanDanGenie',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                '영양 비율 스캔 앱',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 48),

              // Phase 2 completion notice
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppTheme.successColor),
                          const SizedBox(width: 8),
                          Text(
                            'Phase 2: Foundational 완료',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildCheckItem('✅ SQLite Database'),
                      _buildCheckItem('✅ Data Models (4개)'),
                      _buildCheckItem('✅ Gemini Service (2.0-flash)'),
                      _buildCheckItem('✅ Validation Pipeline (5단계)'),
                      _buildCheckItem('✅ Providers (3개)'),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        '다음 단계: Phase 3 - User Story 1 구현',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '카메라 UI, 채팅 화면, 스캔 기능',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textHint,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Provider status check
              Consumer3<ScanProvider, HistoryProvider, SettingsProvider>(
                builder: (context, scanProvider, historyProvider,
                    settingsProvider, child) {
                  return Text(
                    'Providers: ${scanProvider.isScanning ? "Scanning" : "Ready"} | '
                    'History: ${historyProvider.scanHistory.length} scans | '
                    'Settings: ${settingsProvider.settings.length} loaded',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textHint,
                        ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }
}
