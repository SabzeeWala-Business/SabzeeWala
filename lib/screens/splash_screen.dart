import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        final appState = Provider.of<AppState>(context, listen: false);
        if (appState.isAuthLoading || appState.isCatalogLoading) {
          late final VoidCallback listener;
          listener = () {
            if (!appState.isAuthLoading && !appState.isCatalogLoading && mounted) {
              appState.removeListener(listener);
              _navigate(appState);
            }
          };
          appState.addListener(listener);
        } else {
          _navigate(appState);
        }
      }
    });
  }

  void _navigate(AppState appState) {
    if (appState.userMobile != null && appState.userMobile!.isNotEmpty) {
      appState.setNavIndex(0);
      NotificationService.instance.syncTokenWithSupabase(appState.userMobile!);
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Image.asset(
        'assets/images/Splash_Screen.png',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}
