import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tontinechain/constants/app_colors.dart';
import 'package:tontinechain/services/auth_state.dart';
import 'package:tontinechain/services/mock_auth_service.dart';
import 'package:tontinechain/screens/onboarding_screen.dart';

/// Écran Profil — TontineChain
/// Sections : Avatar, Trust Score, Patrimoine, Sécurité,
///             Historique Cotisations, Paramètres, Déconnexion
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _activeMode = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthState>().currentUser ?? {};
    _activeMode = user['activeMode'] == true;
  }

  void _setActiveMode(bool value) {
    final authState = context.read<AuthState>();
    final currentUser = Map<String, dynamic>.from(authState.currentUser ?? {});
    final userId = currentUser['id']?.toString();

    if (userId != null && userId.isNotEmpty) {
      MockAuthService.instance.setActiveMode(userId, value);
    }

    currentUser['activeMode'] = value;
    currentUser['activeSearchStatus'] = value
        ? 'Disponible et en recherche'
        : 'Mode actif désactivé';
    authState.setUser(currentUser);

    setState(() => _activeMode = value);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().currentUser ?? {};
    final String name  = (user['name']  ?? 'Utilisateur').toString();
    final String email = (user['email'] ?? 'non.renseigne@patrimoine.tg').toString();
    final String phone = (user['phone'] ?? 'Non renseigné').toString();
    final String initials = _getInitials(name);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar custom (identique au Dashboard) ─────────────────────
            _buildAppBar(initials, context),

            // ── Contenu scrollable ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Avatar + nom + email + wallet + membre depuis
                    _buildProfileHeader(initials, name, email),
                    const SizedBox(height: 20),

                    // Trust Score
                    _buildTrustScore(),
                    const SizedBox(height: 16),

                    // Patrimoine + boutons
                    _buildPatrimoineCard(context),
                    const SizedBox(height: 16),

                    // Sécurité
                    _buildSecurityCard(context),
                    const SizedBox(height: 24),

                    // Mode actif
                    _buildActiveModeCard(context),
                    const SizedBox(height: 24),

                    // Historique des cotisations
                    _buildHistoriqueSection(),
                    const SizedBox(height: 24),

                    // Paramètres du compte
                    _buildParametresSection(context, name, phone),
                    const SizedBox(height: 24),

                    // Bouton Déconnexion
                    _buildDeconnexion(context),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODE ACTIF
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildActiveModeCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.manage_search_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mode actif',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _activeMode
                      ? 'Votre compte apparaît dans les suggestions d’invitation.'
                      : 'Votre compte n’apparaît pas dans les suggestions.',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.75),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: _activeMode,
            onChanged: _setActiveMode,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.25),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppColors.textSecondary.withValues(alpha: 0.18),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAppBar(String initials, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.6), width: 2),
            ),
            child: Center(
              child: Text(initials,
                style: const TextStyle(
                  fontFamily: 'Manrope', fontSize: 15,
                  fontWeight: FontWeight.w700, color: Colors.white,
                )),
            ),
          ),
          const SizedBox(width: 12),
          const Text('TontineChain',
            style: TextStyle(
              fontFamily: 'Manrope', fontSize: 20,
              fontWeight: FontWeight.w800, color: AppColors.textPrimary,
              letterSpacing: -0.3,
            )),
          const Spacer(),
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.surface, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.notifications_outlined,
                color: AppColors.primary, size: 22),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROFILE HEADER — Avatar, nom, email, wallet, membre depuis
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildProfileHeader(String initials, String name, String email) {
    return Center(
      child: Column(
        children: [
          // Avatar avec badge vérifié
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.secondary, width: 3),
                  color: AppColors.primary,
                ),
                child: Center(
                  child: Text(initials,
                    style: const TextStyle(
                      fontFamily: 'Manrope', fontSize: 34,
                      fontWeight: FontWeight.w800, color: Colors.white,
                    )),
                ),
              ),

              // Badge vérifié doré
              Positioned(
                bottom: 2, right: 2,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: const Icon(Icons.check, color: AppColors.primary, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Nom
          Text(name,
            style: const TextStyle(
              fontFamily: 'Manrope', fontSize: 22,
              fontWeight: FontWeight.w800, color: AppColors.textPrimary,
            )),
          const SizedBox(height: 4),

          // Email
          Text(email,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 13,
              color: AppColors.textSecondary,
            )),
          const SizedBox(height: 14),

          // Adresse wallet (chip vert)
          GestureDetector(
            onTap: () {
              // TODO: copier adresse dans le presse-papier
              Clipboard.setData(const ClipboardData(text: '0x71C...4f2E'));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      color: Colors.white70, size: 14),
                  SizedBox(width: 6),
                  Text('0x71C...4f2E',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                      fontWeight: FontWeight.w600, color: Colors.white,
                      letterSpacing: 0.5,
                    )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Membre depuis
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: const Text('Membre depuis 2022',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                fontWeight: FontWeight.w500, color: AppColors.textSecondary,
              )),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TRUST SCORE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTrustScore() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('TRUST SCORE',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 11,
              fontWeight: FontWeight.w600, color: Colors.white60,
              letterSpacing: 1.6,
            )),
          const SizedBox(height: 8),

          // Score bicolore
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontFamily: 'Manrope', fontSize: 40,
                fontWeight: FontWeight.w800, letterSpacing: -1,
              ),
              children: [
                TextSpan(text: '98', style: TextStyle(color: Colors.white)),
                TextSpan(text: '/100',
                  style: TextStyle(color: Colors.white54, fontSize: 28)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Badge MEMBRE ÉLITE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('MEMBRE ÉLITE',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                fontWeight: FontWeight.w800, color: AppColors.primary,
                letterSpacing: 1.4,
              )),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PATRIMOINE + BOUTONS DÉPOSER / RETIRER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPatrimoineCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + icône banque
          Row(
            children: [
              const Text('Patrimoine Total Estimé',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                  color: AppColors.textSecondary,
                )),
              const Spacer(),
              Icon(Icons.account_balance_outlined,
                  color: AppColors.textSecondary.withValues(alpha: 0.5), size: 20),
            ],
          ),
          const SizedBox(height: 8),

          // Montant — 0 pour nouveau compte
          const Text('0',
            style: TextStyle(
              fontFamily: 'Manrope', fontSize: 34,
              fontWeight: FontWeight.w800, color: AppColors.textPrimary,
              letterSpacing: -1,
            )),
          const Text('XOF',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 16,
              fontWeight: FontWeight.w500, color: AppColors.textSecondary,
              letterSpacing: 1,
            )),
          const SizedBox(height: 18),

          // Boutons Déposer / Retirer
          Row(
            children: [
              // Déposer — primary
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: navigate to deposit screen
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Déposer',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14, fontWeight: FontWeight.w700,
                      )),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Retirer — outlined
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: navigate to withdraw screen
                    },
                    icon: const Icon(Icons.upload_outlined, size: 18),
                    label: const Text('Retirer',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14, fontWeight: FontWeight.w700,
                      )),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SÉCURITÉ
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSecurityCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre avec icône bouclier
          const Row(
            children: [
              Icon(Icons.shield_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('Sécurité',
                style: TextStyle(
                  fontFamily: 'Manrope', fontSize: 16,
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                )),
            ],
          ),
          const SizedBox(height: 16),

          // Items sécurité
          _SecurityItem(label: '2FA Actif',         status: _SecurityStatus.ok),
          const Divider(height: 20, color: Color(0xFFEEEDE9)),
          _SecurityItem(label: 'Wallet Connecté',   status: _SecurityStatus.ok),
          const Divider(height: 20, color: Color(0xFFEEEDE9)),
          _SecurityItem(label: 'Backup Phrase',      status: _SecurityStatus.warning),
          const SizedBox(height: 16),

          // Lien Gérer mes clés
          GestureDetector(
            onTap: () {
              // TODO: navigate to key management
            },
            child: const Center(
              child: Text('Gérer mes clés',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                  fontWeight: FontWeight.w700, color: AppColors.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primary,
                )),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HISTORIQUE DES COTISATIONS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHistoriqueSection() {
    // Pour un nouveau compte : liste vide
    final List<_HistoriqueItem> items = [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Text('Historique des\nCotisations',
                style: TextStyle(
                  fontFamily: 'Manrope', fontSize: 18,
                  fontWeight: FontWeight.w800, color: AppColors.textPrimary,
                )),
            ),

            // Badge "Voir tout"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Voir\ntout',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                  fontWeight: FontWeight.w700, color: Colors.white,
                  height: 1.2,
                )),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // État vide ou items
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                Icon(Icons.history_rounded,
                    color: AppColors.primary.withValues(alpha: 0.3), size: 40),
                const SizedBox(height: 10),
                const Text('Aucune cotisation pour l\'instant',
                  style: TextStyle(
                    fontFamily: 'Manrope', fontSize: 14,
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                  )),
                const SizedBox(height: 4),
                Text('Vos versements apparaîtront ici\naprès avoir rejoint un cercle.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    height: 1.5,
                  )),
              ],
            ),
          )
        else
          ...items.map((item) => _buildHistoriqueItemTile(item)),
      ],
    );
  }

  Widget _buildHistoriqueItemTile(_HistoriqueItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Icône groupe
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                  style: const TextStyle(
                    fontFamily: 'Manrope', fontSize: 13,
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                  )),
                const SizedBox(height: 3),
                Text(item.subtitle,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  )),
              ],
            ),
          ),

          // Montant + badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(item.amount,
                style: const TextStyle(
                  fontFamily: 'Manrope', fontSize: 14,
                  fontWeight: FontWeight.w800, color: AppColors.textPrimary,
                )),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('RÉCEPTION\nFINALE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontSize: 8,
                    fontWeight: FontWeight.w700, color: AppColors.primary,
                    letterSpacing: 0.5, height: 1.3,
                  )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PARAMÈTRES DU COMPTE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildParametresSection(BuildContext context, String name, String phone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Paramètres du Compte',
          style: TextStyle(
            fontFamily: 'Manrope', fontSize: 18,
            fontWeight: FontWeight.w800, color: AppColors.textPrimary,
          )),
        const SizedBox(height: 14),

        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                label: 'Informations Personnelles',
                onTap: () {
                  // TODO: navigate to personal info screen
                },
              ),
              Divider(height: 1, color: AppColors.primary.withValues(alpha: 0.08),
                  indent: 60),
              _SettingsTile(
                icon: Icons.shield_outlined,
                label: 'Préférences de Sécurité',
                onTap: () {
                  // TODO: navigate to security preferences
                },
              ),
              Divider(height: 1, color: AppColors.primary.withValues(alpha: 0.08),
                  indent: 60),
              _SettingsTile(
                icon: Icons.language_outlined,
                label: 'Langue & Région',
                trailing: 'Français',
                onTap: () {
                  // TODO: navigate to language settings
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DÉCONNEXION
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDeconnexion(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<AuthState>().clear();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (route) => false,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        ),
        child: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
            SizedBox(width: 14),
            Text('Déconnexion',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 15,
                fontWeight: FontWeight.w700, color: AppColors.error,
              )),
          ],
        ),
      ),
    );
  }

  // Bottom nav is owned by AppShell; removed local bottom nav to avoid duplication.

  // ── Helper ────────────────────────────────────────────────────────────────
  String _getInitials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS PRIVÉS
