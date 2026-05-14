# SDUI Proj — Server-Driven UI in Dart

A reference implementation of **Server-Driven UI (SDUI)** in pure Dart: a [Dart Frog](https://dart-frog.dev) backend describes screens as JSON, and a Flutter client renders them as native widgets. Ship UI changes without releasing a new app build — change the server response and reload.

Routing, navigation targets, and even the app's entrypoint are decided by the server. The client knows nothing about specific screens.

```
┌──────────────────────────────┐          ┌──────────────────────────────┐
│ sdui_server  (Dart Frog API) │          │ sdui_project  (Flutter app)  │
│                              │          │                              │
│  GET  /         → 302 /login │   JSON   │  SDUIGenericPage             │
│  GET  /login    → form JSON  │ ───────► │    → SDUIApiService (HTTP)   │
│  GET  /home     → dashboard  │          │    → SDUIParser              │
│  GET  /products?page=N       │ ◄──────  │    → ComponentRegistry       │
│  GET  /product/:id           │  action  │    → Flutter widgets         │
│  GET  /feed?page=N           │          │                              │
└──────────────────────────────┘          └──────────────────────────────┘
```

---

## Features

- **Fully server-driven routing** — Even the initial route is an HTTP 302 from `/`. No path-to-screen map lives in the client.
- **Generic component registry** — Add a new widget type by registering one builder; the parser dispatches by `type`.
- **JSON action protocol** — `navigate`, `form_submit`, `show_toast`, `network_request`, `pop`. Submitted forms read field IDs and validators from the same JSON tree.
- **Pagination primitive** — `LAZY_LIST` returns `nextUrl`, the client fetches more on scroll.
- **Single Dart stack** — Server and client share Dart 3, with the same component vocabulary on each side.

---

## Repo layout

```
sdui_proj/
├── sdui_server/                  # Dart Frog backend
│   ├── lib/
│   │   ├── sdui_builder.dart     # Server-side widget classes (toJson)
│   │   └── sdui_actions.dart     # Action payload builder
│   └── routes/
│       ├── index.dart            # / → 302 entrypoint
│       ├── login/index.dart
│       ├── home/index.dart
│       ├── products/index.dart
│       ├── product/[id].dart
│       └── feed/index.dart
│
├── sdui_project/                 # Flutter client
│   ├── lib/
│   │   ├── main.dart             # Generic onGenerateRoute
│   │   ├── sdui/
│   │   │   ├── sdui_page_loader.dart   # HTTP fetch + screen scaffold
│   │   │   ├── sdui_parser.dart        # Tree walker
│   │   │   ├── component_registry.dart # type → Widget builder map
│   │   │   ├── sdui_action.dart        # Action model
│   │   │   ├── action_delegate.dart    # Action dispatch
│   │   │   ├── sdui_input.dart
│   │   │   └── form_manager.dart
│   │   ├── components/                  # Concrete Flutter widgets
│   │   └── utils/style_parser.dart
│   └── pubspec.yaml
│
└── AGENTS.md                     # Developer reference for the SDUI contract
```

---

## Quick start

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

Sanity check:

```bash
curl -sIL http://localhost:8080/ | grep -iE "HTTP|location"
# HTTP/1.1 302 Found
# location: /login
# HTTP/1.1 200 OK
```

### 2. Run the client

```bash
cd sdui_project
flutter pub get
flutter run
```

> **Android emulator** reaches the host at `10.0.2.2:8080` (handled automatically in `SDUIApiService.baseUrl`).
> **iOS simulator / macOS / web** use `localhost:8080`. ATS, cleartext, and macOS sandbox `network.client` are pre-configured.

---

## The SDUI contract

Each node served by the backend has the shape:

```json
{
  "type": "VERTICAL_STACK",
  "props": { "padding": 16, "backgroundColor": "#1a1a2e" },
  "children": [ /* ... */ ],
  "action": { "type": "navigate", "url": "/product/1" }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `type` | yes | Component identifier — looked up in `ComponentRegistry`. |
| `props` | no | Component-specific properties (text, url, colors, sizes…). |
| `children` | no | Nested SDUI nodes. |
| `action` | no | Tap action payload (see below). |

### Built-in component types

| `type` | Server class | Client widget |
|--------|--------------|---------------|
| `VERTICAL_STACK` | `VerticalStack` | `Column` |
| `HORIZONTAL_SCROLL` | `HorizontalScroll` | Horizontal `SingleChildScrollView` |
| `CONTAINER` | `SDUIContainer` | `Container` + padding/margin/radius |
| `TEXT` | `SDUIText` | `Text` with style + color |
| `IMAGE` | `SDUIImage` | `Image.network` with fallback |
| `BUTTON_PRIMARY` | `ButtonPrimary` | Filled button |
| `INPUT_TEXT` | `InputText` | `TextField` registered in `FormManager` |
| `LAZY_LIST` | `LazyList` | Paginated `ListView` with `nextUrl` |

### Action payloads

```dart
sduiAction(type: 'navigate', url: '/product/1');
sduiAction(type: 'show_toast', data: {'message': 'Hello'});
sduiAction(
  type: 'form_submit',
  url: '/auth/login',
  successUrl: '/home',
  successMessage: 'Login successful',
);
```

| Action | Effect on client |
|--------|------------------|
| `navigate` | `Navigator.pushNamed(url)` — `SDUIGenericPage` fetches that path from the server. |
| `pop` | `Navigator.pop()`. |
| `show_toast` | Snackbar from `data.message`. |
| `form_submit` | Validates inputs, POSTs (mock today), then navigates to `success_url`. |
| `network_request` | Fires an out-of-band HTTP call. |

---

## Extending the system

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

1. Add a class to [`sdui_builder.dart`](sdui_server/lib/sdui_builder.dart) extending `SDUIWidget`.
2. Register a builder in [`component_registry.dart`](sdui_project/lib/sdui/component_registry.dart):
   ```dart
   'YOUR_TYPE': (node) => YourWidget.fromJson(node),
   ```

The parser handles wiring, style parsing, and action dispatch automatically.

---

## Project documentation

Additional implementation notes for AI agents and contributors live in [AGENTS.md](AGENTS.md). The two sub-package READMEs cover package-specific details:

- [`sdui_server/README.md`](sdui_server/README.md)
- [`sdui_project/README.md`](sdui_project/README.md)

---

## License

MIT — see individual sub-packages for details.
