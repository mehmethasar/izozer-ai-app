import 'package:flutter/material.dart';
import 'package:mazdek_ai/app/app_scope.dart';
import 'package:mazdek_ai/core/config/app_config.dart';
import 'package:mazdek_ai/core/theme/app_theme.dart';
import 'package:mazdek_ai/screens/root_screen.dart';
import 'package:mazdek_ai/state/app_state.dart';

class MazdekApp extends StatefulWidget {
  const MazdekApp({required this.state, super.key});
  final AppState state;
  @override State<MazdekApp> createState() => _MazdekAppState();
}

class _MazdekAppState extends State<MazdekApp> with WidgetsBindingObserver {
  bool _privacyCover = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final obscured = state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.hidden;
    if (obscured) widget.state.lock();
    if (mounted && _privacyCover != obscured) setState(() => _privacyCover = obscured);
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) => MaterialApp(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: switch (widget.state.themeMode) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          },
          home: Stack(
            fit: StackFit.expand,
            children: [
              const RootScreen(),
              if (_privacyCover)
                const ColoredBox(
                  color: Color(0xFF141414),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.white, size: 58),
                        SizedBox(height: 14),
                        Text('Mazdek', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
                        SizedBox(height: 6),
                        Text('Finansal veriler gizlendi', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
