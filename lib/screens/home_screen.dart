import 'package:flutter/material.dart';
import '../constants/app_strings.dart';

/// Écran d'accueil/tableau de bord
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(AppStrings.appTagline),
            SizedBox(height: 16),
            Text('Bienvenue dans TontineChain'),
          ],
        ),
      ),
    );
  }
}
