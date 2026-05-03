import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tontinechain/models/index.dart';
import 'package:tontinechain/constants/app_colors.dart';
import 'package:tontinechain/screens/app_shell.dart';
import 'package:tontinechain/services/tontine_service.dart';

/// Écran Contrat Intelligent — TontineChain
/// Sections : Carte verte, Règles, Confiance Technique,
///            Registre Blockchain (tableau scroll horizontal avec FutureBuilder)
class ContratSmartScreen extends StatelessWidget {
  final Tontine tontine;

  const ContratSmartScreen({Key? key, required this.tontine}) : super(key: key);

  // ── Formatage montant ──────────────────────────────────────────────────────
  String _formatMontant(double value) {
    final str = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String _shortHash(String h) {
    if (h.startsWith('0x') && h.length > 12) {
      return '${h.substring(0, 6)}...${h.substring(h.length - 4)}';
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildContratCard(),
                    const SizedBox(height: 28),
                    _buildReglesSection(),
                    const SizedBox(height: 24),
                    _buildConfianceSection(),
                    const SizedBox(height: 28),
                    _buildRegistreSection(context),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.6), width: 2),
            ),
            child: const Center(
              child: Text('TC',
                style: TextStyle(
                  fontFamily: 'Manrope', fontSize: 14,
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
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
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
  // CARTE VERTE CONTRAT
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildContratCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF003527), Color(0xFF005C42), Color(0xFF003D2E)],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 20, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Motif losanges
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(painter: _DiamondPainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge "Actif & Audité"
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded,
                          color: AppColors.secondary, size: 14),
                      SizedBox(width: 6),
                      Text('Actif & Audité',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                          fontWeight: FontWeight.w600, color: Colors.white,
                        )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Nom tontine
                Text(tontine.name,
                  style: const TextStyle(
                    fontFamily: 'Manrope', fontSize: 24,
                    fontWeight: FontWeight.w800, color: Colors.white,
                    letterSpacing: -0.5, height: 1.2,
                  )),
                const SizedBox(height: 10),

                // Description
                Text(
                  'Le contrat intelligent sécurise l\'épargne collective et '
                  'automatise les versements sur la blockchain Polygon.',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.5,
                  )),
                const SizedBox(height: 18),

