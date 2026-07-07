import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/action_queue_provider.dart';
import 'providers/gps_provider.dart';
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
import 'theme/app_theme.dart';
import 'core/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }
  await ApiService().init();
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
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => ActionQueueProvider()..init()),
        ChangeNotifierProvider(create: (_) => GpsProvider()),
      ],
      child: MaterialApp(
        title: 'VOSRoute',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: AppTheme.dark,
        home: const AuthGate(),
        onGenerateRoute: _onGenerateRoute,
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
        if (!auth.isLoggedIn) {
          return const LoginScreen();
        }
        return const MainShell();
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _screens = [
    const HomeScreen(),
    const DispatchPlansScreen(),
    const StopsListScreen(),
    const _MoreMenu(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final trip = context.read<TripProvider>();
      final gps = context.read<GpsProvider>();
      await trip.fetchActiveTrip();
      await trip.fetchPendingPlans();
      if (trip.activeTrip?.timeOfDispatch != null && !gps.isTracking) {
        gps.startTracking(trip.activeTrip!.id);
      }
      NotificationService().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripProvider>();
    final currentIndex = trip.currentTabIndex;

    return Scaffold(
      body: _screens[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => trip.setTabIndex(i),
        backgroundColor: Colors.grey.shade900,
        selectedItemColor: Colors.blue.shade300,
        unselectedItemColor: Colors.grey.shade500,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Plans'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Stops'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            _item(context, 'Budget', Icons.account_balance_wallet, '/budget'),
            _item(context, 'Trip Photos', Icons.photo_camera, '/trip-photos'),
            _item(context, 'Trip History', Icons.history, '/history'),
            const Divider(color: Colors.grey, height: 24),
            _item(
              context,
              'Emergency SOS',
              Icons.warning,
              '/sos',
              color: Colors.red.shade700,
            ),
            const Divider(color: Colors.grey, height: 24),
            _item(context, 'Settings', Icons.settings, '/settings'),
          ],
        ),
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
    return Card(
      color: color != null
          ? color.withValues(alpha: 0.2)
          : Colors.grey.shade900,
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.grey.shade400),
        title: Text(
          label,
          style: TextStyle(
            color: color ?? Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade500),
        onTap: () => Navigator.pushNamed(context, route),
      ),
    );
  }
}
