# Bubble Budget 🫧

A tactile, physics-driven mobile budget tracker built with Flutter. Bubble Budget reimagines personal finance as a "living" 2D canvas where your spending categories are interactive bubbles that grow, collide, and bounce.

## Key Features

- **🫧 Interactive Bubble Physics**: A custom-built 2D canvas engine with real-time collision detection, spring dynamics, elastic repulsion, and drag-and-fling interactions.
- **⚡ Rapid Quick-Entry**: A high-speed micro-modal with a custom numeric keypad, quick-increment chips, and calibrated native haptic feedback for frictionless logging.
- **🔒 Privacy-First & Local**: Powered by SQLite (`sqflite`), 100% offline-first. Your financial data stays on your device with zero tracking or third-party analytics.
- **📊 Optional Google Sheets Sync**: Self-bootstrapping live background Webhook synchronization. Log an expense and see it appear in your personal spreadsheet instantly.
- **🎨 Modern Dark UI**: Sleek dark-mode aesthetic with glassmorphism accents, a floating navigation dock, and dynamic theme tokens.
- **📁 1-Tap CSV Export**: Export your entire transaction history to a structured CSV file for deep analysis or backup.

## Architecture & Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (Dart)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Local Database**: [sqflite](https://pub.dev/packages/sqflite) + [path_provider](https://pub.dev/packages/path_provider)
- **Physics Engine**: Custom 2D Implementation (Ticker-driven)
- **Background Networking**: [http](https://pub.dev/packages/http)
- **Export & Sharing**: [csv](https://pub.dev/packages/csv), [share_plus](https://pub.dev/packages/share_plus), [url_launcher](https://pub.dev/packages/url_launcher)

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.13.0 or higher recommended)
- Dart SDK
- An Android or iOS device/emulator

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/bubble_budget.git
   cd bubble_budget
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the application**:
   ```bash
   flutter run
   ```

### Running Tests

Ensure system integrity with the built-in test suite:
```bash
flutter test
```

## Google Sheets Sync Setup Guide

Bubble Budget can automatically sync your expenses to a Google Sheet using a simple Apps Script "Webhook".

1. **Create a Spreadsheet**: Open a new Google Sheet.
2. **Deploy the Script**: Go to `Extensions > Apps Script`, paste the code from the `Setup Kit` (found in the app's Sync settings), and click `Deploy > New Deployment`.
3. **Connect**: Set access to "Anyone", copy the Web App URL, and paste it into the **Sync with Google Sheets** screen in Bubble Budget.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
