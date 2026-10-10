import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/constants/api_constants.dart';
import 'core/theme/app_theme.dart';
import 'providers/pos_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/theme_provider.dart';
import 'services/auth_service.dart';
import 'services/store_profile_service.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI engine on Desktop platforms (Windows, Linux, macOS)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await ApiConstants.loadSavedUrls();
  await StoreProfileService.instance.init();
  await AuthService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => PosProvider()),
        ChangeNotifierProvider(create: (_) => AiProvider()),
        ChangeNotifierProvider.value(value: AuthService.instance),
      ],
      child: const LarisAiApp(),
    ),
  );
}

class LarisAiApp extends StatelessWidget {
  const LarisAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'LarisAI Smart POS UMKM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const MainScreen(),
    );
  }
}
