import 'package:flutter/material.dart';
import 'sdui/sdui_page_loader.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SDUI Deep Link Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
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
  }
}
