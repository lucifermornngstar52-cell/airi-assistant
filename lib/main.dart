import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'theme/app_theme.dart';
import 'screens/chat_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/providers_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // На Windows — используем FFI для SQLite
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Только на мобильных — ориентация и статус-бар
  if (Platform.isAndroid || Platform.isIOS) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.bgColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  runApp(const AiriApp());
}

class AiriApp extends StatelessWidget {
  const AiriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIRI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: '/',
      routes: {
        '/':          (_) => const ChatScreen(),
        '/settings':  (_) => const SettingsScreen(),
        '/providers': (_) => const ProvidersScreen(),
      },
    );
  }
}
