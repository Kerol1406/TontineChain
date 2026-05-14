import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:tontinechain/constants/app_colors.dart';
import 'package:tontinechain/models/index.dart';
import 'package:tontinechain/services/backend_service.dart';
import 'package:tontinechain/services/auth_state.dart';
import 'package:tontinechain/services/firestore_database_service.dart';
import 'package:tontinechain/providers/tontine_provider.dart';

class CotisationPaymentScreen extends StatefulWidget {
  final Tontine tontine;

  const CotisationPaymentScreen({super.key, required this.tontine});

  @override
  State<CotisationPaymentScreen> createState() => _CotisationPaymentScreenState();
}

class _CotisationPaymentScreenState extends State<CotisationPaymentScreen> {
  final FirestoreDatabaseService _db = FirestoreDatabaseService.instance;
  final BackendService _backend = BackendService.instance;
  int _selectedMethod = 0; // 0 = Mobile Money, 1 = Crypto
  String? _selectedMobileProvider; // 'mtn', 'moov', or 'celtis'
  String? _payerPhoneNumber;
  bool _isSubmitting = false;
  static const double _blockchainFee = 150;

  @override
  Widget build(BuildContext context) {
    final amountToPay = widget.tontine.monthlyAmount;
    final totalDebit = amountToPay + _blockchainFee;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _DotsBackgroundPainter())),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 34),
                  const Text(
                    'Finaliser votre\nCotisation',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.1,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Vérifiez les détails de votre transaction\nsécurisée.',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 18,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _buildSummaryCard(amountToPay: amountToPay, totalDebit: totalDebit),
                  const SizedBox(height: 24),
                  const Text(
                    'Mode de Paiement',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _PaymentMethodCard(
                    selected: _selectedMethod == 0,
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Mobile Money',
                    subtitle: _selectedMobileProvider != null ? _getMobileProviderLabel(_selectedMobileProvider!) : 'Choisir un opérateur',
                    onTap: () => setState(() {
                      if (_selectedMethod == 0) {
                        _selectedMethod = -1;
                        _selectedMobileProvider = null;
                      } else {
                        _selectedMethod = 0;
                        _selectedMobileProvider = null;
                      }
                    }),
                    iconColor: const Color(0xFF705A00),
                    iconBackground: const Color(0xFFF8D44A),
                  ),
                  if (_selectedMethod == 0) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Sélectionnez un opérateur',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _MobileProviderCard(
                      provider: 'mtn',
                      label: 'MTN Mobile Money',
                      selected: _selectedMobileProvider == 'mtn',
                      onTap: () => _onMobileProviderSelected('mtn'),
                    ),
                    const SizedBox(height: 10),
                    _MobileProviderCard(
                      provider: 'moov',
                      label: 'Moov Money',
                      selected: _selectedMobileProvider == 'moov',
                      onTap: () => _onMobileProviderSelected('moov'),
                    ),
                    const SizedBox(height: 10),
                    _MobileProviderCard(
                      provider: 'celtis',
                      label: 'Celtis Money',
                      selected: _selectedMobileProvider == 'celtis',
                      onTap: () => _onMobileProviderSelected('celtis'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _PaymentMethodCard(
                    selected: _selectedMethod == 1,
                    icon: Icons.currency_bitcoin_rounded,
                    title: 'Portefeuille Crypto',
                    subtitle: 'USDT, USDC ou ETH (Layer 2)',
                    onTap: () => setState(() {
                      _selectedMethod = 1;
                      _selectedMobileProvider = null;
                    }),
                    iconColor: const Color(0xFF8FC2AF),
                    iconBackground: AppColors.primary,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : ((_selectedMethod == 0 && _selectedMobileProvider != null) || _selectedMethod == 1)
                              ? _showPaymentSimulationDialog
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_selectedMethod == 0 && _selectedMobileProvider != null) || _selectedMethod == 1
                            ? AppColors.primary
                            : const Color(0xFFD4D0C7),
                        foregroundColor: Colors.white,
                        elevation: ((_selectedMethod == 0 && _selectedMobileProvider != null) || _selectedMethod == 1) ? 3 : 0,
                        shadowColor: AppColors.primary.withValues(alpha: 0.25),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                      label: Text(
                        _isSubmitting ? 'Traitement...' : 'Confirmer et Envoyer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1EFE8),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFE6E1D7)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_rounded, color: Color(0xFF5C8C7B), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Transaction cryptée et immutable.',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF54756A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'En cliquant sur confirmer, vous autorisez TontineChain à traiter\ncette transaction via les protocoles de sécurité blockchain.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFF0C2F25),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFF8D44A).withValues(alpha: 0.6),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.face_retouching_natural_rounded,
            color: Color(0xFF87C6B0),
            size: 30,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'TontineChain',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const Icon(Icons.notifications_rounded, color: AppColors.primary, size: 24),
      ],
    );
  }

  Widget _buildSummaryCard({required double amountToPay, required double totalDebit}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF7A9D95), Color(0xFFF8D44A), Color(0xFF7A9D95)],
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NOM DE LA TONTINE',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6C8C81),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.tontine.name,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.15,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCF0E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _AmountBox(
              label: 'Montant à payer',
              value: _formatMoney(amountToPay),
              valueColor: AppColors.textPrimary,
            ),
            const SizedBox(height: 12),
            _AmountBox(
              label: 'Frais blockchain',
              value: _formatMoney(_blockchainFee),
              valueColor: const Color(0xFF8A6F00),
              badge: 'MINIMES',
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFE9E5DC), height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total à débiter',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  _formatMoney(totalDebit),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onMobileProviderSelected(String provider) {
    setState(() {
      _selectedMethod = 0;
      _selectedMobileProvider = provider;
    });
    _showPaymentSimulationDialog();
  }

  Future<void> _showPaymentSimulationDialog() async {
    final controller = TextEditingController(text: _payerPhoneNumber ?? '');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Simulation de paiement',
            style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mode: ${_selectedMethod == 0 ? _getMobileProviderLabel(_selectedMobileProvider ?? 'mtn') : 'Portefeuille Crypto'}',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Entrez votre numéro',
                  labelText: 'Numéro de paiement',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final phone = controller.text.trim();
                if (phone.length < 8) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez saisir un numéro valide.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                final ok = await _submitSimulatedPayment(phone);
                if (!dialogContext.mounted || !mounted) return;
                if (ok) {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Confirmer la transaction',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _submitSimulatedPayment(String phoneNumber) async {
    final userId = context.read<AuthState>().currentUser?['uid']?.toString();
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Utilisateur non connecté.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final payResult = await _backend.payContribution(widget.tontine.id, {
        'userId': userId,
      });

      await _db.simulateCotisationPayment(
        tontineId: widget.tontine.id,
        userId: userId,
        amount: widget.tontine.monthlyAmount,
        phoneNumber: phoneNumber,
        paymentMode: _selectedMethod == 0 ? 'MOBILE_MONEY' : 'CRYPTO',
        provider: _selectedMethod == 0 ? _selectedMobileProvider : 'crypto_wallet',
      );

      _payerPhoneNumber = phoneNumber;

      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Paiement simulé + blockchain réussi via ${_selectedMethod == 0 ? _getMobileProviderLabel(_selectedMobileProvider ?? 'mtn') : 'Portefeuille Crypto'}.',
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      debugPrint('payContribution txHash=${payResult['txHash']} block=${payResult['blockNumber']}');

      // Rafraîchir les données globales via Provider pour synchroniser tous les écrans
      if (mounted) {
        await context.read<TontineProvider>().refreshAfterCotisation(userId);
      }

      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Échec du paiement: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color iconBackground;
  final Color iconColor;

  const _PaymentMethodCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.iconBackground,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE9E5DC),
              width: selected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: selected ? AppColors.primary : const Color(0xFFDCD6CB),
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountBox extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final String? badge;

  const _AmountBox({
    required this.label,
    required this.value,
    required this.valueColor,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1ED),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  letterSpacing: -0.4,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE9A8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF8A6F00),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileProviderCard extends StatelessWidget {
  final String provider;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MobileProviderCard({
    required this.provider,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getProviderColors(provider);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? colors['border'] as Color : const Color(0xFFE9E5DC),
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors['background'] as Color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SvgPicture.asset(
                  _getProviderSvgPath(provider),
                  width: 22,
                  height: 22,
                  fit: BoxFit.scaleDown,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? colors['border'] as Color : Colors.transparent,
                  border: Border.all(
                    color: selected ? colors['border'] as Color : const Color(0xFFDCD6CB),
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _getProviderSvgPath(String provider) {
  switch (provider) {
    case 'mtn':
      return 'assets/images/mtn.svg';
    case 'moov':
      return 'assets/images/moovmoney.svg';
    case 'celtis':
      return 'assets/images/celtis.svg';
    default:
      return 'assets/images/mtn.svg';
  }
}

Map<String, dynamic> _getProviderColors(String provider) {
  switch (provider) {
    case 'mtn':
      return {
        'background': const Color(0xFFFFE9D6),
        'icon': const Color(0xFFE67E22),
        'border': const Color(0xFFE67E22),
      };
    case 'moov':
      return {
        'background': const Color(0xFFD4F1FF),
        'icon': const Color(0xFF00A8CC),
        'border': const Color(0xFF00A8CC),
      };
    case 'celtis':
      return {
        'background': const Color(0xFFF0D9FF),
        'icon': const Color(0xFF9B59B6),
        'border': const Color(0xFF9B59B6),
      };
    default:
      return {
        'background': const Color(0xFFE9E5DC),
        'icon': AppColors.textPrimary,
        'border': const Color(0xFFDCD6CB),
      };
  }
}

String _formatMoney(num amount) {
  final raw = amount.round().toString();
  final formatted = raw.replaceAllMapped(
    RegExp(r'(?<=\d)(?=(\d{3})+$)'),
    (match) => ' ',
  );
  return '$formatted FCFA';
}

String _getMobileProviderLabel(String provider) {
  switch (provider) {
    case 'mtn':
      return 'MTN Mobile Money';
    case 'moov':
      return 'Moov Money';
    case 'celtis':
      return 'Celtis Money';
    default:
      return 'Choisir un opérateur';
  }
}

class _DotsBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8E1D7).withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    const double spacing = 18;
    const double dotRadius = 0.9;

    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x + 1.5, y + 1.5), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
