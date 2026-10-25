import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/services/haptic_service.dart';
import 'core/services/sound_service.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/expense_repository.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/providers/customization_provider.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Türkçe tarih formatlamasını başlat
  await initializeDateFormatting('tr_TR', null);

  // Canlı Supabase altyapısını başlat (Soğuk açılış ve zayıf ağlarda ANR önleme amaçlı 3 sn zaman aşımı)
  await SupabaseService.initialize().timeout(
    const Duration(seconds: 3),
    onTimeout: () => debugPrint('Supabase başlatma zaman aşımı - Çevrimdışı modda devam ediliyor'),
  );

  // Yerel veritabanı / SharedPreferences başlat
  final expenseRepo = await ExpenseRepository.init();

  // Haptik ve Ses Servislerini başlat
  await HapticService.init(expenseRepo.prefs);
  await SoundService.init(expenseRepo.prefs);

  runApp(
    ProviderScope(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(expenseRepo),
      ],
      child: const EvdasApp(),
    ),
  );
}

class EvdasApp extends ConsumerWidget {
  const EvdasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Oturum açıksa doğrudan ana ekrana, değilse Auth ekranına yönlendir
    final initialScreen = SupabaseService.isAuthenticated
        ? const HomeScreen()
        : const AuthScreen();

    final themeType = ref.watch(themeModeProvider);
    final accentColor = ref.watch(accentColorProvider);
    final font = ref.watch(fontFamilyProvider);

    final dynamicTheme = AppTheme.buildTheme(
      type: themeType,
      accentColor: accentColor.color,
      font: font,
    );

    return MaterialApp(
      title: 'Evdaş',
      debugShowCheckedModeBanner: false,
      theme: dynamicTheme,
      home: initialScreen,
    );
  }
}
