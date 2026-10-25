import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:iptv_app/screens/home_screen.dart';

// Global key to allow showing dialogs without a local BuildContext
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class DesktopScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // 1. Catch Flutter-specific errors (UI, Build, etc.)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _showErrorDialog('Flutter Error', details.exceptionAsString());
  };

  // 2. Catch asynchronous errors (Network, parsing, etc.)
  PlatformDispatcher.instance.onError = (error, stack) {
    _showErrorDialog('System/Async Error', error.toString());
    return true;
  };

  runApp(const MyApp());
}

void _showErrorDialog(String title, String message) {
  final context = navigatorKey.currentContext;
  if (context != null) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181A20),
        title: Row(
          children: [
            const Icon(Icons.bug_report, color: Color(0xFFE50914), size: 28),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Dismiss', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'StreamEast TV',
      debugShowCheckedModeBanner: false,
      scrollBehavior: DesktopScrollBehavior(),
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0B0E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE50914),
          primary: const Color(0xFFE50914),
          secondary: const Color(0xFFFF334B),
          surface: const Color(0xFF14161D),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
