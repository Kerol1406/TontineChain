import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/index.dart';
import 'providers/index.dart';
import 'screens/index.dart';
import 'theme/index.dart';

// Services
import 'services/mock_auth_service.dart';
import 'services/auth_state.dart';

import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await MockAuthService.instance.loadSeedUsers();
  runApp(TontineChainApp());
}

class TontineChainApp extends StatelessWidget {
  const TontineChainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TontineProvider()),
        ChangeNotifierProvider(create: (_) => AuthState()),
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const OnboardingScreen(),
        routes: {
          '/app': (_) => const AppShell(),
        },
      ),
    );
  }
}