// ══════════════════════════════════════════════════════════════════════════════

/// Statut d'un item de sécurité
enum _SecurityStatus { ok, warning, error }

/// Item de la section Sécurité
class _SecurityItem extends StatelessWidget {
  final String label;
  final _SecurityStatus status;
  const _SecurityItem({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final Widget trailing;
    switch (status) {
      case _SecurityStatus.ok:
        trailing = Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.green, size: 16),
        );
        break;
      case _SecurityStatus.warning:
        trailing = Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.priority_high_rounded,
              color: AppColors.error, size: 16),
        );
        break;
      case _SecurityStatus.error:
        trailing = const Icon(Icons.close, color: AppColors.error, size: 20);
    }

    return Row(
      children: [
        Expanded(
          child: Text(label,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 14,
              color: AppColors.textPrimary,
            )),
        ),
        trailing,
      ],
    );
  }
}

/// Item des paramètres du compte
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                  fontWeight: FontWeight.w500, color: AppColors.textPrimary,
                )),
            ),
            if (trailing != null) ...[
              Text(trailing!,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                )),
              const SizedBox(width: 4),
            ],
            Icon(Icons.chevron_right,
                color: AppColors.textSecondary.withValues(alpha: 0.4), size: 20),
          ],
        ),
      ),
    );
  }
}

/// Modèle pour un item de l'historique
class _HistoriqueItem {
  final String title;
  final String subtitle;
  final String amount;
  final IconData icon;
  const _HistoriqueItem({
    required this.title, required this.subtitle,
    required this.amount, required this.icon,
  });
}

