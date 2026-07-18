import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/app_config.dart';
import 'providers/app_settings.dart';
import 'services/auth_service.dart';
import 'screens/main_shell.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'services/log_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LogService.init(); // Load if we should be recording
  await LogService.log('--- APP BOOTING ---');

  try {
    await AppConfig.load();
    await LogService.log('Config loaded');
    
    await NotificationService().init();
    await LogService.log('Notifications ready');

    await AppSettings.instance.loadFromPrefs();
    await LogService.log('Settings ready');
  } catch (e) {
    await LogService.error('Fatal startup error', e);
  }

  runApp(EGXApp());
}

class EGXApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final settings = AppSettings.instance;
        return MaterialApp(
          title: 'EGX Fair Value',
          debugShowCheckedModeBanner: false,

          // ── Theme ──────────────────────────────────────────────────────────
          themeMode: settings.themeSetting == 'phosphor'
              ? ThemeMode.dark
              : settings.themeMode,
          theme: _buildLightTheme(),
          darkTheme: settings.themeSetting == 'phosphor'
              ? _buildPhosphorTheme()
              : _buildDarkTheme(),

          // ── Locale / RTL ───────────────────────────────────────────────────
          locale: settings.locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          home: _AuthGate(),
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: false,
      primarySwatch: Colors.deepPurple,
      brightness: Brightness.light,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      cardColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF6A1B9A),
        unselectedItemColor: Colors.grey.shade500,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
      colorScheme: ColorScheme.light(
        primary: const Color(0xFF6A1B9A),
        secondary: const Color(0xFF9C27B0),
        surface: Colors.white,
        background: const Color(0xFFF5F5F5),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: false,
      primarySwatch: Colors.deepPurple,
      brightness: Brightness.dark,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2D2D44),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Colors.white70),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Colors.white70),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        selectedItemColor: Color(0xFFCE93D8),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFCE93D8),
        secondary: Color(0xFF9C27B0),
        surface: Color(0xFF1E1E1E),
        background: Color(0xFF121212),
      ),
    );
  }

  ThemeData _buildPhosphorTheme() {
    final phosphorGreen = const Color(0xFF89F200);
    final dimmerGreen = const Color(0xFF6CBD00);
    final darkBg = const Color(0xFF090D08);
    final darkCard = const Color(0xFF121A0F);

    return ThemeData(
      useMaterial3: false,
      primarySwatch: Colors.green,
      primaryColor: phosphorGreen,
      indicatorColor: phosphorGreen,
      brightness: Brightness.dark,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: darkBg,
      cardColor: darkCard,
      appBarTheme: AppBarTheme(
        backgroundColor: darkCard,
        foregroundColor: phosphorGreen,
        elevation: 0,
        iconTheme: IconThemeData(color: phosphorGreen),
        titleTextStyle: TextStyle(
          color: phosphorGreen,
          fontWeight: FontWeight.bold,
          fontSize: 20,
          fontFamily: 'Roboto',
        ),
      ),
      iconTheme: IconThemeData(color: phosphorGreen),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: phosphorGreen),
        bodyMedium: TextStyle(color: dimmerGreen),
        bodySmall: TextStyle(color: dimmerGreen.withOpacity(0.7)),
        titleMedium: TextStyle(color: phosphorGreen, fontWeight: FontWeight.bold),
        titleSmall: TextStyle(color: dimmerGreen, fontWeight: FontWeight.w500),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkCard,
        selectedItemColor: phosphorGreen,
        unselectedItemColor: dimmerGreen.withOpacity(0.4),
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
      colorScheme: ColorScheme.dark(
        primary: phosphorGreen,
        secondary: dimmerGreen,
        surface: darkCard,
        background: darkBg,
      ),
      inputDecorationTheme: InputDecorationTheme(
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: dimmerGreen.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: phosphorGreen, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        labelStyle: TextStyle(color: dimmerGreen),
        hintStyle: TextStyle(color: dimmerGreen.withOpacity(0.5)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: phosphorGreen,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, inherit: false),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: phosphorGreen,
          side: BorderSide(color: phosphorGreen),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: phosphorGreen,
        ),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  @override
  _AuthGateState createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late Future<bool> _loginFuture;

  @override
  void initState() {
    super.initState();
    _loginFuture = AuthService().isLoggedIn();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _loginFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return const MainShell();
        }
        return LoginScreen();
      },
    );
  }
}