                // Box cagnotte + wallet
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CAGNOTTE TOTALE',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans', fontSize: 10,
                          fontWeight: FontWeight.w600, color: Colors.white54,
                          letterSpacing: 1.4,
                        )),
                      const SizedBox(height: 8),

                      // Montant doré
                      Text(
                        _formatMontant(tontine.monthlyAmount),
                        style: const TextStyle(
                          fontFamily: 'Manrope', fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondary,
                          letterSpacing: -0.5, height: 1.1,
                        )),
                      const SizedBox(height: 2),
                      const Text('FCFA',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                          letterSpacing: 1,
                        )),
                      const SizedBox(height: 14),

                      // Adresse wallet copiable
                      GestureDetector(
                        onTap: () => Clipboard.setData(
                            const ClipboardData(text: '0x71C...BA21')),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined,
                                color: Colors.white54, size: 14),
                            const SizedBox(width: 6),
                            Text('0x71C...BA21',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.6),
                                letterSpacing: 0.5,
                              )),
                            const SizedBox(width: 6),
                            Icon(Icons.copy_outlined,
                                color: Colors.white.withValues(alpha: 0.4),
                                size: 12),
                          ],
                        ),
                      ),
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
  // RÈGLES DE SOLIDARITÉ
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildReglesSection() {
    const regles = [
      _RegleItem(
        icon: Icons.access_time_rounded,
        iconBg: Color(0xFF1A3C34),
        titre: 'Ordre de passage',
        description: 'Attribution aléatoire via Oracle Chainlink le 1er de chaque mois.',
      ),
      _RegleItem(
        icon: Icons.warning_amber_rounded,
        iconBg: Color(0xFF7A3000),
        titre: 'Pénalités de retard',
        description: '5% de frais additionnels après 24h de retard, redistribués aux membres.',
      ),
      _RegleItem(
        icon: Icons.people_alt_rounded,
        iconBg: Color(0xFF1A3C34),
        titre: 'Membres requis',
        description: '12 participants actifs. Le contrat se suspend si un membre se retire.',
      ),
      _RegleItem(
        icon: Icons.account_balance_wallet_outlined,
        iconBg: Color(0xFF4A3000),
        titre: 'Fréquence',
        description: 'Mensuelle — 50 000 FCFA par membre chaque mois.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.rule_rounded, color: AppColors.textPrimary, size: 22),
            SizedBox(width: 10),
            Text('Règles de Solidarité',
              style: TextStyle(
                fontFamily: 'Manrope', fontSize: 18,
                fontWeight: FontWeight.w800, color: AppColors.textPrimary,
              )),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.08)),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
            children: List.generate(regles.length, (i) {
              final r = regles[i];
              final isLast = i == regles.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: r.iconBg, shape: BoxShape.circle),
                          child: Icon(r.icon, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.titre,
                                style: const TextStyle(
                                  fontFamily: 'Manrope', fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                )),
                              const SizedBox(height: 4),
                              Text(r.description,
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.8),
                                  height: 1.5,
                                )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(height: 1,
                        color: AppColors.primary.withValues(alpha: 0.07),
                        indent: 16, endIndent: 16),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIANCE TECHNIQUE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildConfianceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Confiance Technique',
          style: TextStyle(
            fontFamily: 'Manrope', fontSize: 18,
            fontWeight: FontWeight.w800, color: AppColors.textPrimary,
          )),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.08)),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
            children: [
              // Open Source
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_open_outlined,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('Open Source',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                        fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                      ))),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDFF3E3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Vérifié',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A7A35),
                      ))),
                ],
              ),
              Divider(height: 24,
                  color: AppColors.primary.withValues(alpha: 0.07)),

              // Audit CertiK
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.security_rounded,
                        color: AppColors.tertiary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('Audit CertiK',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                        fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                      ))),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Score 98',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                        fontWeight: FontWeight.w700, color: AppColors.tertiary,
                      ))),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                'Ce contrat est immuable. Personne, pas même TontineChain, '
                'ne peut accéder aux fonds sans le consentement '
                'cryptographique des membres.',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  height: 1.55,
                )),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REGISTRE BLOCKCHAIN
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildRegistreSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Registre de la\nBlockchain',
          style: TextStyle(
            fontFamily: 'Manrope', fontSize: 22,
            fontWeight: FontWeight.w800, color: AppColors.textPrimary,
            height: 1.2,
          )),
        const SizedBox(height: 6),
        Text(
          'Toutes les opérations sont enregistrées de façon permanente.',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 13,
            color: AppColors.textSecondary.withValues(alpha: 0.8),
          )),
        const SizedBox(height: 16),

        // Bouton Polygonscan
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ouverture Polygonscan — bientôt disponible'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Explorer sur Polygonscan',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                fontWeight: FontWeight.w700,
              )),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Tableau avec FutureBuilder
        _buildTableauBlockchain(context),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TABLEAU SCROLLABLE HORIZONTAL — FutureBuilder
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTableauBlockchain(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FutureBuilder<List<Object>>(
          future: Future.wait([
            MockTontineService().getHistoricPayments(tontine.id),
            MockTontineService().getMembers(tontine.id),
          ]),
          builder: (context, snapshot) {
            // ── Chargement ─────────────────────────────────────────────────
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 120,
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2.5)));
            }

            final payments = (snapshot.data?[0] as List<Payment>?) ?? [];
            final members  = (snapshot.data?[1] as List<Member>?)  ?? [];

            // ── Vide ────────────────────────────────────────────────────────
            if (payments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        color: AppColors.primary.withValues(alpha: 0.3),
                        size: 40),
                    const SizedBox(height: 10),
                    const Text('Aucune opération récente',
                      style: TextStyle(
                        fontFamily: 'Manrope', fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
                  ],
                ),
              );
            }

            // Tri par date desc
            payments.sort((a, b) =>
                b.paymentDate.compareTo(a.paymentDate));
            final displayedPayments =
                payments.length > 8 ? payments.sublist(0, 8) : payments;

            // ── Tableau scrollable ──────────────────────────────────────────
            return Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête colonnes
                      Container(
                        color: AppColors.primary.withValues(alpha: 0.04),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: const Row(
                          children: [
                            _TableHeader(label: 'DATE',    width: 80),
                            SizedBox(width: 16),
                            _TableHeader(label: 'MEMBRE',  width: 150),
                            SizedBox(width: 16),
                            _TableHeader(label: 'ACTION',  width: 110),
                            SizedBox(width: 16),
                            _TableHeader(label: 'MONTANT', width: 110,
                                align: TextAlign.right),
                          ],
                        ),
                      ),

                      // Lignes de données
                      ...List.generate(displayedPayments.length, (i) {
                        final p = displayedPayments[i];
                        final isLast = i == displayedPayments.length - 1;

                        // Trouver le membre
                        final member = members.firstWhere(
                          (m) => m.id == p.memberId,
                          orElse: () => Member(
                            id: p.memberId, tontineId: tontine.id,
                            name: 'Membre', email: '', phone: '',
                            profileImageUrl: '', role: 'participant',
                            joinedAt: DateTime.now(), isPaid: true,
                            allocationOrder: 0, allocationStatus: 'waiting',
                          ),
                        );

                        final bool isCotisation =
                            !p.transactionId.startsWith('reception');
                        final String action =
                            isCotisation ? 'Cotisation' : 'Déblocage';

                        // Date formatée
                        final String dateStr =
                            '${p.paymentDate.day.toString().padLeft(2, '0')} '
                            '${_monthAbbr(p.paymentDate.month)}\n'
                            '${p.paymentDate.year}';
                        final String heureStr =
                            '${p.paymentDate.hour.toString().padLeft(2, '0')}:'
                            '${p.paymentDate.minute.toString().padLeft(2, '0')}';

                        // Initiales membre
                        final parts = member.name.trim().split(' ');
                        final initiales = parts.length >= 2
                            ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
                            : (member.name.isNotEmpty
                                ? member.name[0].toUpperCase()
                                : 'M');

                        // Couleur avatar
                        final avatarColors = [
                          const Color(0xFFFFB300), const Color(0xFF26A69A),
                          const Color(0xFF66BB6A), const Color(0xFF7E57C2),
                          const Color(0xFFEF5350), const Color(0xFF42A5F5),
                        ];
                        final avatarColor =
                            avatarColors[i % avatarColors.length];

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // DATE
                                  SizedBox(
                                    width: 80,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(dateStr,
                                          style: const TextStyle(
                                            fontFamily: 'Plus Jakarta Sans',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                            height: 1.3,
                                          )),
                                        Text(heureStr,
                                          style: TextStyle(
                                            fontFamily: 'Plus Jakarta Sans',
                                            fontSize: 11,
                                            color: AppColors.textSecondary
                                                .withValues(alpha: 0.6),
                                          )),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // MEMBRE
                                  SizedBox(
                                    width: 150,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: avatarColor
                                              .withValues(alpha: 0.18),
                                          child: Text(initiales,
                                            style: TextStyle(
                                              fontFamily: 'Manrope',
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: avatarColor,
                                            )),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(member.name,
                                            style: const TextStyle(
                                              fontFamily: 'Plus Jakarta Sans',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // ACTION badge
                                  SizedBox(
                                    width: 110,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isCotisation
                                            ? const Color(0xFFE8F5E9)
                                            : const Color(0xFFFFF8E1),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6, height: 6,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isCotisation
                                                  ? const Color(0xFF1A7A35)
                                                  : const Color(0xFF8D6E00),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(action,
                                            style: TextStyle(
                                              fontFamily: 'Plus Jakarta Sans',
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isCotisation
                                                  ? const Color(0xFF1A7A35)
                                                  : const Color(0xFF8D6E00),
                                            )),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // MONTANT
                                  SizedBox(
                                    width: 110,
                                    child: Text(
                                      '${_formatMontant(p.amount)} FCFA',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontFamily: 'Manrope', fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      )),
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast)
                              Divider(height: 1,
                                  color: AppColors.primary
                                      .withValues(alpha: 0.07)),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM NAV (Contrats = index 3)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBottomNavBar(BuildContext context) {
    const int selectedIndex = 3;
    const destinations = [
      _NavItem(icon: Icons.grid_view_rounded,     label: 'Accueil'),
      _NavItem(icon: Icons.explore_outlined,      label: 'Explorer'),
      _NavItem(icon: Icons.add_circle_outline,    label: 'Créer'),
      _NavItem(icon: Icons.receipt_long_outlined, label: 'Contrats'),
      _NavItem(icon: Icons.person_outline,        label: 'Profil'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(destinations.length, (index) {
              final dest       = destinations[index];
              final isSelected = index == selectedIndex;
              final isCenter   = index == 2;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!isSelected) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => AppShell(initialIndex: index),
                        ),
                      );
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      isCenter
                          ? Container(
                              width: 40, height: 40,
                              decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle),
                              child: Icon(dest.icon,
                                  color: Colors.white, size: 22))
                          : Icon(dest.icon,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary
                                      .withValues(alpha: 0.5),
                              size: 24),
                      const SizedBox(height: 4),
                      Text(dest.label,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans', fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary
                                  .withValues(alpha: 0.5),
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

  // ── Helpers ────────────────────────────────────────────────────────────────
  static String _monthAbbr(int month) {
    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
    ];
    return months[month - 1];
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS PRIVÉS
// ══════════════════════════════════════════════════════════════════════════════

/// En-tête colonne tableau
class _TableHeader extends StatelessWidget {
  final String label;
  final double width;
  final TextAlign align;

  const _TableHeader({
    required this.label,
    required this.width,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(label,
        textAlign: align,
        style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans', fontSize: 10,
          fontWeight: FontWeight.w700, color: AppColors.textSecondary,
          letterSpacing: 1.2,
        )),
    );
  }
}

class _RegleItem {
  final IconData icon;
  final Color iconBg;
  final String titre;
  final String description;
  const _RegleItem({
    required this.icon, required this.iconBg,
    required this.titre, required this.description,
  });
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTER — Motif losanges
// ─────────────────────────────────────────────────────────────────────────────
class _DiamondPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    const double spacing = 34.0;
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