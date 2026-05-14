# SDUI Proj — Server-Driven UI in Dart

A reference implementation of **Server-Driven UI (SDUI)** in pure Dart: a [Dart Frog](https://dart-frog.dev) backend describes screens as JSON, and a Flutter client renders them as native widgets. Ship UI changes without releasing a new app build — change the server response and reload.

Routing, navigation targets, and even the app's entrypoint are decided by the server. The client knows nothing about specific screens.

```
┌──────────────────────────────┐          ┌──────────────────────────────┐
│ sdui_server  (Dart Frog API) │          │ sdui_project  (Flutter app)  │
│                              │          │                              │
│  GET  /         → 302 /login │   JSON   │  SDUIGenericPage             │
│  GET  /login    → form JSON  │ ───────► │    → SDUIApiService (HTTP)   │
│  POST /auth/login            │ ◄──────  │    → SDUIParser              │
│  GET  /home     → dashboard  │  action  │    → ComponentRegistry       │
│  GET  /products?page=N       │          │    → Flutter widgets         │
│  GET  /product/:id           │          │                              │
│  GET  /feed?page=N           │          │                              │
└──────────────────────────────┘          └──────────────────────────────┘
```

---

## Features

- **Fully server-driven routing** — Even the initial route is an HTTP 302 from `/`. No path-to-screen map lives in the client.
- **Generic component registry** — Add a new widget type by registering one builder; the parser dispatches by `type`.
- **JSON action protocol** — `navigate`, `form_submit`, `show_toast`, `network_request`, `pop`, `logout`. Forms validate locally, POST to the server, and run whatever action the server returns next.
- **Real auth & session** — `/auth/login` issues an HS256 JWT; the client persists it via `shared_preferences` and attaches `Authorization: Bearer …` on every request. Protected routes return a `401` carrying a `navigate /login` action.
- **Schema versioning** — Client sends `X-SDUI-Version`; server echoes its version and emits `X-SDUI-Deprecated` for stale clients. Server widgets can ship `fallback_type` so older clients render a back-compat shape instead of an "Unknown Component" banner.
- **Real pagination** — `LAZY_LIST` emits `nextUrl`; the client fetches more on scroll and stops when the server omits it.
- **Pull-to-refresh + cache** — Every screen has `RefreshIndicator`; pulling bypasses the in-memory cache.
- **Configurable base URL** — Point at any backend with `--dart-define=SDUI_BASE_URL=...`; sensible defaults for Android emulator, iOS sim, desktop, and web.
- **CORS-ready** — A global middleware adds permissive CORS so the Flutter web build works out of the box.
- **Contract test** — A Flutter test guards every server-emitted component type and asserts field locations (notably `INPUT_TEXT.id`) round-trip through the parser.
- **Single Dart stack** — Server and client share Dart 3, with the same component vocabulary on each side.

---

## Repo layout

```
sdui_proj/
├── sdui_server/                  # Dart Frog backend
│   ├── lib/
│   │   ├── sdui_builder.dart     # Server-side widget classes (toJson)
│   │   ├── sdui_actions.dart     # Action payload builder
│   │   └── auth.dart             # JWT sign/verify + AuthUser context
│   └── routes/
│       ├── _middleware.dart      # CORS + JWT auth + schema-version negotiation
│       ├── index.dart            # / → 302 entrypoint
│       ├── login/index.dart      # GET  login screen
│       ├── auth/login/index.dart # POST credential check (issues JWT)
│       ├── auth/me/index.dart    # GET  current user (JWT-protected)
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
│   │   │   ├── action_delegate.dart    # Action dispatch + real form POST
│   │   │   ├── sdui_input.dart
│   │   │   └── form_manager.dart
│   │   ├── components/                  # Concrete Flutter widgets
│   │   └── utils/style_parser.dart
│   ├── test/widget_test.dart            # Schema contract test
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

Point at a different backend:

```bash
flutter run --dart-define=SDUI_BASE_URL=https://sdui.example.com
```

### Test credentials

The mock login endpoint accepts a single account ([routes/auth/login/index.dart](sdui_server/routes/auth/login/index.dart)):

```text
username: demo@sdui.app
password: password
```

Any other credentials trigger an `Invalid credentials` toast (returned as a `show_toast` action by the server).

### Run the contract test

```bash
cd sdui_project
flutter test       # 7 tests — fails if the JSON schema drifts
```

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
| `props` | no | Component-specific properties (text, url, colors, sizes…). All component fields live here — never on the root node. |
| `children` | no | Nested SDUI nodes. |
| `action` | no | Tap action payload (see below). |

### Built-in component types

| `type` | Server class | Client widget | Key `props` |
| --- | --- | --- | --- |
| `VERTICAL_STACK` | `VerticalStack` | `Column` | — |
| `HORIZONTAL_SCROLL` | `HorizontalScroll` | Horizontal `SingleChildScrollView` | — |
| `CONTAINER` | `SDUIContainer` | `Container` | `padding`, `margin`, `backgroundColor`, `cornerRadius` |
| `TEXT` | `SDUIText` | `Text` | `text`, `style` (`title` / `subtitle` / `body`), `color` |
| `IMAGE` | `SDUIImage` | `Image.network` with fallback | `url`, `height`, `width` |
| `BUTTON_PRIMARY` | `ButtonPrimary` | Filled button | `label` |
| `INPUT_TEXT` | `InputText` | `TextField` registered in `FormManager` | `id`, `label`, `placeholder` |
| `LAZY_LIST` | `LazyList` | Paginated `ListView` | `nextUrl` (omitted on the last page) |

### Action payloads

```dart
sduiAction(type: 'navigate', url: '/product/1');
sduiAction(type: 'show_toast', data: {'message': 'Hello'});
sduiAction(type: 'form_submit', url: '/auth/login');
```

| Action | Effect on client |
|--------|------------------|
| `navigate` | `Navigator.pushNamed(url)` — `SDUIGenericPage` fetches that path from the server. |
| `pop` | `Navigator.pop()`. |
| `show_toast` | `SnackBar` from `data.message` (`is_error: true` → red). |
| `form_submit` | Validates inputs locally, POSTs the merged form data to `url`, displays `reply.message`, then dispatches whatever `reply.action` the server returns. If `reply.token` is present, the client persists it via `SessionStore`. |
| `logout` | Clears the persisted JWT + in-memory cache and navigates to `action.url` (default `/login`). |
| `network_request` | Fires an out-of-band HTTP call. |

**Server reply for `form_submit`** (login):

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6Ik...",
  "user": { "username": "demo@sdui.app" },
  "message": "Welcome, demo@sdui.app",
  "action": { "type": "navigate", "url": "/home" }
}
```

The server is authoritative — on success it returns a `navigate` action, on failure a `show_toast`. No `success_url` flag is needed on the client side.

---

## Auth & session

The server signs HS256 JWTs in [`lib/auth.dart`](sdui_server/lib/auth.dart). The secret comes from `SDUI_JWT_SECRET` (defaults to a dev value).

```bash
export SDUI_JWT_SECRET="some-long-random-string"   # for production
```

The global middleware ([`routes/_middleware.dart`](sdui_server/routes/_middleware.dart)) treats `/`, `/login`, and `/auth/login` as public; everything else requires a valid `Authorization: Bearer <jwt>` header. Failed checks return a `401` with an SDUI action the client runs:

```json
{
  "action": { "type": "navigate", "url": "/login" },
  "message": "Please sign in to continue"
}
```

End-to-end check from the terminal:

```bash
# 1. Hit a protected route — get 401 + recovery action
curl -s http://localhost:8080/home | jq

# 2. Log in, capture token
TOKEN=$(curl -s -X POST http://localhost:8080/auth/login \
  -H 'content-type: application/json' \
  -d '{"username":"demo@sdui.app","password":"password"}' | jq -r .token)

# 3. Re-hit the protected route with the token
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8080/home | jq

# 4. Inspect the authenticated user
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8080/auth/me
```

On the client, [`SessionStore`](sdui_project/lib/sdui/session_store.dart) wraps `shared_preferences`; `SDUIApiService._headers()` attaches the token automatically. A `401` raises `SDUIUnauthorizedException`, which `SDUIGenericPage` catches and forwards to the action delegate — typically navigating back to `/login`.

---

## Schema versioning

Every client request carries `X-SDUI-Version: 1`. The server echoes its own version in the response and, if the client is older than `_minSupportedClientVersion`, also sends `X-SDUI-Deprecated` with a human-readable nudge. `SDUIApiService.deprecationNotice` (a `ValueNotifier<String?>`) captures it so the app can surface a banner.

Server widgets can ship a back-compat shape for clients that don't yet know a new type:

```dart
class FuturisticCard extends SDUIWidget {
  FuturisticCard()
      : super(
          type: 'FUTURISTIC_CARD',
          props: {'glow': true},
          fallbackType: 'CONTAINER',
          fallbackProps: {'padding': 16, 'backgroundColor': '#ffffff'},
        );
}
```

If the client's `ComponentRegistry` has no `FUTURISTIC_CARD` builder, the parser uses `fallback_type` + `fallback_props` automatically and renders the older shape — no "Unknown Component" banner.

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

1. Add a class to [`sdui_builder.dart`](sdui_server/lib/sdui_builder.dart) extending `SDUIWidget`. Put all properties in `props`.
2. Register a builder in [`component_registry.dart`](sdui_project/lib/sdui/component_registry.dart):

   ```dart
   'YOUR_TYPE': (node) {
     final props = Map<String, dynamic>.from(node['props'] as Map? ?? {});
     return YourWidget(/* read from props */);
   },
   ```

3. Add a fixture to [`test/widget_test.dart`](sdui_project/test/widget_test.dart) so a future schema drift is caught.

The parser handles wiring, gesture wrapping, and action dispatch automatically.

---

## Project documentation

Additional implementation notes for AI agents and contributors live in [AGENTS.md](AGENTS.md). The two sub-package READMEs cover package-specific details:

- [`sdui_server/README.md`](sdui_server/README.md)
- [`sdui_project/README.md`](sdui_project/README.md)

---

## License

MIT — see individual sub-packages for details.
