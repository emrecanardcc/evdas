import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/services/heartbeat_service.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/expense_repository.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Türkçe tarih formatlamasını başlat
  await initializeDateFormatting('tr_TR', null);

  // Canlı Supabase altyapısını başlat
  await SupabaseService.initialize();

  // Supabase uyku modu önleyici heartbeat pingi (UI'yi bloklamaz)
  unawaited(HeartbeatService.pingIfNeeded());

  // Yerel veritabanı / SharedPreferences başlat
  final expenseRepo = await ExpenseRepository.init();

  runApp(
    ProviderScope(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(expenseRepo),
      ],
      child: const EvdasApp(),
    ),
  );
}

class EvdasApp extends StatelessWidget {
  const EvdasApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Oturum açıksa doğrudan ana ekrana, değilse Auth ekranına yönlendir
    final initialScreen = SupabaseService.isAuthenticated
        ? const HomeScreen()
        : const AuthScreen();

    return MaterialApp(
      title: 'Evdaş',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: initialScreen,
    );
  }
}
