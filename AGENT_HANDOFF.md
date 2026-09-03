Project Brief & Architecture: Bubble Budget
Bubble Budget is an offline-first, tactile personal budgeting app for Android and iOS built with Flutter. Instead of spreadsheets or dense tables, spending categories are represented as organic, physics-driven floating bubbles where volume/size directly reflects financial allocation or tap-frequency.

Framework & Engine: Flutter 3.x (Dart), targeting Android 13+ (predictive back gesture compliant) and iOS 16+.

Local Storage: SQLite (sqflite) for all transactions and category configs.

Optional Cloud Sync: Google Sheets via a personal Google Apps Script Webhook (account-free, offline-first).

Key State Flags (SharedPreferences):

has_accepted_privacy: Governs entry to the privacy commitment screen.

has_seen_welcome: Governs entry to the interactive hero bubble bridge.

Current Linear Onboarding Flow
[Clean Install]
       │
       ▼
1. PrivacyOnboardingScreen (lib/screens/privacy_onboarding_screen.dart)
   - Shield header wrapped in Flexible (iPhone XR overflow-safe).
   - 3 value pillars (Local SQLite, Optional Sheets Sync, Account-Free).
   - Hyperlink to full TermsScreen(isOnboarding: false).
   - "Agree and Continue" button -> sets has_accepted_privacy = true.
       │  (pushReplacement)
       ▼
2. WelcomeScreen (lib/screens/welcome_screen.dart)
   - Top 45%: Substantial 190px interactive coral bubble with 3D depth and float physics.
   - Tap behavior: elastic bounce, light haptics, "+$5.00 logged!" floating toast.
   - Middle 35%: Clean typography block with generous line height.
   - Bottom 20%: Pinned CTA button ("Understood. Let's roll!") -> sets has_seen_welcome = true.
       │  (pushReplacement)
       ▼
3. HomeScreen (lib/main.dart / lib/widgets/bubble_canvas.dart)
   - Physics-driven 3-pass custom painter for bubbles:
     * Pass 1: Dynamic colored ambient under-glow for Dark Mode (`baseColor.withOpacity(0.24)`), black shadow for Light Mode.
     * Pass 2: Radial gradient with specular top-left highlight (0.62 factor) and contoured bottom shading.
     * Pass 3: Crisp glass rim catch-light (18% white stroke).
   - Collision throttle capped at 10 simultaneous audio triggers to prevent engine overload.
   - Startup scatter-and-settle shuffle animation.
   - Subsequent launches bypass screens 1 & 2 directly to this canvas.
