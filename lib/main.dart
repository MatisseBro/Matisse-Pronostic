import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/predictions_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/results_screen.dart';
import 'screens/standings_screen.dart';
import 'services/cache_service.dart';
import 'viewmodels/auth_view_model.dart';
import 'viewmodels/matches_view_model.dart';
import 'services/mqtt_service.dart';
import 'viewmodels/mqtt_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  String? firebaseError;
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    firebaseError = e.toString();
  }

  if (firebaseError != null) {
    runApp(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              const Text('Erreur Firebase',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red)),
              const SizedBox(height: 16),
              SelectableText(firebaseError,
                  style:
                      const TextStyle(fontSize: 12, fontFamily: 'monospace')),
            ],
          ),
        ),
      ),
    ));
    return;
  }

  try {
    await CacheService.init();
  } catch (_) {}
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Matimatch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardTheme(
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          side: BorderSide.none,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 16,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          elevation: 0,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: SegmentedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: const Size(0, 48),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          shape: StadiumBorder(),
        ),
      ),
      home: authState.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const LoginScreen(),
        data: (user) => user != null ? const HomePage() : const LoginScreen(),
      ),
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const List<Widget> _pages = [
    MatchesScreen(),
    PredictionsScreen(),
    ResultsScreen(),
    StandingsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initMqtt());
  }

  Future<void> _initMqtt() async {
    final repo = ref.read(mqttRepositoryProvider);

    // Écouter l'état de connexion MQTT
    repo.stateStream.listen((s) {
      if (!mounted) return;
      ref.read(mqttConnectedProvider.notifier).state =
          s == MqttState.connected;
    });

    // Écouter le statut de l'objet (ONLINE / OFFLINE)
    repo.deviceStatusStream.listen((status) {
      if (!mounted) return;
      ref.read(deviceStatusProvider.notifier).state = status.trim();
    });

    await repo.connect();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(selectedTabProvider);

    return Scaffold(
      body: _pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) =>
            ref.read(selectedTabProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sports_soccer_outlined),
            selectedIcon: Icon(Icons.sports_soccer),
            label: 'Matchs',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline),
            selectedIcon: Icon(Icons.star),
            label: 'Pronostics',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Résultats',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Classements',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
