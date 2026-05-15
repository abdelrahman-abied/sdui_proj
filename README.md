# SDUI Proj — Server-Driven UI in Dart

A complete, working reference for **Server-Driven UI (SDUI)** in pure Dart: a [Dart Frog](https://dart-frog.dev) backend describes screens as JSON, a Flutter client renders them as native widgets. Ship UI changes without releasing a new app build — change the server response and reload.

Routing, navigation targets, brand colors, and the app's entrypoint are all decided by the server. The client knows nothing about specific screens.

```text
┌──────────────────────────────┐          ┌──────────────────────────────┐
│ sdui_server  (Dart Frog API) │          │ sdui_project  (Flutter app)  │
│                              │          │                              │
│  GET  /         → 302 entry  │   JSON   │  SDUIGenericPage             │
│  GET  /login    → form JSON  │ ───────► │    → SDUIApiService (HTTP)   │
│  POST /auth/login            │ ◄──────  │    → SDUIParser              │
│  GET  /home     → dashboard  │  action  │    → ComponentRegistry       │
│  GET  /products?page=N       │          │    → Flutter widgets         │
│  GET  /product/:id           │          │                              │
│  GET  /feed?page=N           │          │                              │
│  GET  /theme    → brand JSON │          │                              │
└──────────────────────────────┘          └──────────────────────────────┘
```

This README is both a feature reference and a **build-from-scratch guide**. If you want to construct a system like this, follow the [Build it from scratch](#build-it-from-scratch) section step by step.

---

## Table of contents

1. [What "SDUI" actually means here](#what-sdui-actually-means-here)
2. [Feature highlights](#feature-highlights)
3. [Quick demo](#quick-demo)
4. [Build it from scratch](#build-it-from-scratch)
5. [Reference: the SDUI contract](#reference-the-sdui-contract)
6. [Operational notes](#operational-notes)
7. [Going further](#going-further)

---

## What "SDUI" actually means here

A pure Dart implementation that takes a strong, opinionated position:

| Decision | This repo's answer |
| --- | --- |
| Atomic vs semantic components | **Semantic** — server emits `CARD`, `BUTTON_PRIMARY`, `INPUT_TEXT`, not flex/box primitives. |
| Schema shape | Every node is `{type, props, children?, action?, fallback_type?}`. |
| Routing | Server-driven; the client's `onGenerateRoute` is a pass-through. |
| Forms | Singleton `FormManager` collects values by `props.id`; `form_submit` POSTs everything. |
| Auth | HS256 JWT, persisted client-side, server replies an SDUI action on 401. |
| Theming | Server emits brand tokens, client builds `ThemeData`, JSON references `@primary`/`@danger`. |
| Schema evolution | `X-SDUI-Version` headers, plus per-node `fallback_type` for newer widgets on older clients. |

For a longer architectural discussion of trade-offs, see [SDUI_ARCHITECTURE_ARTICLE.md](SDUI_ARCHITECTURE_ARTICLE.md).

---

## Feature highlights

- **Fully server-driven routing** — Initial route is an HTTP 302 from `/`. No path-to-screen map in the client.
- **Generic component registry** — Add a new widget type by registering one builder; the parser dispatches by `type`.
- **JSON action protocol** — `navigate`, `form_submit`, `show_toast`, `network_request`, `pop`, `logout`. Forms validate locally, POST to the server, and run whatever action the server returns next.
- **Real auth & session** — `/auth/login` issues an HS256 JWT; the client persists it via `shared_preferences` and attaches `Authorization: Bearer …` on every request.
- **Schema versioning** — `X-SDUI-Version` request/response headers; widgets can ship a `fallback_type` so older clients keep rendering during a rollout.
- **Server-driven theming** — `GET /theme` returns brand tokens; the client builds `ThemeData`; component colors use `@primary`, `@danger` references.
- **Real pagination** — `LAZY_LIST` emits `nextUrl`; client fetches more on scroll and stops when the server omits it.
- **Pull-to-refresh + cache** — Every screen has `RefreshIndicator`; pulling bypasses the in-memory cache.
- **Configurable base URL** — `--dart-define=SDUI_BASE_URL=…`; sensible defaults for Android emulator, iOS sim, desktop, and web.
- **CORS-ready** — Global middleware adds permissive CORS so the Flutter web build works out of the box.
- **Contract tests** — Flutter tests assert every server-emitted component type renders and forms register the right `id`/value.

---

## Quick demo

### Prerequisites

- Dart SDK ≥ 3.0
- Flutter ≥ 3.10
- [`dart_frog_cli`](https://pub.dev/packages/dart_frog_cli):
  ```bash
  dart pub global activate dart_frog_cli
  ```

### 1. Run the server

```bash
cd sdui_server
dart pub get
dart_frog dev      # http://localhost:8080
```

### 2. Run the client

```bash
cd sdui_project
flutter pub get
flutter run
```

> **Android emulator** reaches the host at `10.0.2.2:8080` (handled automatically in `SDUIApiService.baseUrl`).
> **iOS simulator / desktop / web** use `localhost:8080`. ATS, Android cleartext, and macOS sandbox `network.client` are pre-configured.

Point at a different backend:

```bash
flutter run --dart-define=SDUI_BASE_URL=https://sdui.example.com
```

### Test credentials

| | |
| --- | --- |
| **Email** | `demo@sdui.app` |
| **Password** | `password` |

### Run the contract tests

```bash
cd sdui_project
flutter test       # 22 tests — fail if the schema drifts
```

---

## Build it from scratch

This walkthrough builds the same system, in roughly the order the codebase grew. Each step ends with a pointer to the real file so you can compare.

### Step 0 — Prerequisites

The same ones from [Quick demo](#prerequisites): Dart 3, Flutter, `dart_frog_cli`.

### Step 1 — Repo layout

Two independent Dart packages side by side:

```text
sdui_proj/
├── sdui_server/        # Dart Frog API
└── sdui_project/       # Flutter client
```

The packages share **no code** — they only share the JSON wire shape. That's intentional: it forces the contract through the wire instead of through a leaky shared library.

### Step 2 — Scaffold the server

```bash
dart_frog create sdui_server
cd sdui_server
dart pub add dart_jsonwebtoken   # for the auth step later
```

You'll get a `routes/index.dart` returning "Welcome to Dart Frog!". Leave it for now.

### Step 3 — Define the wire contract

Every node the server emits must have the same shape, so make a base class. Put it in [`sdui_server/lib/sdui_builder.dart`](sdui_server/lib/sdui_builder.dart):

```dart
abstract class SDUIWidget {
  const SDUIWidget({
    required this.type,
    this.props = const {},
    this.children,
    this.action,
    this.fallbackType,
    this.fallbackProps,
  });

  final String type;
  final Map<String, dynamic> props;
  final List<SDUIWidget>? children;
  final Map<String, dynamic>? action;
  final String? fallbackType;
  final Map<String, dynamic>? fallbackProps;

  Map<String, dynamic> toJson() => {
        'type': type,
        'props': props,
        if (children != null && children!.isNotEmpty)
          'children': children!.map((c) => c.toJson()).toList(),
        if (action != null) 'action': action,
        if (fallbackType != null) 'fallback_type': fallbackType,
        if (fallbackProps != null) 'fallback_props': fallbackProps,
      };
}
```

Two rules pay off later:

- **All component fields live in `props`** — never on the root node. If you mix the two you'll have a silent bug where the client reads from the wrong location.
- **Empty `children`/`action`/`fallback_*` are omitted**, not emitted as `null`. The server's JSON output stays small.

Then add concrete classes for each component. Start small:

```dart
class VerticalStack extends SDUIWidget {
  VerticalStack({super.children}) : super(type: 'VERTICAL_STACK');
}

class SDUIText extends SDUIWidget {
  SDUIText({required String text, String? style, String? color})
      : super(type: 'TEXT', props: {
          'text': text,
          if (style != null) 'style': style,
          if (color != null) 'color': color,
        });
}
```

Action helpers live in [`sdui_server/lib/sdui_actions.dart`](sdui_server/lib/sdui_actions.dart):

```dart
Map<String, dynamic> sduiAction({
  required String type,
  String? url,
  Map<String, dynamic>? data,
  String? successUrl,
  String? successMessage,
}) => {
  'type': type,
  if (url != null) 'url': url,
  if (data != null) 'data': data,
  if (successUrl != null) 'success_url': successUrl,
  if (successMessage != null) 'success_message': successMessage,
};
```

### Step 4 — First route

Drop a route under `sdui_server/routes/home/index.dart`:

```dart
import 'package:dart_frog/dart_frog.dart';
import 'package:sdui_server/sdui_builder.dart';

Response onRequest(RequestContext context) {
  final dashboard = VerticalStack(children: [
    SDUIText(text: 'Hello, SDUI!', style: 'title'),
  ]);
  return Response.json(body: dashboard.toJson());
}
```

`dart_frog dev` and `curl http://localhost:8080/home` should return the JSON. **This is the wire contract. Every later feature builds on this shape.**

### Step 5 — Scaffold the Flutter client

```bash
flutter create sdui_project
cd sdui_project
flutter pub add http shared_preferences
```

We'll use `http` for fetching and `shared_preferences` later for the JWT.

### Step 6 — The HTTP layer

Create [`sdui_project/lib/sdui/sdui_page_loader.dart`](sdui_project/lib/sdui/sdui_page_loader.dart). The key bits:

```dart
class SDUIApiService {
  static const String _override = String.fromEnvironment('SDUI_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://localhost:8080';
  }

  static final Map<String, Map<String, dynamic>> _cache = {};
  static void clearCache() => _cache.clear();

  static Future<Map<String, dynamic>> fetchEndpoint(
    String endpoint, {
    bool useCache = true,
  }) async {
    final uri = _resolve(endpoint);
    final key = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    if (useCache && _cache.containsKey(key)) {
      return Map<String, dynamic>.from(_cache[key]!);
    }
    final r = await http.get(uri, headers: await _headers());
    final data = await _decode(r, uri);
    if (useCache) _cache[key] = data;
    return data;
  }
}
```

Three things to notice:

- `--dart-define=SDUI_BASE_URL=…` overrides everything. Use this to point at staging.
- Android emulator gets `10.0.2.2` automatically (the host machine's loopback).
- A simple in-memory cache, keyed by URL+query. Pulled-to-refresh navigations and `clearCache()` invalidate it.

### Step 7 — The parser and the registry

Two tiny components do all the work on the client:

- **`ComponentRegistry`** ([`component_registry.dart`](sdui_project/lib/sdui/component_registry.dart)) — `Map<String, Widget Function(node)>`.
- **`SDUIParser`** ([`sdui_parser.dart`](sdui_project/lib/sdui/sdui_parser.dart)) — looks up the type in the registry, builds the widget, and wraps it in a `GestureDetector` if the node has an action.

```dart
class ComponentRegistry {
  static final Map<String, SDUIWidgetBuilder> _registry = {
    'VERTICAL_STACK': (node) => Column(
      children: (node['children'] as List? ?? [])
          .map((c) => SDUIParser(uiJson: Map<String, dynamic>.from(c as Map)))
          .toList(),
    ),
    'TEXT': (node) {
      final props = Map<String, dynamic>.from(node['props'] as Map? ?? {});
      return Text(props['text']?.toString() ?? '');
    },
  };

  static SDUIWidgetBuilder? getWidgetBuilder(String type) => _registry[type];
}
```

The parser's job is one switch plus action wrapping:

```dart
class SDUIParser extends StatelessWidget {
  final Map<String, dynamic> uiJson;
  const SDUIParser({super.key, required this.uiJson});

  @override
  Widget build(BuildContext context) {
    final type = uiJson['type'] ?? 'UNKNOWN';
    final builder = ComponentRegistry.getWidgetBuilder(type);
    if (builder == null) return _unknownBanner(type);

    Widget native = builder(uiJson);
    if (uiJson.containsKey('action')) {
      final action = SDUIAction.fromJson(
        Map<String, dynamic>.from(uiJson['action'] as Map),
      );
      native = GestureDetector(
        onTap: () => SDUIActionDelegate.handleAction(context, action),
        child: native,
      );
    }
    return native;
  }
}
```

### Step 8 — Generic routing

The whole router in [`main.dart`](sdui_project/lib/main.dart):

```dart
MaterialApp(
  initialRoute: '/',
  onGenerateRoute: (settings) {
    final path = (settings.name?.isNotEmpty ?? false) ? settings.name! : '/home';
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => SDUIGenericPage(endpoint: path),
    );
  },
)
```

Whatever path comes in — `/products`, `/product/42`, `/anything-the-server-knows` — gets passed to `SDUIGenericPage`, which calls `SDUIApiService.fetchEndpoint(path)` and feeds the response into `SDUIParser`.

You now have a fully working baseline: server emits JSON, client renders it, navigation works.

### Step 9 — Actions

`SDUIAction` ([`sdui_action.dart`](sdui_project/lib/sdui/sdui_action.dart)) is a thin model:

```dart
class SDUIAction {
  final String type;
  final String? url;
  final Map<String, dynamic>? payload;
  final String? successUrl;
  final String? successMessage;
  // ...fromJson reads `data`, `success_url`, `success_message`.
}
```

`SDUIActionDelegate` ([`action_delegate.dart`](sdui_project/lib/sdui/action_delegate.dart)) is one big switch:

```dart
switch (action.type) {
  case 'navigate':       Navigator.pushNamed(context, action.url!); break;
  case 'pop':            Navigator.pop(context); break;
  case 'show_toast':     /* SnackBar from action.payload['message'] */ break;
  case 'form_submit':    _handleFormSubmit(context, action); break;
  case 'logout':         _handleLogout(context, action); break;
}
```

Crucially, `navigate` doesn't need a client-side route table — `Navigator.pushNamed(url)` flows back through `onGenerateRoute` from Step 8, which fetches the URL.

### Step 10 — Containers, layouts, images, buttons

Add more components to `ComponentRegistry`. Each follows the same pattern: read `props`, build a Flutter widget. Examples:

- `CONTAINER` → `Container` with `padding` / `margin` / `backgroundColor` / `cornerRadius` from props.
- `IMAGE` → `Image.network` with `props.url` / `props.height`, plus an error builder.
- `BUTTON_PRIMARY` → a filled Material button with `props.label`. No `onTap` — the gesture wrapper from Step 7 handles it.
- `HORIZONTAL_SCROLL` → `SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: …))`.

See [`component_registry.dart`](sdui_project/lib/sdui/component_registry.dart) for the full table.

### Step 11 — Style parsing

Pull color/padding logic out of every builder into a single [`StyleParser`](sdui_project/lib/utils/style_parser.dart):

```dart
class StyleParser {
  static Color? parseColor(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('@')) {
      return ThemeRegistry.current.colors[raw.substring(1)];
    }
    // …hex fallback
  }

  static EdgeInsets parsePadding(Map<String, dynamic>? props) {
    final v = props?['padding'];
    return v is num ? EdgeInsets.all(v.toDouble()) : EdgeInsets.zero;
  }
}
```

Note the `@token` branch — it'll resolve theme tokens once we add `ThemeRegistry` in Step 17.

### Step 12 — Forms

Three pieces:

1. `SDUIFormManager` singleton holds field values, validators, and errors ([`form_manager.dart`](sdui_project/lib/sdui/form_manager.dart)).
2. Form widgets register themselves on init: `INPUT_TEXT` calls `manager.registerInput(id, validators)`, then `manager.set(id, value)` on change. The same pattern works for `CHECKBOX`, `SWITCH`, `RADIO_GROUP`, `SELECT`.
3. `form_submit` action collects values via `manager.export()`, merges with `action.payload`, POSTs to `action.url`.

Server-side `INPUT_TEXT`:

```dart
class InputText extends SDUIWidget {
  InputText({required String id, String? label, String? placeholder})
      : super(type: 'INPUT_TEXT', props: {
          'id': id,
          if (label != null) 'label': label,
          if (placeholder != null) 'placeholder': placeholder,
        });
}
```

Client registry:

```dart
'INPUT_TEXT': (node) {
  final props = Map<String, dynamic>.from(node['props'] as Map? ?? {});
  return SDUITextInput(
    id: props['id']?.toString() ?? 'unknown_id',
    props: props,
  );
},
```

> **Common bug**: putting `id` at the root of the node (`node['id']`) instead of in `props`. The form will silently submit nothing — the contract test in Step 20 catches this.

### Step 13 — Real form submit

`_handleFormSubmit` in [`action_delegate.dart`](sdui_project/lib/sdui/action_delegate.dart):

```dart
final errors = manager.validate();
if (errors != null) {
  manager.fieldErrors.value = errors;
  return;
}
final body = {...manager.export(), if (action.payload != null) ...action.payload!};

final reply = await SDUIApiService.postJson(action.url!, body);

if (reply['token'] is String) await SessionStore.setToken(reply['token']);
if (reply['message'] is String) _showSnack(reply['message']);

final next = reply['action'];
if (next is Map) {
  final a = SDUIAction.fromJson(Map<String, dynamic>.from(next));
  // navigate or dispatch via handleAction
}
```

The principle: **the server is authoritative for what happens next**. On success it returns a `navigate` action. On failure it returns a `show_toast`. The client doesn't decide.

Server side:

```dart
// routes/auth/login/index.dart
final body = await context.request.json();
if (body['username'] != 'demo@sdui.app' || body['password'] != 'password') {
  return Response.json(body: {
    'action': sduiAction(
      type: 'show_toast',
      data: {'message': 'Invalid credentials', 'is_error': true},
    ),
  });
}
return Response.json(body: {
  'token': issueToken(body['username']),
  'action': sduiAction(type: 'navigate', url: '/home'),
  'message': 'Welcome',
});
```

### Step 14 — Auth & session

Three new files plus middleware.

**Server JWT helpers** [`lib/auth.dart`](sdui_server/lib/auth.dart):

```dart
String issueToken(String username) =>
    JWT({'sub': username}, issuer: 'sdui_server')
        .sign(SecretKey(_secret), expiresIn: Duration(hours: 24));

Map<String, dynamic>? verifyToken(String? token) {
  if (token == null) return null;
  try {
    return Map<String, dynamic>.from(JWT.verify(token, SecretKey(_secret)).payload as Map);
  } on JWTException { return null; }
}
```

**Global middleware** [`routes/_middleware.dart`](sdui_server/routes/_middleware.dart):

```dart
Handler middleware(Handler handler) {
  return (context) async {
    final path = context.request.uri.path;
    final username = _authenticate(context);
    if (_isProtected(path) && username == null) {
      return Response.json(statusCode: 401, body: {
        'action': sduiAction(type: 'navigate', url: '/login'),
        'message': 'Please sign in to continue',
      });
    }
    final user = username == null ? AuthUser.anonymous : AuthUser(username: username);
    final inner = context.provide<AuthUser>(() => user);
    return handler(inner);
  };
}
```

Public-path allow-list: `/`, `/login`, `/auth/login`, `/theme`. Routes that need the user call `context.read<AuthUser>().username`.

**Client persistence** [`session_store.dart`](sdui_project/lib/sdui/session_store.dart) — a thin `SharedPreferences` wrapper. `SDUIApiService._headers()` reads `getToken()` on every request and adds `Authorization: Bearer …`. On `401` it clears the session and throws `SDUIUnauthorizedException(action)`, which `SDUIGenericPage` catches and dispatches via the delegate.

**Auth-aware entrypoint** — `GET /` reads `AuthUser` and redirects to `/home` if logged in, `/login` otherwise:

```dart
Response onRequest(RequestContext context) {
  final user = context.read<AuthUser>();
  return Response(
    statusCode: 302,
    headers: {'location': user.isAnonymous ? '/login' : '/home'},
  );
}
```

After this, a cold start with a persisted JWT skips the login screen.

### Step 15 — Schema versioning

Client sends a version header on every request:

```dart
static Future<Map<String, String>> _headers() async {
  final token = await SessionStore.getToken();
  return {
    'content-type': 'application/json',
    'x-sdui-version': '$sduiSchemaVersion',  // const = 1
    if (token != null) 'authorization': 'Bearer $token',
  };
}
```

Server middleware reads it and adds `x-sdui-deprecated` on the way back if the client is too old. The client's `SDUIApiService.deprecationNotice` (a `ValueNotifier<String?>`) captures it so the UI can show a banner.

For schema *changes*, widgets can ship a back-compat shape:

```dart
class FuturisticCard extends SDUIWidget {
  FuturisticCard() : super(
    type: 'FUTURISTIC_CARD',
    props: {'glow': true},
    fallbackType: 'CONTAINER',
    fallbackProps: {'padding': 16, 'backgroundColor': '@surface'},
  );
}
```

The client parser:

```dart
var builder = ComponentRegistry.getWidgetBuilder(type);
if (builder == null) {
  final fb = uiJson['fallback_type'] as String?;
  if (fb != null) builder = ComponentRegistry.getWidgetBuilder(fb);
  // …rebuild `node` with fallback_props instead of props
}
```

Older clients now render *something useful* during a rollout instead of the red "Unknown Component" banner.

### Step 16 — Theming

Server route [`routes/theme/index.dart`](sdui_server/routes/theme/index.dart) returns brand tokens:

```dart
const _theme = {
  'colors': {'primary': '#1a1a2e', 'danger': '#c62828', 'onPrimary': '#ffffff'},
  'typography': {'title': 24.0, 'body': 14.0},
  'radius': {'card': 12.0, 'button': 8.0},
};
Response onRequest(RequestContext context) => Response.json(body: _theme);
```

Add `/theme` to the public allow-list in the middleware so the splash can fetch it before login.

Client [`theme_registry.dart`](sdui_project/lib/sdui/theme_registry.dart):

```dart
class ThemeRegistry {
  static SDUITheme current = SDUITheme.fallback;
  static final notifier = ValueNotifier<SDUITheme>(SDUITheme.fallback);

  static Future<void> bootstrap() async {
    try {
      final json = await SDUIApiService.fetchEndpoint('/theme');
      current = SDUITheme.fromJson(json);
      notifier.value = current;
    } catch (_) { /* fall through to fallback */ }
  }
}
```

In `main.dart`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeRegistry.bootstrap();
  runApp(const MyApp());
}
```

`MaterialApp` uses `ValueListenableBuilder<SDUITheme>` over `ThemeRegistry.notifier` so a future hot-swap rebuilds the app.

The `StyleParser.parseColor` extension from Step 11 already resolves `@primary` against `ThemeRegistry.current.colors`. Component JSON now writes `color: '@primary'` instead of `color: '#1a1a2e'`. Change one map on the server, redeploy, restart the app — every screen re-brands.

### Step 17 — Pagination (LAZY_LIST)

Server emits `LAZY_LIST` with an optional `nextUrl`:

```dart
final products = LazyList(
  nextUrl: hasMore ? '/products?page=${page + 1}' : null,   // omitted on the last page
  children: [/* product cards */],
);
```

Client component ([`sdui_lazy_list.dart`](sdui_project/lib/components/sdui_lazy_list.dart)):

```dart
void _onScroll() {
  if (pos.pixels >= pos.maxScrollExtent - 200) _loadMore();
}
Future<void> _loadMore() async {
  if (_isLoading || _nextUrl == null) return;
  final next = await SDUIApiService.fetchEndpoint(_nextUrl!, useCache: false);
  _items.addAll((next['children'] as List?) ?? const []);
  _nextUrl = (next['props'] as Map?)?['nextUrl'] as String?;
  // …setState
}
```

When the server omits `nextUrl`, the client stops paging. No `has_more` flag needed.

### Step 18 — Pull-to-refresh + cache

`SDUIGenericPage` wraps its body in a `RefreshIndicator`:

```dart
RefreshIndicator(
  onRefresh: () => _fetchPage(useCache: false),
  child: SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    child: SDUIParser(uiJson: tree),
  ),
)
```

Same cache from Step 6: `fetchEndpoint(..., useCache: false)` bypasses the in-memory map. The error state has a Retry button that does the same.

### Step 19 — CORS for the web build

Web browsers refuse cross-origin requests without explicit headers. Make `routes/_middleware.dart` permissive in dev:

```dart
const _corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'access-control-allow-headers': 'content-type, authorization, x-sdui-version',
  'access-control-expose-headers': 'x-sdui-version, x-sdui-deprecated',
  'access-control-max-age': '86400',
};

// In middleware: short-circuit OPTIONS to 204, merge _corsHeaders into every response.
```

Tighten the allowed origin before production. `flutter run -d chrome` now works.

### Step 20 — Contract testing

The single most useful test you can write: a schema contract test ([`test/widget_test.dart`](sdui_project/test/widget_test.dart)).

```dart
test('every server-emitted type has a client builder', () {
  const serverEmittedTypes = [
    'VERTICAL_STACK', 'HORIZONTAL_SCROLL', 'CONTAINER', 'TEXT', 'IMAGE',
    'BUTTON_PRIMARY', 'INPUT_TEXT', 'LAZY_LIST', /* ...all of them */
  ];
  for (final t in serverEmittedTypes) {
    expect(ComponentRegistry.getWidgetBuilder(t), isNotNull);
  }
});

testWidgets('INPUT_TEXT id is read from props (regression)', (tester) async {
  await tester.pumpWidget(_wrap({
    'type': 'INPUT_TEXT',
    'props': {'id': 'email', 'label': 'Email'},
  }));
  await tester.enterText(find.byType(TextField), 'a@b.c');
  expect(SDUIFormManager().export()['email'], 'a@b.c');
});
```

When you next move a prop or rename a field, this fails fast instead of silently breaking the rendered UI.

---

### What you now have

Doing all twenty steps you end up with:

- A server with auth, theming, pagination, schema versioning, and CORS.
- A client that renders 18 component types, runs forms, holds a session across restarts, gracefully falls back on unknown components, and re-brands without redeploy.
- A test suite that fails the moment the wire shape drifts.
- ~1500 lines of Dart total, mostly straight-line code with no DI framework or codegen.

---

## Reference: the SDUI contract

Each node served by the backend has the shape:

```json
{
  "type": "VERTICAL_STACK",
  "props": { "padding": 16, "backgroundColor": "@primary" },
  "children": [ /* ... */ ],
  "action": { "type": "navigate", "url": "/product/1" }
}
```

| Field | Required | Description |
| --- | --- | --- |
| `type` | yes | Component identifier — looked up in `ComponentRegistry`. |
| `props` | no | Component-specific properties. **All component fields live here — never on the root node.** |
| `children` | no | Nested SDUI nodes. |
| `action` | no | Tap action payload (see below). |
| `fallback_type` | no | Type to render if the client doesn't know the primary `type`. |
| `fallback_props` | no | Props used with `fallback_type`. |

### Component types

| `type` | Server class | Client widget | Key `props` |
| --- | --- | --- | --- |
| `VERTICAL_STACK` | `VerticalStack` | `Column` | — |
| `HORIZONTAL_SCROLL` | `HorizontalScroll` | Horizontal `SingleChildScrollView` | — |
| `CONTAINER` | `SDUIContainer` | `Container` | `padding`, `margin`, `backgroundColor`, `cornerRadius` |
| `CARD` | `Card` | Material `Card` | `padding`, `margin`, `elevation` |
| `GRID_2_COL` | `Grid2Col` | 2-column `GridView` | `spacing` |
| `TEXT` | `SDUIText` | `Text` | `text`, `style` (`title`/`subtitle`/`body`), `color` |
| `IMAGE` | `SDUIImage` | `Image.network` with fallback | `url`, `height`, `width` |
| `ICON` | `SDUIIcon` | Material `Icon` | `name`, `size`, `color` |
| `BADGE` | `Badge` | Pill chip | `text`, `backgroundColor`, `color` |
| `DIVIDER` | `Divider` | `Divider` | `thickness`, `color`, `indent` |
| `LIST_ITEM` | `ListItem` | `ListTile` | `title`, `subtitle`, `leadingIcon`, `trailingIcon` |
| `BUTTON_PRIMARY` | `ButtonPrimary` | Filled button | `label` |
| `INPUT_TEXT` | `InputText` | `TextField` in `FormManager` | `id`, `label`, `placeholder` |
| `CHECKBOX` | `Checkbox` | `CheckboxListTile` in form | `id`, `label`, `default` |
| `SWITCH` | `Switch` | `SwitchListTile` in form | `id`, `label`, `default` |
| `RADIO_GROUP` | `RadioGroup` | Stacked radios in form | `id`, `label`, `options`, `default` |
| `SELECT` | `Select` | Dropdown in form | `id`, `label`, `options`, `default` |
| `LAZY_LIST` | `LazyList` | Paginated `ListView` | `nextUrl` (omitted on the last page) |

Form widgets (`INPUT_TEXT`, `CHECKBOX`, `SWITCH`, `RADIO_GROUP`, `SELECT`) all register themselves with the singleton `SDUIFormManager` by their `props.id` and are merged into the body of any sibling `form_submit` action automatically.

### Action types

| Action | Effect on client |
| --- | --- |
| `navigate` | `Navigator.pushNamed(url)` — `SDUIGenericPage` fetches that path. |
| `pop` | `Navigator.pop()`. |
| `show_toast` | `SnackBar` from `data.message` (`is_error: true` → red). |
| `form_submit` | Validates inputs locally, POSTs form data to `url`, displays `reply.message`. Paints `reply.errors` inline if present. Otherwise dispatches `reply.action` and persists `reply.token` if present. Form data is kept across navigations unless `reply.clear_form` is true. |
| `logout` | Clears the persisted JWT + in-memory cache and navigates to `action.url` (default `/login`). |
| `sequence` | Runs `action.actions` in order, awaiting each. |
| `network_request` | Fires an out-of-band HTTP call. |

Universal modifiers on any action:

| Field | Effect |
| --- | --- |
| `if: {field, equals\|not_equals\|truthy}` | Evaluated against `FormManager.export()` before dispatch. Skips when false. |
| `confirm: {title, message, confirmLabel, cancelLabel, destructive}` | Shows an `AlertDialog`; action only runs on confirm. |

### Auth headers in/out

| Direction | Header | Meaning |
| --- | --- | --- |
| Request | `Authorization: Bearer <jwt>` | Client → server, HS256 token |
| Request | `X-SDUI-Version: 1` | Client schema version |
| Response | `X-SDUI-Version` | Server's current schema version |
| Response | `X-SDUI-Deprecated` | Present when the client is below `_minSupportedClientVersion` |

### Theme tokens

The server returns `{colors, typography, radius}` from `/theme`. Component JSON references colors with `@token`:

```json
{ "type": "TEXT", "props": { "text": "Welcome", "color": "@onPrimary" } }
```

Unknown tokens fall through to `null` (widget picks its default).

---

## Operational notes

### Env vars

| Var | Where | Default | Used for |
| --- | --- | --- | --- |
| `SDUI_JWT_SECRET` | Server | `dev-secret-change-me` | HS256 signing key. **Override in production.** |
| `SDUI_BASE_URL` | Client (`--dart-define`) | `http://localhost:8080` / `10.0.2.2` | Points the client at staging/prod |

### Repo layout

```text
sdui_proj/
├── sdui_server/                  # Dart Frog backend
│   ├── lib/
│   │   ├── sdui_builder.dart     # Widget classes (toJson)
│   │   ├── sdui_actions.dart     # Action payload helper
│   │   └── auth.dart             # JWT + AuthUser context
│   └── routes/
│       ├── _middleware.dart      # CORS + JWT + schema-version
│       ├── index.dart            # / → 302 entrypoint
│       ├── login/index.dart
│       ├── auth/login/index.dart # POST issues JWT
│       ├── auth/me/index.dart    # GET current user (gated)
│       ├── home/index.dart
│       ├── products/index.dart
│       ├── product/[id].dart
│       ├── feed/index.dart
│       ├── settings/index.dart
│       ├── settings/save/index.dart
│       └── theme/index.dart
│
├── sdui_project/                 # Flutter client
│   ├── lib/
│   │   ├── main.dart
│   │   ├── sdui/
│   │   │   ├── sdui_page_loader.dart
│   │   │   ├── sdui_parser.dart
│   │   │   ├── component_registry.dart
│   │   │   ├── sdui_action.dart
│   │   │   ├── action_delegate.dart
│   │   │   ├── sdui_input.dart
│   │   │   ├── form_manager.dart
│   │   │   ├── session_store.dart
│   │   │   └── theme_registry.dart
│   │   ├── components/
│   │   │   ├── sdui_components.dart
│   │   │   ├── sdui_container.dart
│   │   │   ├── sdui_display.dart
│   │   │   ├── sdui_form_inputs.dart
│   │   │   ├── sdui_grid.dart
│   │   │   └── sdui_lazy_list.dart
│   │   └── utils/style_parser.dart
│   ├── test/widget_test.dart
│   └── pubspec.yaml
│
├── AGENTS.md                     # Reference for AI agents working in the repo
└── SDUI_ARCHITECTURE_ARTICLE.md  # Architectural discussion / trade-offs
```

### Adding a new screen

1. Drop a route file under `sdui_server/routes/`:
   ```dart
   import 'package:dart_frog/dart_frog.dart';
   import 'package:sdui_server/sdui_builder.dart';

   Response onRequest(RequestContext context) {
     final page = VerticalStack(children: [
       SDUIText(text: 'Hello, SDUI!', style: 'title'),
     ]);
     return Response.json(body: page.toJson());
   }
   ```
2. Link to it from any existing screen with `sduiAction(type: 'navigate', url: '/your-route')`.

No client change required — `onGenerateRoute` accepts any path.

### Adding a new component

1. Add a class to [`sdui_builder.dart`](sdui_server/lib/sdui_builder.dart) extending `SDUIWidget`. Put all properties in `props`.
2. Register a builder in [`component_registry.dart`](sdui_project/lib/sdui/component_registry.dart):

   ```dart
   'YOUR_TYPE': (node) {
     final props = Map<String, dynamic>.from(node['props'] as Map? ?? {});
     return YourWidget(/* read from props */);
   },
   ```

3. Add a fixture to [`test/widget_test.dart`](sdui_project/test/widget_test.dart) so a future schema drift is caught.

The parser handles gesture wrapping and action dispatch automatically.

### Re-brand without a release

1. Edit the color map in [`routes/theme/index.dart`](sdui_server/routes/theme/index.dart).
2. Redeploy the server.
3. Restart the app (it bootstraps the theme on cold start).

Every screen that uses `@token` colors reflects the new brand.

### Tighten before prod

| Concern | What to change |
| --- | --- |
| JWT secret | Set `SDUI_JWT_SECRET` to a long random string in your deploy environment |
| CORS | Replace `*` in `_corsHeaders` with your allowed origin |
| Mock auth | Replace `_mockUsername`/`_mockPassword` in [`routes/auth/login/index.dart`](sdui_server/routes/auth/login/index.dart) with a real user store |
| HTTPS | Run the server behind a TLS-terminating proxy; drop `usesCleartextTraffic` in Android and the ATS exceptions in iOS |

---

## Composing actions

The action protocol is more than `navigate` and `show_toast`. Any action can be wrapped in a confirmation dialog, gated by a condition on form state, or composed into a sequence — all from JSON, no client code change.

### Sequence — run several actions in order

```dart
sduiSequence([
  sduiAction(type: 'show_toast', data: {'message': 'Saving…'}),
  sduiAction(type: 'navigate', url: '/home'),
])
```

The client awaits each inner action before starting the next. Sequences nest.

### Confirm — show a dialog before running

```dart
sduiConfirm(
  sduiAction(type: 'logout', url: '/login'),
  title: 'Sign out?',
  message: "You'll need to sign in again.",
  confirmLabel: 'Sign out',
  destructive: true,         // red confirm button
)
```

The wrapped action runs only if the user taps confirm.

### `if` — gate on a form field

Useful for "Submit" buttons whose behavior depends on a checkbox state:

```dart
sduiWhen(
  sduiAction(type: 'form_submit', url: '/checkout'),
  field: 'agree',
  equals: true,
)
```

Supported predicates: `equals`, `not_equals`, `truthy`. The condition is evaluated against `SDUIFormManager.export()` on the client just before dispatch.

### Server-driven field errors

A `form_submit` reply that contains an `errors` map paints the messages inline on the matching `INPUT_TEXT` widgets and **keeps the form mounted** (no navigate):

```dart
// POST /settings/save
return Response.json(body: sduiFieldErrors({
  'plan': 'Pick a plan',
  'language': 'Pick a language',
}));
```

The client reads `reply.errors` and assigns `FormManager.fieldErrors`. Adding new fields to validation requires no client release.

### Multi-step forms

`form_submit` no longer clears the form by default. To preserve user input across pages (think wizard: step 1 → step 2 → review → submit), the server simply returns `navigate` and the singleton `FormManager` carries the values forward. When the final step succeeds, the server sends:

```json
{
  "clear_form": true,
  "action": { "type": "navigate", "url": "/home" }
}
```

That flag is the only way the form gets cleared.

### Composing all of these

The danger zone in `/settings` chains every Phase 5 feature into one action:

```dart
sduiConfirm(
  sduiSequence([
    sduiAction(type: 'show_toast', data: {'message': 'Account deleted'}),
    sduiAction(type: 'logout', url: '/login'),
  ]),
  title: 'Delete this account?',
  message: 'This permanently removes your data.',
  confirmLabel: 'Delete',
  destructive: true,
)
```

Tap → confirm dialog → on confirm, the sequence runs (toast, then logout clears session and navigates).

---

## Going further

Worth-doing items not yet implemented in this repo:

- **Cache with ETag + stale-while-revalidate + persistent disk cache** for offline-first.
- **Server-driven loading/empty/error skeletons** so each screen has its own shimmer.
- **Server-Sent Events** for live UI refresh.
- **a11y / i18n** — `props.semantic_label`, server reads `Accept-Language` and returns localized strings.

For the deeper architectural reasoning — when SDUI is worth the operational cost, where it tends to fall apart in production, common mitigations — see [SDUI_ARCHITECTURE_ARTICLE.md](SDUI_ARCHITECTURE_ARTICLE.md).

---

## License

MIT — see individual sub-packages for details.
