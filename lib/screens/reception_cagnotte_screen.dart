import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:tontinechain/models/index.dart';
import 'package:tontinechain/constants/app_colors.dart';
import 'package:tontinechain/services/auth_state.dart';
import 'package:tontinechain/services/tontine_service.dart';
import 'app_shell.dart';

/// Écran de réception de la cagnotte
/// ✅ Carte verte fidèle à la maquette :
///    - Montant très grand, doré, avec points séparateurs
///    - Motif texture losanges sur fond vert
///    - Badge "Vérifié sur Blockchain Polygon" pill sombre
class ReceptionCagnotteScreen extends StatefulWidget {
  final Tontine tontine;
  final String montant;
  final String tourNumber;

  const ReceptionCagnotteScreen({
    super.key,
    required this.tontine,
    required this.montant,
    required this.tourNumber,
  });

  @override
  State<ReceptionCagnotteScreen> createState() =>
      _ReceptionCagnotteScreenState();
}

class _ReceptionCagnotteScreenState extends State<ReceptionCagnotteScreen>
    with TickerProviderStateMixin {
  late final MockTontineService _service;
  String? _selectedMethod;
  String? _phoneNumber;
  late AnimationController _stepAnimationController;
  int _currentStep = 0;
  bool _isTransferring = false;

  @override
  void initState() {
    super.initState();
    _service = MockTontineService();
    _stepAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _stepAnimationController.dispose();
    super.dispose();
  }

  // ── Formatage du montant avec points séparateurs (ex: 5.000.000) ─────────
  String _formatMontant(String raw) {
    // Extraire uniquement les chiffres
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return raw;

    // Groupes de 3 avec point comme séparateur
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  void _selectMethod(String method) {
    setState(() => _selectedMethod = method);
    _showPhoneDialog();
  }

  void _showPhoneDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String? tempPhone;
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Entrez votre numéro',
            style: TextStyle(
              fontFamily: 'Manrope', fontSize: 18,
              fontWeight: FontWeight.w700, color: AppColors.textPrimary,
            )),
          content: TextField(
            onChanged: (v) => tempPhone = v,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '+229 XX XX XX XX',
              hintStyle: const TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              onPressed: () {
                if (tempPhone != null && tempPhone!.isNotEmpty) {
                  setState(() => _phoneNumber = tempPhone);
                  Navigator.pop(context);
                }
              },
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startTransfer() async {
    if (_selectedMethod == null || _phoneNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Veuillez sélectionner un moyen et entrer votre numéro')));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final user = context.read<AuthState>().currentUser ?? {};
    final currentUserPhone = (user['phone'] ?? '').toString();
    if (currentUserPhone.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Impossible d\'identifier l\'utilisateur connecté')));
      return;
    }

    setState(() {
      _isTransferring = true;
      _currentStep = 1;
    });

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final ok = await _service.confirmCagnotteReception(
      tontineId: widget.tontine.id,
      memberPhone: currentUserPhone,
      receptionMethod: _selectedMethod!,
      receiverPhone: _phoneNumber!,
    );

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _isTransferring = false;
        _currentStep = 0;
      });
      messenger.showSnackBar(const SnackBar(
          content:
              Text('Réception impossible: ce tour a déjà été traité')));
      return;
    }

    setState(() => _currentStep = 2);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) _showSuccessDialog();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0xFFE8F5E9)),
              child: const Icon(Icons.check_circle,
                  size: 50, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text('Cagnotte reçue !',
              style: TextStyle(
                fontFamily: 'Manrope', fontSize: 20,
                fontWeight: FontWeight.w700, color: AppColors.textPrimary,
              )),
            const SizedBox(height: 10),
            Text('Les fonds ont été transférés sur $_selectedMethod',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                color: AppColors.textSecondary,
              )),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              child: const Text('Retour au tableau de bord'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('TontineChain',
          style: TextStyle(
            fontFamily: 'Manrope', fontSize: 20,
            fontWeight: FontWeight.w800, color: AppColors.textPrimary,
          )),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  color: AppColors.primary, size: 20),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Icône + Titre ──────────────────────────────────────────────
            _buildHeader(),
            const SizedBox(height: 24),

            // ── ✅ CARTE VERTE (fidèle maquette) ───────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildMontantCard(),
            ),
            const SizedBox(height: 20),

            // ── Info cercle ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildCercleInfo(),
            ),
            const SizedBox(height: 28),

            // ── État du déblocage ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildDeblockageState(),
            ),
            const SizedBox(height: 28),

            // ── Méthode de réception ───────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Méthode de réception',
                style: TextStyle(
                  fontFamily: 'Manrope', fontSize: 16,
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                )),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildMethodSelector(),
            ),
            const SizedBox(height: 20),

            // ── Message sécurité ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSecurityNote(),
            ),
            const SizedBox(height: 28),

            // ── Bouton confirmer ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildConfirmButton(),
            ),
          ],
        ),
      ),

      // ── Bottom nav ─────────────────────────────────────────────────────────
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER — Icône + Titre
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          // Icône cagnotte
          SizedBox(
            width: 60, height: 60,
            child: Image.asset(
              'assets/images/icone_cagnotte.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F1D0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.5),
                      width: 1),
                ),
                child: const Center(
                  child: Icon(Icons.eco_outlined,
                      color: AppColors.primary, size: 28),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Réception de la cagnotte',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope', fontSize: 26,
              fontWeight: FontWeight.w800, color: AppColors.textPrimary,
              letterSpacing: -0.4,
            )),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ CARTE VERTE — Fidèle à la maquette
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMontantCard() {
    final String montantFormate = _formatMontant(widget.montant);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF003D2B),
            Color(0xFF005C42),
            Color(0xFF004535),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 24, offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // ── Motif losanges texture (fidèle maquette) ─────────────────────
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(painter: _DiamondTexturePainter()),
            ),
          ),

          // ── Contenu ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 28, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Label
                const Text('MONTANT TOTAL À RECEVOIR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                    fontWeight: FontWeight.w600, color: Colors.white54,
                    letterSpacing: 1.2,
                  )),
                const SizedBox(height: 16),

                // ── Montant principal — très grand, doré ──────────────────
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
                        letterSpacing: -1.5,
                        height: 1.0,
                      ),
                      children: [
                        TextSpan(text: montantFormate),
                        const TextSpan(
                          text: ' FCFA',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppColors.secondary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Badge "Vérifié sur Blockchain Polygon" ────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded,
                          size: 15, color: AppColors.secondary),
                      SizedBox(width: 7),
                      Text('Vérifié sur Blockchain Polygon',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                          fontWeight: FontWeight.w600, color: Colors.white,
                          letterSpacing: 0.2,
                        )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INFO CERCLE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCercleInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          // Icône groupe
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_alt_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),

          // Nom + cycle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cercle des',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  )),
                Text(widget.tontine.name,
                  style: const TextStyle(
                    fontFamily: 'Manrope', fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                const Text('Cycle Janvier 2024',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                    color: AppColors.textSecondary,
                  )),
              ],
            ),
          ),

          // Badge "Tour de rôle n°X"
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Tour de rôle\nn°${widget.tourNumber}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A56DB), height: 1.3,
              )),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ÉTAT DU DÉBLOCAGE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDeblockageState() {
    const steps = [
      (
        'En attente',
        'Validation des contributions terminée',
        Icons.check,
      ),
      (
        'En cours de transfert',
        'Envoi vers votre compte Mobile Money',
        Icons.currency_exchange_outlined,
      ),
      (
        'Reçu avec succès',
        'Confirmation finale du réseau',
        Icons.flag_outlined,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('État du déblocage',
          style: TextStyle(
            fontFamily: 'Manrope', fontSize: 16,
            fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          )),
        const SizedBox(height: 16),

        Stack(
          children: [
            // Ligne verticale connectant les étapes
            Positioned(
              left: 21, top: 44, bottom: 0,
              child: Container(
                width: 2,
                color: const Color(0xFFE0E0E0),
              ),
            ),

            Column(
              children: List.generate(steps.length, (index) {
                final (title, subtitle, icon) = steps[index];
                final isCompleted = _currentStep > index;
                final isActive    = _currentStep == index;
                final isLast      = index == steps.length - 1;

                final Color circleColor = isCompleted
                    ? AppColors.primary
                    : isActive
                        ? AppColors.secondary
                        : const Color(0xFFDDDDDD);

                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cercle indicateur
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: circleColor,
                          border: isActive
                              ? Border.all(
                                  color: AppColors.secondary
                                      .withValues(alpha: 0.4),
                                  width: 3)
                              : null,
                          boxShadow: isActive
                              ? [BoxShadow(
                                  color: AppColors.secondary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8, spreadRadius: 2)]
                              : [],
                        ),
                        child: (isCompleted || isActive)
                            ? Icon(icon,
                                color: isActive
                                    ? AppColors.primary
                                    : Colors.white,
                                size: 20)
                            : null,
                      ),
                      const SizedBox(width: 16),

                      // Texte
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                style: TextStyle(
                                  fontFamily: 'Manrope', fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: (isCompleted || isActive)
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary
                                          .withValues(alpha: 0.5),
                                )),
                              const SizedBox(height: 3),
                              Text(subtitle,
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 12, fontWeight: FontWeight.w500,
                                  color: (isCompleted || isActive)
                                      ? AppColors.textSecondary
                                      : const Color(0xFFBDBDBD),
                                )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MÉTHODE DE RÉCEPTION
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMethodSelector() {
    final methods = [
      _PaymentMethod(
        id: 'mtn',
        label: 'MTN Benin',
        subText: '+229 97 ·· 45',
        bgColor: const Color(0xFFFFCC00), // Jaune MTN officiel
        svgAsset: 'assets/images/mtn.svg',
      ),
      _PaymentMethod(
        id: 'moov',
        label: 'Moov Africa',
        subText: 'Sélectionner ce compte',
        bgColor: const Color(0xFF0066CC), // Bleu Moov
        svgAsset: 'assets/images/moovmoney.svg',
      ),
      _PaymentMethod(
        id: 'celtis',
        label: 'Celtis Mobile',
        subText: 'Sélectionner ce compte',
        bgColor: const Color(0xFF003380), // Bleu foncé Celtis
        svgAsset: 'assets/images/celtis.svg',
      ),
    ];

    return Column(
      children: methods.map((method) {
        final isSelected = _selectedMethod == method.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => _selectMethod(method.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFFE0E0E0),
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(14),
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.04)
                    : Colors.white,
              ),
              child: Row(
                children: [
                  // Logo opérateur — SVG dans container coloré
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: method.bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: SvgPicture.asset(
                      method.svgAsset,
                      fit: BoxFit.contain,
                      // Pas de colorFilter — SVG affiché tel quel
                      placeholderBuilder: (context) => Center(
                        child: Text(
                          method.id.toUpperCase().substring(0, 3),
                          style: const TextStyle(
                            fontFamily: 'Manrope', fontSize: 12,
                            fontWeight: FontWeight.w800, color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Nom + sous-texte
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(method.label,
                          style: const TextStyle(
                            fontFamily: 'Manrope', fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          )),
                        const SizedBox(height: 3),
                        Text(method.subText,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.8),
                          )),
                      ],
                    ),
                  ),

                  // Radio indicator
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFFDDDDDD),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 15)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTE SÉCURITÉ
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 20, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Votre transaction est sécurisée par un contrat intelligent '
              '(Smart Contract) audité. La réception est garantie dès '
              'validation sur la chaîne.',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                fontWeight: FontWeight.w500, color: AppColors.textSecondary,
                height: 1.5,
              )),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOUTON CONFIRMER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white, elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _isTransferring ? null : _startTransfer,
        child: _isTransferring
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Confirmer la réception',
                    style: TextStyle(
                      fontFamily: 'Manrope', fontSize: 16,
                      fontWeight: FontWeight.w700, letterSpacing: -0.2,
                    )),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM NAV
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBottomNavBar() {
    const items = [
      _NavItem(icon: Icons.home_outlined,      label: 'Accueil'),
      _NavItem(icon: Icons.people_outline,     label: 'Tontines'),
      _NavItem(icon: Icons.account_balance_wallet_outlined, label: 'Paiements'),
      _NavItem(icon: Icons.person_outline,     label: 'Profil'),
    ];
    const int selectedIndex = 2; // Paiements actif

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (index) {
              final item       = items[index];
              final isSelected = index == selectedIndex;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Navigate to main app shell and select the tapped tab
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => AppShell(initialIndex: index)),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary
                                .withValues(alpha: 0.45),
                        size: 24),
                      const SizedBox(height: 4),
                      Text(item.label,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans', fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary
                                  .withValues(alpha: 0.45),
                        )),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MODÈLES PRIVÉS
// ══════════════════════════════════════════════════════════════════════════════

class _PaymentMethod {
  final String id;
  final String label;
  final String subText;
  final Color bgColor;
  final String svgAsset;

  const _PaymentMethod({
    required this.id, required this.label, required this.subText,
    required this.bgColor, required this.svgAsset,
  });
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ══════════════════════════════════════════════════════════════════════════════
// PAINTER — Texture losanges carte verte (fidèle maquette)
// ══════════════════════════════════════════════════════════════════════════════
class _DiamondTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const double spacing = 32.0;
    const double half    = spacing / 2;

    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      for (double y = -spacing; y < size.height + spacing; y += spacing) {
        final path = Path()
          ..moveTo(x, y - half)
          ..lineTo(x + half, y)
          ..lineTo(x, y + half)
          ..lineTo(x - half, y)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}