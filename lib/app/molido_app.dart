import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/calculator/calculator_screen.dart';
import '../features/charts/charts_screen.dart';
import '../features/home/home_screen.dart';
import '../features/market/market_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/update/update_flow.dart';
import '../state/app_providers.dart';
import 'theme.dart';

class MolidoApp extends ConsumerStatefulWidget {
  const MolidoApp({super.key});

  @override
  ConsumerState<MolidoApp> createState() => _MolidoAppState();
}

class _MolidoAppState extends ConsumerState<MolidoApp>
    with WidgetsBindingObserver {
  int _tab = 0;

  static const _screens = <Widget>[
    HomeScreen(),
    MarketScreen(),
    ChartsScreen(),
    CalculatorScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(() async {
      await ref.read(refreshEngineProvider).onForegroundChanged(true);
    });
    Future<void>.delayed(const Duration(seconds: 8), () async {
      if (!mounted) return;
      final check = await ref.read(updateCheckProvider.future);
      if (check.hasUpdate && mounted) {
        await runUpdateFlow(context, ref, precheck: check);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final engine = ref.read(refreshEngineProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        engine.onForegroundChanged(true);
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        engine.onForegroundChanged(false);
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MOLIDO MARKET',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        body: IndexedStack(index: _tab, children: _screens),
        bottomNavigationBar: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard_rounded),
                label: 'خانه',
              ),
              NavigationDestination(
                icon: Icon(Icons.candlestick_chart_outlined),
                selectedIcon: Icon(Icons.candlestick_chart_rounded),
                label: 'بازار',
              ),
              NavigationDestination(
                icon: Icon(Icons.query_stats_outlined),
                selectedIcon: Icon(Icons.query_stats_rounded),
                label: 'نمودارها',
              ),
              NavigationDestination(
                icon: Icon(Icons.calculate_outlined),
                selectedIcon: Icon(Icons.calculate_rounded),
                label: 'محاسبه',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'بیشتر',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
