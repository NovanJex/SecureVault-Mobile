import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/audit_screen.dart';
import 'screens/generator_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/vault_screen.dart';
import 'state/vault_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SecureVaultMobileApp());
}

class SecureVaultMobileApp extends StatefulWidget {
  const SecureVaultMobileApp({super.key});

  @override
  State<SecureVaultMobileApp> createState() => _SecureVaultMobileAppState();
}

class _SecureVaultMobileAppState extends State<SecureVaultMobileApp> {
  final VaultController _controller = VaultController();
  int _currentTab = 0;
  String? _toastMessage;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onStateChanged);
    _controller.init();
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    _toastTimer?.cancel();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _showToast(String msg) {
    _toastTimer?.cancel();
    setState(() => _toastMessage = msg);
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _controller.isDark;
    final scaffoldBg =
        isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);

    return MaterialApp(
      title: 'SecureVault',
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4F46E5),
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6366F1),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020617),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      home: Scaffold(
        backgroundColor: scaffoldBg,
        body: SafeArea(
          child: Stack(
            children: [
              if (!_controller.isUnlocked)
                LockScreen(controller: _controller, onToast: _showToast)
              else
                IndexedStack(
                  index: _currentTab,
                  children: [
                    VaultScreen(controller: _controller, onToast: _showToast),
                    GeneratorScreen(
                        controller: _controller, onToast: _showToast),
                    AuditScreen(controller: _controller, onToast: _showToast),
                    SettingsScreen(
                        controller: _controller, onToast: _showToast),
                  ],
                ),
              if (_toastMessage != null)
                Positioned(
                  top: 12,
                  left: 24,
                  right: 24,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.15)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('✓',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF34D399),
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _toastMessage!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: _controller.isUnlocked
            ? NavigationBar(
                height: 64,
                selectedIndex: _currentTab,
                onDestinationSelected: (idx) =>
                    setState(() => _currentTab = idx),
                destinations: [
                  NavigationDestination(
                    icon: const Text('🔐', style: TextStyle(fontSize: 16)),
                    label: _controller.isZh ? '保险箱' : 'Vault',
                  ),
                  NavigationDestination(
                    icon: const Text('🎲', style: TextStyle(fontSize: 16)),
                    label: _controller.isZh ? '生成器' : 'Generator',
                  ),
                  NavigationDestination(
                    icon: const Text('🛡️', style: TextStyle(fontSize: 16)),
                    label: _controller.isZh ? '审计' : 'Audit',
                  ),
                  NavigationDestination(
                    icon: const Text('⚙️', style: TextStyle(fontSize: 16)),
                    label: _controller.isZh ? '设置' : 'Settings',
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
