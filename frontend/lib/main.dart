import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'screens.dart';
import 'dashboard_screen.dart';

const ivory = Color(0xFFFCF8F5);
const forest = Color(0xFF2B8554);
const accent = Color(0xFFD94060);
const ink = Color(0xFF24342B);

void main() {
  runApp(const VmsApp());
}

class VmsApp extends StatefulWidget {
  const VmsApp({super.key});
  @override
  State<VmsApp> createState() => _VmsAppState();
}

class _VmsAppState extends State<VmsApp> {
  final ApiClient api = ApiClient();
  AuthSession? session;

  @override
  void dispose() {
    api.close();
    super.dispose();
  }

  void logout() {
    api.signOut();
    setState(() {
      session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stark Group VMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: ivory,
        colorScheme: ColorScheme.fromSeed(
          seedColor: forest,
          primary: forest,
          secondary: accent,
          surface: ivory,
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: ink,
          displayColor: ink,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFDBE3DA)),
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 15,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            animationDuration: const Duration(milliseconds: 200),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            elevation: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.hovered) ? 9 : 2,
            ),
            shadowColor: WidgetStatePropertyAll(forest.withValues(alpha: 0.27)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            animationDuration: const Duration(milliseconds: 200),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            elevation: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.hovered) ? 5 : 0,
            ),
            shadowColor: WidgetStatePropertyAll(forest.withValues(alpha: 0.20)),
          ),
        ),
      ),
      home: session == null
          ? AuthScreen(
              api: api,
              onAuthenticated: (s) => setState(() => session = s),
            )
          : FleetDashboardScreen(api: api, session: session!, onLogout: logout),
    );
  }
}
