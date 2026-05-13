import 'package:flutter/material.dart';
import 'package:tontinechain/constants/app_colors.dart';
import 'package:tontinechain/services/firebase_auth_service.dart';
import 'package:tontinechain/widgets/common_button.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  late final List<TextEditingController> _otpControllers;
  late Duration _remainingTime;

  bool _isLoading = false;
  bool _isSendingCode = true;
  String? _verificationId;

  @override
  void initState() {
    super.initState();
    _otpControllers = List.generate(6, (_) => TextEditingController());
    _remainingTime = const Duration(seconds: 55);
    _sendCode();
  }

  Future<void> _sendCode() async {
    setState(() => _isSendingCode = true);

    try {
      final verificationId = await FirebaseAuthService().sendPhoneVerificationCode(widget.phoneNumber);
      if (!mounted) return;

      setState(() {
        _verificationId = verificationId;
        _remainingTime = const Duration(seconds: 55);
        _isSendingCode = false;
      });

      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingCode = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'envoyer le code OTP: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _remainingTime.inSeconds <= 0) {
        return;
      }

      setState(() {
        _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
      });

      _startTimer();
    });
  }

  String _formatTime(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds.remainder(60))}';
  }

  bool get _isOtpComplete => _otpControllers.every((c) => c.text.trim().isNotEmpty);

  void _handleVerify() {
    if (_verificationId == null || !_isOtpComplete) return;

    final smsCode = _otpControllers.map((c) => c.text.trim()).join();
    Navigator.of(context).pop<Map<String, String>>({
      'verificationId': _verificationId!,
      'smsCode': smsCode,
    });
  }

  @override
  void dispose() {
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boxSize = (screenWidth - 80) / 6;

    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        backgroundColor: AppColors.neutral,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Vérification OTP'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Vérification',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Veuillez saisir le code à 6 chiffres envoyé\nau ${widget.phoneNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _isSendingCode ? null : _sendCode,
                child: Text(_isSendingCode ? 'Envoi en cours...' : 'Renvoyer le code'),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: boxSize,
                    height: boxSize,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _otpControllers[index].text.isNotEmpty
                              ? AppColors.primary
                              : AppColors.divider,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _otpControllers[index],
                        textAlign: TextAlign.center,
                        textAlignVertical: TextAlignVertical.center,
                        cursorColor: AppColors.primary,
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
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time, size: 18, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Text(
                    'RENVOYER DANS ${_formatTime(_remainingTime)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              CommonButton(
                label: 'Vérifier le code',
                isLoading: _isLoading || _isSendingCode,
                onPressed: _handleVerify,
                backgroundColor: AppColors.primary,
                textColor: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}