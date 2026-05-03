import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'auth_screen.dart';
import 'login_screen.dart';
import 'package:provider/provider.dart';
import 'package:tontinechain/services/mock_auth_service.dart';
import 'package:tontinechain/services/auth_state.dart';
import 'app_shell.dart';

/// Écran d'Onboarding - Présentation de TontineChain
/// Maquette fidèlement respectée : logo + nom, badge doré, titre bicolore,
/// feature card, boutons, carte blockchain, footer sécurité.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),

                    // ── Logo + Nom + Slogan ──────────────────────────────
                    _buildLogoSection(context),
                    const SizedBox(height: 40),

                    // ── Badge "NOUVELLE ÈRE FINANCIÈRE" ─────────────────
                    _buildBadge(),
                    const SizedBox(height: 16),

                    // ── Titre principal bicolore ─────────────────────────
                    _buildTitle(context),
                    const SizedBox(height: 16),

                    // ── Sous-titre ───────────────────────────────────────
                    _buildSubtitle(context),
                    const SizedBox(height: 28),

                    // ── Feature Card "Communauté Active" ─────────────────
                    _buildFeatureCard(context),
                    const SizedBox(height: 32),

                    // ── Bouton Commencer ─────────────────────────────────
                    _buildPrimaryButton(context),
                    const SizedBox(height: 12),

                    // ── Bouton Se connecter ──────────────────────────────
                    _buildSecondaryButton(context),
                    const SizedBox(height: 32),
                  ],
                ),
              ),

              // ── Carte Blockchain (pleine largeur avec padding) ────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildBlockchainCard(context),
              ),
              const SizedBox(height: 32),

              // ── Footer sécurité ──────────────────────────────────────
              _buildFooter(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION LOGO
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLogoSection(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          children: [
            // Logo circulaire - long press ouvre menu debug (DEV)
            GestureDetector(
              onLongPress: () async {
                if (!const bool.fromEnvironment('dart.vm.product')) {
                  final users = MockAuthService.instance.users;
                  if (users.isEmpty) {
                    // Charger en arrière-plan (DEV) — on ouvre le menu immédiatement
                    MockAuthService.instance.loadSeedUsers();
                  }
                  showDialog(
                    context: context,
                    builder: (ctx) {
                      return AlertDialog(
                        title: const Text('Comptes tests'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: MockAuthService.instance.users.length,
                            itemBuilder: (context, index) {
                              final u = MockAuthService.instance.users[index];
                              return ListTile(
                                title: Text(u['name'] ?? ''),
                                subtitle: Text(u['phone'] ?? ''),
                                trailing: TextButton(
                                  onPressed: () {
                                    // Auto-login
                                    final auth = Provider.of<AuthState>(context, listen: false);
                                    auth.setUser(u);
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(builder: (_) => const AppShell()),
                                    );
                                  },
                                  child: const Text('Auto-login'),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                }
              },
              child: Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: Image.asset(
                  'assets/images/Logo_TontineChaine_sans_nom.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.monetization_on,
                    size: 72,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Nom de l'app
            const Text(
              'TontineChain',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),

            // Slogan
            const Text(
              'PATRIMOINE & CONFIANCE',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BADGE DORÉ
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: const Text(
        'NOUVELLE ÈRE FINANCIÈRE',
        style: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.tertiary,
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TITRE BICOLORE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTitle(BuildContext context) {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 40,
          fontWeight: FontWeight.w800,
          height: 1.15,
          letterSpacing: -1,
        ),
        children: [
          TextSpan(
            text: "L'épargne\n",
            style: TextStyle(color: AppColors.textPrimary),
          ),
          TextSpan(
            text: 'collective',
            style: TextStyle(color: AppColors.secondary),
          ),
          TextSpan(
            text: ',\nréinventée.',
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOUS-TITRE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSubtitle(BuildContext context) {
    return Text(
      'Rejoignez des cercles de solidarité numériques. '
      'Épargnez ensemble, réalisez vos projets et '
      'sécurisez votre avenir grâce à la puissance de la blockchain.',
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontFamily: 'Plus Jakarta Sans',
            color: AppColors.textSecondary,
            height: 1.6,
            fontSize: 15,
          ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURE CARD — COMMUNAUTÉ ACTIVE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFeatureCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icône groupe
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),

          // Textes
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Communauté Active',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Plus de 50,000 membres partagent déjà leur succès.',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOUTON PRINCIPAL — COMMENCER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPrimaryButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const RegisterScreen(),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Commencer',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(width: 10),
            Icon(Icons.arrow_forward, size: 20),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOUTON SECONDAIRE — SE CONNECTER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSecondaryButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Se connecter',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CARTE BLOCKCHAIN — IMAGE + OVERLAY CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBlockchainCard(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 280,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image de fond (réseau blockchain)
            Image.asset(
              'assets/images/image_blockchain.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0D2B2B),
                      AppColors.primary,
                    ],
                  ),
                ),
              ),
            ),

            // Overlay sombre pour lisibilité
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),

            // Overlay card en bas
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildBlockchainOverlayCard(),
            ),
          ],
        ),
      ),
    );
  }

  /// Carte blanche en overlay sur l'image blockchain
  Widget _buildBlockchainOverlayCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icône vérification
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Texte
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Garantie Blockchain',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Chaque transaction est immuable, garantissant '
                  'l\'intégrité de votre épargne collective.',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FOOTER SÉCURITÉ
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        // Ligne séparatrice
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Divider(
            color: AppColors.textSecondary.withValues(alpha: 0.2),
            thickness: 1,
          ),
        ),
        const SizedBox(height: 16),

        // Badges sécurité
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFooterBadge(Icons.shield_outlined, 'Cryptage AES-256'),
            const SizedBox(width: 24),
            _buildFooterBadge(Icons.account_balance_outlined, 'Régulé & Conforme'),
          ],
        ),
        const SizedBox(height: 16),

        // Copyright
        const Text(
          '© 2024 TONTINECHAIN — L\'HÉRITAGE MODERNE',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  /// Badge icône + texte pour le footer
  Widget _buildFooterBadge(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}