import 'package:flutter/material.dart';
import 'sdui/sdui_page_loader.dart';
import 'sdui/theme_registry.dart';

Future<void> main() async {
  // Plugins (shared_preferences) need the binding before runApp.
  WidgetsFlutterBinding.ensureInitialized();
  // Fetch the brand theme so we can build MaterialApp with it. Falls back
  // to SDUITheme.fallback if /theme is unreachable.
  await ThemeRegistry.bootstrap();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SDUITheme>(
      valueListenable: ThemeRegistry.notifier,
      builder: (context, theme, _) {
        return MaterialApp(
          title: 'SDUI Deep Link Demo',
          theme: theme.toThemeData(),
          // Server decides the entrypoint. Client just asks `/` and the
          // server redirects (HTTP 302) to whichever screen should load first.
          initialRoute: '/',

          // Generic, server-driven routing.
          // Whatever path the server (or another JSON node) hands us via a
          // `navigate` action is the endpoint we fetch. No hardcoded screen list.
          onGenerateRoute: (settings) {
            final path = (settings.name == null || settings.name!.isEmpty)
                ? '/home'
                : settings.name!;
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            debugPrint('🚦 Routing to: $path');

            return MaterialPageRoute(
              settings: settings,
              builder: (_) => SDUIGenericPage(endpoint: path, initialData: args),
            );
          },
        );
      },
    );
  }
}
