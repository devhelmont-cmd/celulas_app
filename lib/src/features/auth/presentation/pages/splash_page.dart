import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/core/utils/fade_page_route.dart';
import 'package:celulas_app/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:celulas_app/src/features/auth/presentation/controllers/auth_state.dart';
import 'package:celulas_app/src/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';

import '../../../home/presentation/pages/home_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  final _authController = getIt<AuthController>();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    _initializeSplash();

    /*WidgetsBinding.instance.addPostFrameCallback((_) {
      _authController.checkCurrentUser();
    });*/
  }

  Future<void> _initializeSplash() async {
    await Future.wait([
      _authController.checkCurrentUser(),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);

    if (!mounted) return;

    final state = _authController.value;

    if (state is AuthSuccessState) {
      _navigateTo(HomePage(user: state.user));
    } else if (state is AuthInitialState || state is AuthErrorState) {
      _navigateTo(const LoginPage());
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    //_authController.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _navigateTo(Widget page) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(FadePageRoute(page: page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Icon(
                  Icons.church_rounded,
                  size: 90,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
