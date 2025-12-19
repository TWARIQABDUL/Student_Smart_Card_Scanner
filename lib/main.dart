import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // 👈 Import Provider
import 'services/theme_manager.dart';    // 👈 Import ThemeManager
import 'screens/guard_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load Theme before app starts
  final themeManager = ThemeManager();
  await themeManager.loadTheme();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeManager),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 2. Watch Theme
    final theme = Provider.of<ThemeManager>(context);

    return MaterialApp(
      title: 'Guard Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Apply SaaS Colors globally
        primaryColor: theme.primaryColor,
        scaffoldBackgroundColor: theme.backgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.primaryColor,
          background: theme.backgroundColor,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const GuardLoginScreen(),
    );
  }
}