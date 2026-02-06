import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'utils/theme.dart';
import 'services/services.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Enable Firestore offline persistence with reasonable cache limit
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 50 * 1024 * 1024, // 50MB limit instead of unlimited
  );

  // Set preferred orientations
  // Note: Tablets (shortest side >= 600dp) can also use landscape;
  // this is enforced at runtime in ClassPulseApp after MediaQuery is available.
  // Default to portrait for initial launch.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runZonedGuarded(() {
    runApp(
      const ProviderScope(
        child: ClassPulseApp(),
      ),
    );
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack);
  });
}

class ClassPulseApp extends ConsumerWidget {
  const ClassPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'ClassPulse',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const _TabletOrientationUnlock(child: AppStartup()),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}

/// Unlocks landscape orientation on tablets (shortest side >= 600dp)
class _TabletOrientationUnlock extends StatefulWidget {
  final Widget child;
  const _TabletOrientationUnlock({required this.child});

  @override
  State<_TabletOrientationUnlock> createState() => _TabletOrientationUnlockState();
}

class _TabletOrientationUnlockState extends State<_TabletOrientationUnlock> {
  bool _orientationSet = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_orientationSet) {
      _orientationSet = true;
      final shortestSide = MediaQuery.of(context).size.shortestSide;
      if (shortestSide >= 600) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Checks if onboarding is complete before showing auth flow
class AppStartup extends StatefulWidget {
  const AppStartup({super.key});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  bool _isLoading = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

    // Fresh install - clear any stale auth (anonymous users, cached credentials)
    if (!onboardingComplete) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }
    }

    if (mounted) {
      setState(() {
        _showOnboarding = !onboardingComplete;
        _isLoading = false;
      });
    }
  }

  void _onOnboardingComplete() {
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SplashScreen();
    }

    if (_showOnboarding) {
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }

    return const AuthWrapper();
  }
}

/// Wrapper to handle authentication state
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        // Require proper phone authentication, not just any user
        // Anonymous users have no phone number and should be signed out
        if (user == null || user.phoneNumber == null || user.phoneNumber!.isEmpty) {
          // Sign out anonymous/invalid users to clear stale auth state
          if (user != null && (user.phoneNumber == null || user.phoneNumber!.isEmpty)) {
            FirebaseAuth.instance.signOut();
          }
          return const LoginScreen();
        }

        // Check if user has teacher record
        final teacherState = ref.watch(currentTeacherProvider);

        return teacherState.when(
          data: (teacher) {
            if (teacher == null) {
              // User logged in but not registered as teacher
              return const RegisterScreen();
            }
            return const DashboardScreen();
          },
          loading: () => const SplashScreen(),
          error: (error, stack) => _ErrorScreen(error: error.toString()),
        );
      },
      loading: () => const SplashScreen(),
      error: (error, stack) => _ErrorScreen(error: error.toString()),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;

  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Restart the app by navigating to splash
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  );
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
