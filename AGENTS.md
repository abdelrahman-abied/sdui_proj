# SDUI Project — Agent Reference

Server-Driven UI (SDUI) system: a Dart Frog backend serves JSON UI definitions; a Flutter client renders them.

---

## Architecture

```
sdui_server (Dart Frog)          sdui_client (Flutter)
┌─────────────────────┐          ┌─────────────────────┐
│ Routes (HTTP)       │  JSON    │ SDUIPageLoader      │
│   /home             │ ──────►  │   → SDUIParser      │
│   /feed?page=N      │          │   → ComponentRegistry│
│   /product/[id]     │          │   → Flutter Widgets │
└─────────────────────┘          └─────────────────────┘
```

- **Server**: Builds UI trees with `sdui_builder.dart` widgets; returns `Response.json(body: widget.toJson())`.
- **Client**: Fetches JSON from endpoints, caches in SharedPreferences, parses with `SDUIParser`, renders via `ComponentRegistry`.

---

## Project Structure

| Path | Purpose |
|------|---------|
| `sdui_server/` | Dart Frog API; routes under `routes/` |
| `sdui_server/lib/sdui_builder.dart` | All server-side SDUI widget classes |
| `sdui_server/lib/sdui_actions.dart` | Helper for `action` payloads |
| `sdui_client/` | Flutter app |
| `sdui_client/lib/sdui_page_loader.dart` | Fetches JSON, cache, shimmer, parse |
| `sdui_client/lib/sdui/` | Parser, registry, actions, form manager |
| `sdui_client/lib/components/` | Flutter widgets for each SDUI type |

---

## JSON Schema (Server → Client)

Each node:

```json
{
  "type": "VERTICAL_STACK",
  "props": { ... },
  "children": [ { ... } ],
  "action": { "type": "navigate", "url": "/product/1" }
}
```

- **type** (required): Component type string.
- **props**: Component-specific properties.
- **children**: Nested SDUI nodes.
- **action** (optional): Tap action payload.

---

## Server-Side Widgets (`sdui_builder.dart`)

| Class | type | Key props |
|-------|------|-----------|
| `VerticalStack` | VERTICAL_STACK | — |
| `HorizontalScroll` | HORIZONTAL_SCROLL | — |
| `SDUIContainer` | CONTAINER | padding, margin, backgroundColor, cornerRadius |
| `SDUIText` | TEXT | text, style, color |
| `SDUIImage` | IMAGE | url, height |
| `ButtonPrimary` | BUTTON_PRIMARY | label |
| `InputText` | INPUT_TEXT | id, label, placeholder |
| `LazyList` | LAZY_LIST | nextUrl |

All extend `SDUIWidget` and implement `toJson()`.

---

## Adding a New Server Widget

1. Add class in `sdui_server/lib/sdui_builder.dart` extending `SDUIWidget`.
2. Set `type` and `props` in constructor.
3. Add route that returns `Response.json(body: widget.toJson())`.

---

## Adding a New Client Component

1. Create widget in `sdui_client/lib/components/` with `fromJson(Map<String, dynamic> json)`.
2. Register in `sdui_client/lib/sdui/component_registry.dart`:
   ```dart
   'YOUR_TYPE': (json) => YourWidget.fromJson(json),
   ```

---

## Actions

Use `sduiAction()` from `sdui_actions.dart`:

```dart
sduiAction(type: 'navigate', url: '/product/1')
sduiAction(type: 'show_toast', data: {'message': 'Hello'})
sduiAction(type: 'form_submit', url: '/cart/add', data: {'productId': '1'})
```

Client handles in `ActionDelegate`:

- **navigate**: `Navigator.pushNamed` with `url` path.
- **show_toast**: `ScaffoldMessenger.showSnackBar`.
- **form_submit**: `FormManager.submit()` + optional POST (currently logs only).

---

## Style Parsing (Client)

`StyleParser` in `utils/style_parser.dart`:

- `parseHexColor('#1a1a2e')` → Color
- `parsePadding(props)` / `parseMargin(props)` → EdgeInsets (single value → all sides)
- `parseBackgroundColor(props)` / `parseCornerRadius(props)`

---

## Routes

| Server | Client |
|--------|--------|
| `GET /home` | `/` → SDUIGenericPage(home) |
| `GET /feed?page=N` | `/feed` |
| `GET /product/:id` | `/product/{id}` |
| Fallback | `$_baseUrl$path` |

Client `main.dart` uses `onGenerateRoute`; `SDUIGenericPage` takes full endpoint URL.

---

## Conventions

- Server: Dart Frog; routes in `routes/`; `[id].dart` for path params.
- Client: Flutter; components use `fromJson`; `ComponentRegistry` maps type → builder.
- Colors: hex strings (e.g. `#1a1a2e`).
- Spacing: numeric `padding`/`margin` in props.
