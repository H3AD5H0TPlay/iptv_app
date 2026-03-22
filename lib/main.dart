import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:iptv_app/screens/home_screen.dart';

// Global key to allow showing dialogs without a local BuildContext
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // 1. Catch Flutter-specific errors (UI, Build, etc.)
  FlutterError.onError = (details) {
    FlutterError.presentError(details); // Still log to console
    _showErrorDialog('Flutter Error', details.exceptionAsString());
  };

  // 2. Catch asynchronous errors (Network, parsing, etc.)
  PlatformDispatcher.instance.onError = (error, stack) {
    _showErrorDialog('System/Async Error', error.toString());
    return true; // Mark as handled
  };

  runApp(const MyApp());
}

void _showErrorDialog(String title, String message) {
  // Use the global navigator key to show the dialog
  final context = navigatorKey.currentContext;
  if (context != null) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bug_report, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
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
      navigatorKey: navigatorKey, // Required for the global error dialogs
      title: 'StreamEast',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
