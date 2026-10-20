import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/heartbeat_service.dart';
import '../../core/services/supabase_service.dart';
import '../../data/repositories/expense_repository.dart';
import '../providers/app_providers.dart';
import 'expenses_screen.dart';
import 'household_screen.dart';
import 'quick_expense_screen.dart';
import 'reports_screen.dart';
import 'settlement_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0; // Açar açmaz Hızlı Giriş Numpad Ekranı!
  StreamSubscription<String>? _syncSub;

  final List<Widget> _screens = const [
    QuickExpenseScreen(),
    ExpensesScreen(),
    ReportsScreen(),
    SettlementScreen(),
    HouseholdScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _syncSub = ExpenseRepository.syncNotifications.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cloud_done_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.positive,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    });

    // Oturum açıksa açılışta bulut ile arka planda canlı eşitle ve heartbeat gönder
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(HeartbeatService.pingIfNeeded());
      if (SupabaseService.isAuthenticated) {
        ref.read(expenseRepositoryProvider).syncWithCloud().then((_) {
          if (mounted) {
            ref.read(householdProvider.notifier).refresh();
            ref.read(expensesProvider.notifier).refresh();
            ref.read(paymentRequestsProvider.notifier).refresh();
            ref.read(approvalRequestsProvider.notifier).refresh();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt_rounded, color: AppColors.primary),
            label: 'Hızlı Gir',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon:
                Icon(Icons.receipt_long_rounded, color: AppColors.primary),
            label: 'Hareketler',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: AppColors.primary),
            label: 'Raporlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.handshake_outlined),
            selectedIcon:
                Icon(Icons.handshake_rounded, color: AppColors.primary),
            label: 'Ödeşme',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group_rounded, color: AppColors.primary),
            label: 'Ortaklık',
          ),
        ],
      ),
    );
  }
}
