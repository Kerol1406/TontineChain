import 'package:flutter/material.dart';
import 'package:tontinechain/constants/app_colors.dart';
import 'package:tontinechain/widgets/common_button.dart';
import 'package:provider/provider.dart';
import 'package:tontinechain/services/auth_state.dart';
import 'package:tontinechain/services/firebase_auth_service.dart';
import 'package:tontinechain/services/firestore_database_service.dart';
import 'auth_screen.dart';
import 'otp_verification_screen.dart';
import 'app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  late List<TextEditingController> _otpControllers;

  late Duration _remainingTime;
  String? _verificationId;

  bool _isLoading = false;
  bool _showPassword = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _otpControllers = List.generate(6, (_) => TextEditingController());
    _remainingTime = Duration(seconds: 55);
    _startOtpTimer();
  }

  void _startOtpTimer() {
    Future.delayed(Duration(seconds: 1), () {
      if (mounted && _currentStep == 1) {
        setState(() {
          if (_remainingTime.inSeconds > 0) {
            _remainingTime =
                Duration(seconds: _remainingTime.inSeconds - 1);
            _startOtpTimer();
          }
        });
      }
    });
  }

  bool get _isCredentialsValid =>
      _phoneController.text.isNotEmpty &&
      _passwordController.text.isNotEmpty;

  bool get _isOtpComplete =>
      _otpControllers.every((c) => c.text.isNotEmpty);

  String _formatTime(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds.remainder(60))}';
  }

  void _handleConnectClick() async {
    if (!_isCredentialsValid) return;

    setState(() => _isLoading = true);

    print('\n========== LOGIN ATTEMPT ==========');
    print('📱 Téléphone: ${_phoneController.text.trim()}');
    print('🔒 Mot de passe: ${_passwordController.text.length} caractères');

    // Appel Firebase Auth pour la connexion (email/password via resolved phone->email)
    final result = await FirebaseAuthService().login(
      identifier: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    print('📊 Résultat login: ${result['success']} - ${result['error']}');

    if (result['success'] == true) {
      final profile = result['profile'] as Map<String, dynamic>?;
      final phone = (profile != null && profile['phone'] != null)
          ? profile['phone'] as String
          : _phoneController.text.trim();

      print('✅ Première étape réussie, navigation vers OTP...');
      
      final otpResult = await Navigator.of(context).push<Map<String, String>>(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(phoneNumber: phone),
        ),
      );

      if (!mounted) return;

      if (otpResult == null) {
        print('⚠️  OTP annulé par l\'utilisateur');
        setState(() => _isLoading = false);
        return;
      }

      print('📱 OTP reçu, vérification...');

      final reauth = await FirebaseAuthService().reauthenticateWithPhone(
        verificationId: otpResult['verificationId'] ?? '',
        smsCode: otpResult['smsCode'] ?? '',
        expectedPhone: phone,
      );

      if (reauth['success'] == true) {
        print('✅ OTP vérifié, authentification complète!');
        setState(() => _isLoading = false);

        final auth = Provider.of<AuthState>(context, listen: false);
        final profile = result['profile'] as Map<String, dynamic>?;
        auth.setUser({
          'uid': result['uid'],
          ...?profile,
          'email': profile?['email'] ?? result['email'],
          'displayName': profile?['displayName'] ?? result['displayName'],
          'phone': profile?['phone'] ?? phone,
          'phoneNumber': profile?['phone'] ?? phone,
          'role': 'user',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connexion réussie!'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppShell()),
        );
      } else {
        print('❌ OTP échoué: ${reauth['error']}');
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reauth['error'] ?? 'Échec de la vérification'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } else {
      print('❌ Première étape échouée: ${result['error']}');
      print('   Code: ${result['code']}');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Erreur de connexion'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _handleVerifyOtp() async {
    if (!_isOtpComplete) return;

    setState(() => _isLoading = true);

    final verificationId = _verificationId;
    if (verificationId == null || verificationId.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La vérification OTP n\'a pas été initialisée.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final smsCode = _otpControllers.map((c) => c.text.trim()).join();
    final reauth = await FirebaseAuthService().reauthenticateWithPhone(
      verificationId: verificationId,
      smsCode: smsCode,
      expectedPhone: _phoneController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (reauth['success'] == true) {
      final auth = Provider.of<AuthState>(context, listen: false);
      final profile = FirebaseAuthService().currentUser == null
          ? null
          : await FirestoreDatabaseService.instance
              .getUserProfile(FirebaseAuthService().currentUser!.uid);
      auth.setUser({
        'uid': FirebaseAuthService().currentUser?.uid,
        ...?profile,
        'email': profile?['email'] ?? FirebaseAuthService().currentUser?.email,
        'displayName': profile?['displayName'] ?? FirebaseAuthService().currentUser?.displayName,
        'phone': profile?['phone'] ?? _phoneController.text.trim(),
        'phoneNumber': profile?['phone'] ?? _phoneController.text.trim(),
        'role': 'user',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connexion réussie!'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reauth['error'] ?? 'Échec de la vérification'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ================= HEADER CORRIGÉ =================
  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(top: 60, bottom: 120),
          decoration: BoxDecoration(
            color: AppColors.neutral,
            image: DecorationImage(
              image: AssetImage('assets/images/pattern_bg.png'),
              fit: BoxFit.cover,
              opacity: 0.15,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance,
                  color: AppColors.secondary,
                  size: 32,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'TONTINECHAIN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),

        Positioned(
          bottom: -60,
          left: 24,
          right: 24,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              image: DecorationImage(
                image: AssetImage(
                    'assets/images/portefeuille_connexion.png'),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bon retour',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Connectez-vous pour gérer vos tontines',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral,
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_currentStep == 0) _buildHeader(),

            if (_currentStep == 0) SizedBox(height: 80),

            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: _currentStep == 0
                  ? _buildCredentialsStep()
                  : _buildOtpStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),

        // PHONE
        Text('NUMÉRO DE TÉLÉPHONE'),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                child: Text('+229'),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    hintText: '00 00 00 00',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 24),

        // PASSWORD
        Text('MOT DE PASSE'),
        SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: Icon(Icons.lock),
            suffixIcon: GestureDetector(
              onTap: () =>
                  setState(() => _showPassword = !_showPassword),
              child: Icon(_showPassword
                  ? Icons.visibility
                  : Icons.visibility_off),
            ),
          ),
        ),

        SizedBox(height: 16),

        Align(
          alignment: Alignment.centerRight,
          child: Text('Mot de passe oublié ?'),
        ),

        SizedBox(height: 32),

        // Bouton toujours cliquable pour tester l'écran OTP
        CommonButton(
          label: 'SE CONNECTER',
          isLoading: _isLoading,
          onPressed: _handleConnectClick,
          backgroundColor: AppColors.primary,
          textColor: Colors.white,
        ),

        SizedBox(height: 24),

        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Pas encore membre ? ',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RegisterScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Créer un compte',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

Widget _buildOtpStep() {
  double screenWidth = MediaQuery.of(context).size.width;

  // Taille dynamique pour éviter overflow
  double boxSize = (screenWidth - 80) / 6;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SizedBox(height: 20),

      Text(
        'Vérification',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),

      SizedBox(height: 12),

      Text(
        'Veuillez saisir le code à 6 chiffres envoyé\npar SMS',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),

      SizedBox(height: 8),

      TextButton(
        onPressed: () async {
          final phone = _phoneController.text.trim();
          if (phone.isEmpty) return;
          setState(() => _isLoading = true);
          try {
            final verificationId = await FirebaseAuthService().sendPhoneVerificationCode(phone);
            if (!mounted) return;
            setState(() {
              _verificationId = verificationId;
              _remainingTime = const Duration(seconds: 55);
              _isLoading = false;
            });
            _startOtpTimer();
            for (final controller in _otpControllers) {
              controller.clear();
            }
          } catch (e) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Impossible de renvoyer le code: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        child: const Text('Renvoyer le code'),
      ),

      SizedBox(height: 40),

      // 🔥 OTP RESPONSIVE (CORRIGÉ)
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (index) {
          return SizedBox(
            width: boxSize,
            height: boxSize,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _otpControllers[index].text.isNotEmpty
                      ? AppColors.primary
                      : AppColors.divider,
                  width: 2,
                ),
              ),
              child: TextField(
                controller: _otpControllers[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    FocusScope.of(context).nextFocus();
                  } else if (value.isEmpty && index > 0) {
                    FocusScope.of(context).previousFocus();
                  }
                  setState(() {});
                },
                decoration: InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }),
      ),

      SizedBox(height: 32),

      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time,
              size: 18, color: AppColors.secondary),
          SizedBox(width: 8),
          Text(
            'RENVOYER DANS ${_formatTime(_remainingTime)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),

      SizedBox(height: 32),

      CommonButton(
        label: 'Vérifier le code',
        isLoading: _isLoading,
        onPressed: _isOtpComplete ? _handleVerifyOtp : () {},
        backgroundColor: AppColors.primary,
        textColor: Colors.white,
      ),
    ],
  );
}
  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    super.dispose();
  }
}