import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // soft, subtle radial gradient teal/white for high-end consumer aesthetic
    final backgroundGradient = RadialGradient(
      center: Alignment.center,
      radius: 1.2,
      colors: isDark
          ? const [Color(0xFF0F2626), Color(0xFF070B0B)]
          : const [Color(0xFFE0F2F1), Color(0xFFFFFFFF)],
    );

    final textPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF4B5563);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. Onboarding Copywriting
                Column(
                  children: [
                    const SizedBox(height: 32),
                    Text(
                      'Welcome to Bubble Budget',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Budgeting without the friction. Just tap a bubble to log an expense.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '100% private and offline. Optionally syncs straight to your own Google Sheet for deep financial clarity.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary.withOpacity(0.65),
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),

                // 2. The Hero Interactive Bubble Area
                Expanded(
                  child: Center(
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
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Color(0xFFFF8A65), // Coral sheen
                                    Color(0xFFFF5722), // Main Coral
                                    Color(0xFFE64A19), // Shadow coral
                                  ],
                                  center: Alignment(-0.25, -0.25),
                                  radius: 0.9,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 16,
                                    offset: Offset(0, 8),
                                  )
                                ],
                              ),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Tap Me!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '☕',
                                      style: TextStyle(
                                        fontSize: 26,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Micro-toast Floating Badge
                        if (_showMicroToast)
                          AnimatedBuilder(
                            animation: _floatController,
                            builder: (context, child) {
                              final floatOffset = math.sin(_floatController.value * math.pi * 2) * 12.0;
                              return Transform.translate(
                                offset: Offset(0, floatOffset - 90.0 + _microToastYOffset),
                                child: child,
                              );
                            },
                            child: AnimatedOpacity(
                              opacity: _microToastOpacity,
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOut,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    )
                                  ],
                                ),
                                child: const Text(
                                  '+\$5.00 logged!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // 3. Tactile CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D9488).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _handleLetRoll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488), // Vibrant teal
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        "Understood. Let's roll!",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}