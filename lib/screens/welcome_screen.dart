import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _bounceController;
  final AudioService _audio = AudioService();

  bool _showMicroToast = false;
  double _microToastOpacity = 0.0;
  double _microToastYOffset = 0.0;

  // Reached only before the user can open Settings, so this screen is dark by
  // construction rather than by relying on the app's default ThemeMode.
  static final ThemeData _theme = AppTheme.darkTheme;

  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Colors.white70;
  static const Color _textTertiary = Color(0x99FFFFFF);
  // The same fill the privacy screen's CTA uses, so onboarding closes on the
  // note it opened on. White on it is 5.1:1. (This was cream while the orb was
  // coral - "orb owns colour, button owns brightness" - but that argument died
  // when the orb became violet.)
  static const Color _ctaFill = Color(0xFF2563EB);
  static const Color _ctaLabel = Colors.white;

  static const SystemUiOverlayStyle _overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarIconBrightness: Brightness.light,
  );

  // Pure black, matching AppTheme.darkTheme's scaffoldBackgroundColor and the
  // privacy screen before it, so the two onboarding screens read as one space.
  // The teal-black gradient this replaces was chosen as coral's complement;
  // with a violet orb it only cast a green tint. The orb's own violet bloom
  // supplies the atmosphere.
  static const Color _ground = Color(0xFF000000);

  @override
  void initState() {
    super.initState();
    // Idle float controller (sine wave movement)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    // Scale elastic bounce controller on tap
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.8,
      upperBound: 1.3,
    );
    _bounceController.value = 1.0; // Starts at normal scale
  }

  @override
  void dispose() {
    _floatController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _handleBubbleTap() {
    HapticFeedback.lightImpact();
    _audio.triggerHapticLight();
    _audio.playTap();

    // Elastic pop animation
    _bounceController.forward(from: 0.8).then((_) {
      _bounceController.animateTo(1.0, curve: Curves.easeOut);
    });

    // Animate the upward micro-toast float & fade
    setState(() {
      _showMicroToast = true;
      _microToastOpacity = 1.0;
      _microToastYOffset = 0.0;
    });

    // Slide up and fade out over 800ms
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _microToastYOffset = -40.0;
          _microToastOpacity = 0.0;
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showMicroToast = false;
        });
      }
    });
  }

  void _handleLetRoll() {
    HapticFeedback.mediumImpact();
    _audio.triggerHapticHeavy();
    _audio.playSuccess();

    // Persist seen status so it never loads again
    final settings = SettingsService();
    settings.hasSeenWelcome = true;

    // Use a high-polish scaled-fade navigation transition to HomeScreen
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fadeTween = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          );
          final scaleTween = Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          );
          return FadeTransition(
            opacity: fadeTween,
            child: ScaleTransition(
              scale: scaleTween,
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _overlay,
        child: Scaffold(
          body: ColoredBox(
            color: _ground,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    // 1. Top 45%: Hero Stage (Floating sample bubble + micro-toast)
                    Expanded(
                      flex: 45,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Never larger than the original 190, never larger than
                          // the space it actually has. On every normal phone this
                          // resolves to 190; it only shrinks where the old fixed
                          // size would have overflowed.
                          final double fits = math.min(
                            constraints.maxHeight * 0.86,
                            constraints.maxWidth * 0.58,
                          );
                          final double orbSize = fits > 190.0 ? 190.0 : fits;

                          return Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Floating & bouncing coral bubble
                                AnimatedBuilder(
                                  animation: Listenable.merge([_floatController, _bounceController]),
                                  builder: (context, child) {
                                    final floatOffset = math.sin(_floatController.value * math.pi * 2) * 12.0;
                                    return Transform.translate(
                                      offset: Offset(0, floatOffset),
                                      child: Transform.scale(
                                        scale: _bounceController.value,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: GestureDetector(
                                    onTap: _handleBubbleTap,
                                    child: _buildOrb(orbSize),
                                  ),
                                ),

                                // Micro-toast Floating Badge
                                if (_showMicroToast)
                                  AnimatedBuilder(
                                    animation: _floatController,
                                    builder: (context, child) {
                                      final floatOffset = math.sin(_floatController.value * math.pi * 2) * 12.0;
                                      return Transform.translate(
                                        offset: Offset(
                                          0,
                                          floatOffset - (orbSize / 2) - 15.0 + _microToastYOffset,
                                        ),
                                        child: child,
                                      );
                                    },
                                    child: AnimatedOpacity(
                                      opacity: _microToastOpacity,
                                      duration: const Duration(milliseconds: 600),
                                      curve: Curves.easeOut,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        // Emerald, not the old teal: teal was
                                        // chosen to match a teal CTA and a
                                        // teal-black ground, and both are gone.
                                        // White on #047857 is 5.5:1.
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF047857),
                                          borderRadius: BorderRadius.all(Radius.circular(999)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0x66047857),
                                              blurRadius: 16,
                                              offset: Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: const Text(
                                          '+\$5.00 logged!',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // 2. Middle 35%: Typography Block (BELOW the hero stage)
                    Expanded(
                      flex: 35,
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Welcome to Bubble Budget',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _textPrimary,
                                letterSpacing: -0.4,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 340),
                              child: const Text(
                                'Budgeting without the friction. Just tap a bubble to log an expense.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  color: _textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 340),
                              child: const Text(
                                '100% private and offline. Optionally syncs straight to your own Google Sheet for deep financial clarity.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _textTertiary,
                                  height: 1.45,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 3. Bottom 20%: Anchored CTA
                    Expanded(
                      flex: 20,
                      child: Center(
                        child: SizedBox(
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.all(Radius.circular(30)),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x522563EB),
                                  blurRadius: 18,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _handleLetRoll,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _ctaFill,
                                foregroundColor: _ctaLabel,
                                minimumSize: const Size(double.infinity, 60),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(30)),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "Understood. Let's roll!",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _ctaLabel,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Iridescent soap-bubble orb. A sweep gradient lays down the oil-slick sheen;
  // the violet body sits over it and fades toward the rim, so the iridescence
  // reads only where a real bubble shows it - around the edge. Same three-pass
  // logic as the canvas painter: ambient glow, curved body, specular highlight.
  Widget _buildOrb(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        // Pass 1 of the surface: the oil-slick sweep.
        gradient: SweepGradient(
          colors: [
            Color(0xFF38BDF8), // sky
            Color(0xFFA78BFA), // violet
            Color(0xFFF472B6), // pink
            Color(0xFFFBBF24), // amber
            Color(0xFF34D399), // emerald
            Color(0xFF38BDF8), // back to sky, so the seam is invisible
          ],
          stops: [0.0, 0.20, 0.42, 0.62, 0.82, 1.0],
        ),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0x33FFFFFF), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x4D7C3AED),
            blurRadius: 44,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pass 2: violet body, deliberately transparent at the outer stop so
            // the sweep beneath it survives as a rim of colour.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(-0.32, -0.38),
                    radius: 0.95,
                    colors: [
                      Color(0xFFCBB2FF), // specular glint
                      Color(0xFF9A6BFA), // upper body
                      Color(0xE64C1D95), // lower body, slightly translucent
                      Color(0x4D2E1065), // rim: mostly clear, sheen shows through
                    ],
                    stops: [0.0, 0.30, 0.70, 1.0],
                  ),
                ),
              ),
            ),

            // Pass 3: specular catch-light.
            Positioned(
              left: size * 0.18,
              top: size * 0.15,
              child: Transform.rotate(
                angle: -0.42,
                child: Container(
                  width: size * 0.34,
                  height: size * 0.22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(
                      Radius.elliptical(size * 0.17, size * 0.11),
                    ),
                    gradient: const RadialGradient(
                      colors: [Color(0x99FFFFFF), Color(0x00FFFFFF)],
                      stops: [0.0, 0.72],
                    ),
                  ),
                ),
              ),
            ),

            // Padded so the label wraps inside the sphere instead of being
            // clipped by the ClipOval at large Dynamic Type.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.16),
              child: const Text(
                'Tap Me!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                  shadows: [
                    Shadow(
                      color: Color(0x66000000),
                      blurRadius: 8,
                      offset: Offset(0, 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
