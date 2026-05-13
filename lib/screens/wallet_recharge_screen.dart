import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tontinechain/constants/app_colors.dart';
import 'package:tontinechain/services/auth_state.dart';
import 'package:tontinechain/services/firestore_database_service.dart';

class WalletRechargeScreen extends StatefulWidget {
  final bool isWithdrawal;

  const WalletRechargeScreen({super.key, this.isWithdrawal = false});

  @override
  State<WalletRechargeScreen> createState() => _WalletRechargeScreenState();
}

class _WalletRechargeScreenState extends State<WalletRechargeScreen> {
  final FirestoreDatabaseService _db = FirestoreDatabaseService.instance;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  int _selectedMethod = -1; // -1 = rien, 0 = Mobile Money, 1 = Crypto
  String? _selectedMobileProvider; // 'mtn', 'moov', or 'celtis'
  bool _isSubmitting = false;
  static const double _blockchainFee = 150;

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _getMobileProviderLabel(String provider) {
    switch (provider.toLowerCase()) {
      case 'mtn':
        return 'MTN Mobile Money';
      case 'moov':
        return 'Moov Money';
      case 'celtis':
        return 'Celtis Money';
      default:
        return provider;
    }
  }

  Future<void> _handleTransaction() async {
    final amountText = _amountController.text.trim();
    final phone = _phoneController.text.trim();

    if (amountText.isEmpty || phone.isEmpty || _selectedMobileProvider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Montant invalide.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = context.read<AuthState>().currentUser;
      final userId = user?['uid']?.toString();
      final currentSolde = (user?['solde'] as num?)?.toDouble() ?? 0;

      if (userId == null || userId.isEmpty) {
        throw Exception('Utilisateur non identifié');
      }

      if (widget.isWithdrawal && amount > currentSolde) {
        throw Exception('Solde insuffisant');
      }

      if (widget.isWithdrawal) {
        await _db.simulateWalletWithdrawal(
          userId: userId,
          amount: amount,
          phoneNumber: phone,
          paymentMode: _selectedMobileProvider!,
        );
      } else {
        // Simuler le rechargement du portefeuille
        await _db.simulateWalletRecharge(
          userId: userId,
          amount: amount,
          phoneNumber: phone,
          paymentMode: _selectedMobileProvider!,
        );
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Portefeuille rechargé avec succès !'),
          backgroundColor: AppColors.primary,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amountText = _amountController.text.isEmpty ? '0' : _amountController.text;
    final amount = double.tryParse(amountText) ?? 0;
    final currentSolde = (context.watch<AuthState>().currentUser?['solde'] as num?)?.toDouble() ?? 0;
    final totalDebit = widget.isWithdrawal ? amount : amount + _blockchainFee;
    final nextBalance = widget.isWithdrawal ? currentSolde - amount : currentSolde + amount;
    final canSubmit = _selectedMobileProvider != null && _amountController.text.isNotEmpty && !_isSubmitting;
    final title = widget.isWithdrawal ? 'Retirer depuis\nPortefeuille' : 'Recharger votre\nPortefeuille';
    final subtitle = widget.isWithdrawal
        ? 'Retirez de l\'argent vers votre compte Mobile Money.'
        : 'Montant sécurisé et instantané\nvia Mobile Money.';
    final actionLabel = widget.isWithdrawal ? 'Confirmer le Retrait' : 'Confirmer la Recharge';
    final amountLabel = widget.isWithdrawal ? 'Montant à Retirer' : 'Montant à Recharger';

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
                  Text(
                    title,
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
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 18,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Champ montant
                  Text(
                    amountLabel,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ex: 50000',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      suffixText: 'XOF',
                      suffixStyle: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF4F3EF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Résumé
                  _buildSummaryCard(
                    amount: amount,
                    currentSolde: currentSolde,
                    totalDebit: totalDebit,
                    nextBalance: nextBalance,
                    isWithdrawal: widget.isWithdrawal,
                  ),
                  const SizedBox(height: 24),

                  // Mode paiement
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
                    Row(
                      children: [
                        _OperatorChip(
                          label: 'MTN',
                          selected: _selectedMobileProvider == 'mtn',
                          onTap: () => setState(() => _selectedMobileProvider = 'mtn'),
                        ),
                        const SizedBox(width: 10),
                        _OperatorChip(
                          label: 'Moov',
                          selected: _selectedMobileProvider == 'moov',
                          onTap: () => setState(() => _selectedMobileProvider = 'moov'),
                        ),
                        const SizedBox(width: 10),
                        _OperatorChip(
                          label: 'Celtis',
                          selected: _selectedMobileProvider == 'celtis',
                          onTap: () => setState(() => _selectedMobileProvider = 'celtis'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: '+225 07 00 00 00',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                        ),
                        prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: const Color(0xFFF4F3EF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Bouton confirmation
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: canSubmit ? _handleTransaction : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isWithdrawal ? AppColors.error : AppColors.secondary,
                        foregroundColor: AppColors.textPrimary,
                        disabledBackgroundColor: (widget.isWithdrawal ? AppColors.error : AppColors.secondary).withValues(alpha: 0.6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.textPrimary,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  actionLabel,
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 18),
                              ],
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
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
            ),
            child: const Icon(Icons.arrow_back, size: 18, color: AppColors.textPrimary),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
            ),
            child: const Icon(Icons.close, size: 18, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required double amount,
    required double currentSolde,
    required double totalDebit,
    required double nextBalance,
    required bool isWithdrawal,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isWithdrawal ? 'Montant à retirer' : 'Montant',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
              Text(
                '${amount.toStringAsFixed(0)} XOF',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isWithdrawal ? 'Solde disponible' : 'Frais blockchain',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
              Text(
                isWithdrawal ? '${currentSolde.toStringAsFixed(0)} XOF' : '${_blockchainFee.toStringAsFixed(0)} XOF',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isWithdrawal ? 'Nouveau solde' : 'Frais blockchain',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
              Text(
                isWithdrawal ? '${nextBalance.toStringAsFixed(0)} XOF' : '${_blockchainFee.toStringAsFixed(0)} XOF',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isWithdrawal && nextBalance < 0 ? AppColors.error : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (!isWithdrawal) ...[
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: AppColors.textSecondary.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total à débiter',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${totalDebit.toStringAsFixed(0)} XOF',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: AppColors.textSecondary.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Solde après retrait',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${nextBalance.toStringAsFixed(0)} XOF',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: nextBalance < 0 ? AppColors.error : AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color iconColor;
  final Color iconBackground;

  const _PaymentMethodCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.iconColor,
    required this.iconBackground,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondary.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.secondary : AppColors.textSecondary.withValues(alpha: 0.15),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.secondary : AppColors.textSecondary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.secondary,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _OperatorChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OperatorChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondary.withValues(alpha: 0.15) : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.secondary : AppColors.textSecondary.withValues(alpha: 0.2),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.secondary : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotsBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4C9B0).withValues(alpha: 0.15)
      ..strokeWidth = 1.5;

    const dotSpacing = 28.0;

    for (double x = 0; x < size.width; x += dotSpacing) {
      for (double y = 0; y < size.height; y += dotSpacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
