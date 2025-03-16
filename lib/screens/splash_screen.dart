import 'package:flutter/material.dart';
import 'package:ride_along/screens/supabase_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeLogoAnimation;
  late Animation<double> _fadeTitleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize the AnimationController with a 4-second duration
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    // Slide animation for logo: Moves from right (1.0) to left (-1.0)
    _slideAnimation = Tween<double>(begin: 1.5, end: -1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    // Fade out animation for logo
    _fadeLogoAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.5, curve: Curves.easeOut),
      ),
    );

    // Fade in animation for title
    _fadeTitleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.75, curve: Curves.easeIn),
      ),
    );

    // Start the animation
    _controller.forward();

    // Navigate to SupabaseGate after animation completes
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SupabaseGate()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Logo animation
                Transform.translate(
                  offset: Offset(
                    _slideAnimation.value *
                        MediaQuery.of(context).size.width *
                        0.5,
                    0,
                  ),
                  child: FadeTransition(
                    opacity: _fadeLogoAnimation,
                    child: Image.asset(
                      'assets/blue_logo.png',
                      width: 150,
                      height: 150,
                    ),
                  ),
                ),
                // Title animation
                FadeTransition(
                  opacity: _fadeTitleAnimation,
                  child: const Text(
                    'Ride Along',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue, // Adjust color as needed
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
