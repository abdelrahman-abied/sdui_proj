# SDUI Project — Server-Driven UI for Flutter

A Flutter implementation of **Server-Driven UI (SDUI)** that renders native Flutter widgets from JSON definitions. Update your app's screens and layouts without shipping a new app release—just change the JSON from your backend.

## Features

- **JSON-driven UI** — Define screens, layouts, and components entirely in JSON
- **Deep linking** — Route-based navigation (`/login`, `/products`, `/product/123`)
- **Form handling** — Text inputs with validation (required, regex) and form submission
- **Actions** — Navigate, show toast, form submit, network requests, pop
- **Extensible registry** — Add new component types via `ComponentRegistry`
- **Style parsing** — Colors, padding, margin, corner radius from JSON

## Quick Start

```bash
# Get dependencies
flutter pub get

# Run the app
flutter run
```

The app starts at `/login`. Use the in-app navigation or deep links to explore screens.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────────┐
│  JSON (API/     │────▶│  SDUIParser      │────▶│  ComponentRegistry  │
│  Assets)        │     │  (recursive)     │     │  (type → Widget)    │
└─────────────────┘     └──────────────────┘     └─────────────────────┘
         │                        │
         │                        ▼
         │               ┌──────────────────┐
         └──────────────▶│  ActionDelegate  │  (navigate, form_submit, etc.)
                         └──────────────────┘
```

- **SDUIGenericPage** — Loads JSON for an endpoint and renders the `ui_tree`
- **SDUIParser** — Recursively parses JSON nodes into Flutter widgets
- **ComponentRegistry** — Maps component `type` strings to widget builders
- **SDUIActionDelegate** — Handles taps and actions (navigation, forms, etc.)

## Project Structure

```
lib/
├── main.dart                 # App entry, routing (onGenerateRoute)
├── sdui/
│   ├── sdui_page_loader.dart # SDUIGenericPage, MockNetworkService
│   ├── sdui_parser.dart      # JSON → Widget parsing
│   ├── component_registry.dart # Component type → builder map
│   ├── sdui_action.dart      # Action model (navigate, form_submit, etc.)
│   ├── action_delegate.dart  # Action handlers
│   ├── form_manager.dart     # Form state, validation, export
│   └── sdui_input.dart       # SDUITextInput (validated inputs)
├── components/
│   ├── sdui_components.dart  # Header, Banner, ProductCard
│   ├── sdui_container.dart   # Generic container with style
│   ├── sdui_grid.dart        # Grid layout
│   └── sdui_lazy_list.dart   # Lazy-loading list
└── utils/
    └── style_parser.dart     # Colors, insets, decoration from JSON

assets/sdui/
├── login.json
├── home.json
├── products.json
└── product_details.json
```

## JSON Structure

Each screen JSON has:

```json
{
  "screen_title": "Page Title",
  "ui_tree": {
    "type": "VERTICAL_STACK",
    "children": [
      {
        "type": "TEXT",
        "props": { "text": "Hello" },
        "style": { "font_size": 18, "font_weight": "bold" }
      },
      {
        "type": "BUTTON_PRIMARY",
        "props": { "label": "Submit" },
        "action": {
          "type": "navigate",
          "url": "/home"
        }
      }
    ]
  }
}
```

## Available Components

| Type | Description |
|------|-------------|
| `VERTICAL_STACK` | Column of children |
| `CONTAINER` | Box with padding, margin, background, corner radius |
| `GRID_2_COL` | 2-column grid |
| `TEXT` | Text with style (font_size, color, font_weight) |
| `HEADER` | Title + icon row |
| `BANNER_CARD` | Full-width image banner |
| `PRODUCT_CARD` | Product name + price card |
| `BUTTON_PRIMARY` | Primary button with optional action |
| `INPUT_TEXT` | Text field with label, validation, placeholder |
| `LAZY_LIST` | Scrollable list with lazy loading |

## Supported Actions

Attach an `action` object to any component to make it tappable:

| Action | Description | Example |
|--------|-------------|---------|
| `navigate` | Push named route | `{ "type": "navigate", "url": "/products" }` |
| `form_submit` | Validate form, submit, then navigate | `{ "type": "form_submit", "url": "...", "success_url": "/home" }` |
| `show_toast` | Show SnackBar | `{ "type": "show_toast", "data": { "message": "Done!" } }` |
| `network_request` | API call (mocked) | `{ "type": "network_request", "url": "..." }` |
| `pop` | Pop current route | `{ "type": "pop" }` |

## Style Properties

Components with a `style` object support:

- `padding`, `padding_top`, `padding_bottom`, etc.
- `margin`, `margin_top`, etc.
- `background_color` — hex string (e.g. `"#2196F3"`)
- `corner_radius` — double
- `font_size`, `font_weight`, `color` — for TEXT

## Adding a New Component

1. Create the widget (e.g. in `components/`).
2. Register it in `component_registry.dart`:

```dart
'MY_COMPONENT': (node) => MyComponent(
  title: node['props']['title'],
  // ...
),
```

3. Use it in your JSON:

```json
{ "type": "MY_COMPONENT", "props": { "title": "Hello" } }
```

## Adding a New Screen

1. Add a JSON file under `assets/sdui/`.
2. Register the endpoint in `MockNetworkService._endpointToAsset` in `sdui_page_loader.dart`.
3. Add a route in `main.dart` `onGenerateRoute` if needed.

## Replacing Mock with Real API

Replace `MockNetworkService.getJsonForEndpoint` with your HTTP client:

```dart
// Example: fetch from API
final response = await http.get(Uri.parse('https://api.example.com/sdui/$endpoint'));
final json = jsonDecode(response.body) as Map<String, dynamic>;
return json;
```

## Requirements

- Flutter SDK ^3.10.8
- Dart ^3.10.8
