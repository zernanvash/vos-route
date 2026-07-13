import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'services/timezone_service.dart';
import 'providers/auth_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/action_queue_provider.dart';
import 'providers/gps_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/sync_log_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/dispatch_plans_screen.dart';
import 'screens/stops_list_screen.dart';
import 'screens/stop_detail_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/trip_photos_screen.dart';
import 'screens/history_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/settings_screen.dart';
import 'db/app_database.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'core/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // 1. Initialize DB singleton and run migrations
  final db = AppDatabase();
  await db.executor.ensureOpen(db);

  // 2. Initialize api client primitives
  await ApiService().init();

  // 3. Load business settings cache (reconciles or falls back safely)
  await TimezoneService().load();

  runApp(const VOSRouteApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'vosroute',
);

class VOSRouteApp extends StatelessWidget {
  const VOSRouteApp({super.key});

  static void _wireNotifications() {
    NotificationService().setNavigatorKey(navigatorKey);
  }

  @override
  Widget build(BuildContext context) {
    _wireNotifications();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => ActionQueueProvider()..init()),
        ChangeNotifierProvider(create: (_) => GpsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'VOSRoute',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            home: const AuthGate(),
            onGenerateRoute: _onGenerateRoute,
          );
        },
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.stopDetail:
        return MaterialPageRoute(
          builder: (_) => StopDetailScreen(stop: settings.arguments as Object),
        );
      case AppRoutes.budget:
        return MaterialPageRoute(builder: (_) => const BudgetScreen());
      case AppRoutes.tripPhotos:
        return MaterialPageRoute(builder: (_) => const TripPhotosScreen());
      case AppRoutes.history:
        return MaterialPageRoute(builder: (_) => const HistoryScreen());
      case AppRoutes.sos:
        return MaterialPageRoute(builder: (_) => const SosScreen());
      case AppRoutes.syncLog:
        return MaterialPageRoute(builder: (_) => const SyncLogScreen());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        return MaterialPageRoute(builder: (_) => const AuthGate());
    }
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const _SplashScreen();
        }
        if (!auth.isLoggedIn) {
          return LoginScreen(sessionExpired: auth.error != null);
        }
        return const MainShell();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A3FBD), Color(0xFF3B6EF0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                size: 44,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'VOSRoute',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Fleet Dispatch',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final PageController _pageController;
  int _lastSettledIndex = 0;
  final _screens = [
    const HomeScreen(),
    const DispatchPlansScreen(),
    const StopsListScreen(),
    const _MoreMenu(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final trip = context.read<TripProvider>();
      final gps = context.read<GpsProvider>();

      await BackgroundService().ensureInitialized();
      await trip.fetchAllCachedData();
      if (trip.activeTrip?.timeOfDispatch != null && !gps.isTracking) {
        gps.startTracking(trip.activeTrip!.id);
      }
      NotificationService().init();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    BackgroundService().stop();
    super.dispose();
  }

  void _syncPageIfNeeded(int targetIndex) {
    final currentPage = _pageController.page?.round();
    if (currentPage != null && currentPage != targetIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pageController.jumpToPage(targetIndex);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripProvider>();
    final currentIndex = trip.currentTabIndex;
    final cs = Theme.of(context).colorScheme;

    if (currentIndex != _lastSettledIndex) {
      _lastSettledIndex = currentIndex;
      _syncPageIfNeeded(currentIndex);
    }

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const PageScrollPhysics(),
        onPageChanged: (i) => trip.setTabIndex(i),
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (i) {
            trip.setTabIndex(i);
            _pageController.jumpToPage(i);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment_rounded),
              label: 'Plans',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt_rounded),
              label: 'Stops',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_rounded),
              selectedIcon: Icon(Icons.more_horiz_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// MORE MENU
// ────────────────────────────────────────────────────────────────────────────
class _MoreMenu extends StatelessWidget {
  const _MoreMenu();

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<ActionQueueProvider>();
    final pending = queue.pendingCount;
    final failed = queue.failedCount;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('More'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _syncStatusTile(context, pending, failed),
            const SizedBox(height: 8),
            _item(
              context,
              'Budget',
              Icons.account_balance_wallet_outlined,
              '/budget',
            ),
            _item(
              context,
              'Trip Photos',
              Icons.photo_camera_outlined,
              '/trip-photos',
            ),
            _item(context, 'Trip History', Icons.history_rounded, '/history'),
            Divider(color: cs.outlineVariant, height: 24),
            _item(
              context,
              'Emergency SOS',
              Icons.emergency_outlined,
              '/sos',
              color: AppColors.error,
            ),
            Divider(color: cs.outlineVariant, height: 24),
            _item(context, 'Settings', Icons.settings_outlined, '/settings'),
          ],
        ),
      ),
    );
  }

  Widget _syncStatusTile(BuildContext context, int pending, int failed) {
    final cs = Theme.of(context).colorScheme;
    final Color statusColor = failed > 0
        ? AppColors.error
        : pending > 0
        ? AppColors.warning
        : AppColors.success;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          failed > 0
              ? Icons.sync_problem_rounded
              : pending > 0
              ? Icons.sync_rounded
              : Icons.cloud_done_rounded,
          color: statusColor,
        ),
        title: Text(
          'Sync Status',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          pending > 0 || failed > 0
              ? '$pending pending, $failed failed'
              : 'All synced',
          style: TextStyle(color: statusColor, fontSize: 13),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
        onTap: () => Navigator.pushNamed(context, '/sync-log'),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    String label,
    IconData icon,
    String route, {
    Color? color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: color != null ? color.withValues(alpha: 0.08) : cs.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color ?? cs.onSurfaceVariant),
        title: Text(
          label,
          style: TextStyle(
            color: color ?? cs.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
        onTap: () => Navigator.pushNamed(context, route),
      ),
    );
  }
}
