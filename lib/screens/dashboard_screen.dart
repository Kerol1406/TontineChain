import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tontinechain/models/index.dart';
import 'package:tontinechain/constants/app_colors.dart';
import 'package:tontinechain/services/auth_state.dart';
import 'package:tontinechain/services/tontine_service.dart';
import 'package:tontinechain/screens/contracts_list_screen.dart';
import 'package:tontinechain/screens/explorer_screen.dart';
import 'package:tontinechain/screens/tontine_details_screen.dart';

/// Tableau de bord TontineChain, calé sur la maquette.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().currentUser;
    final String userName = (user?['name'] ?? 'Utilisateur').toString();
    final visibleTontines = _visibleTontines(context);
    final nextTourGroupName = _nextTourGroupName(visibleTontines);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _DashboardDotsPainter()),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGreeting(userName),
                  const SizedBox(height: 18),
                  _buildPatrimoineCard(),
                  const SizedBox(height: 28),
                  _buildTontinesSection(context, visibleTontines),
                  const SizedBox(height: 24),
                  _buildNextTourSection(nextTourGroupName),
                  const SizedBox(height: 24),
                  _buildActionPanel(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildGreeting(String name) {
    final String firstName = name.trim().isEmpty
        ? 'Utilisateur'
        : name.trim().split(RegExp(r'\s+')).first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BIENVENUE DANS VOTRE PATRIMOINE',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Bonjour, $firstName !',
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 31,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.9,
            height: 0.98,
          ),
        ),
      ],
    );
  }

  static Widget _buildPatrimoineCard() {
    return Container(
      width: double.infinity,
      height: 402,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF033A2A), Color(0xFF0A533E), Color(0xFF043325)],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _DiamondPatternPainter())),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PATRIMOINE\nTOTAL',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white54,
                                height: 1.05,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              '2 450\n000',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 0.88,
                                letterSpacing: -1.2,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'FCFA',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 118),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8D44A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.verified_outlined,
                                size: 15, color: Color(0xFF6E5800)),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'SÉCURISÉ\nPAR\nBLOCKCHAIN',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF5F4A00),
                                  height: 1.05,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      _WealthMetric(
                        label: 'Total épargné',
                        value: '1 800 000\nFCFA',
                        alignRight: false,
                      ),
                      _WealthMetric(
                        label: 'Total reçu',
                        value: '650 000 FCFA',
                        alignRight: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<Tontine> _visibleTontines(BuildContext context) {
    final user = context.read<AuthState>().currentUser ?? {};
    final String phone = (user['phone'] ?? '').toString();
    final service = MockTontineService();
    final userTontines = service.getTontinesForUserSync(phone);

    final demoTontines = <Tontine>[
      Tontine(
        id: 'demo_001',
        name: 'Cercle "Les Entrepreneurs"',
        description: 'Démo dashboard',
        memberCount: 12,
        maxMembers: 15,
        monthlyAmount: 50000,
        status: 'active',
        createdAt: DateTime.now(),
        creatorId: 'demo',
        creatorName: 'Demo',
        frequency: 'mois',
        rating: 4.9,
      ),
      Tontine(
        id: 'demo_002',
        name: 'Fond Immobilier Familial',
        description: 'Démo dashboard',
        memberCount: 8,
        maxMembers: 8,
        monthlyAmount: 200000,
        status: 'active',
        createdAt: DateTime.now(),
        creatorId: 'demo',
        creatorName: 'Demo',
        frequency: 'trimestre',
        rating: 4.7,
      ),
    ];

    return userTontines.isNotEmpty ? userTontines : demoTontines;
  }

  static String _nextTourGroupName(List<Tontine> tontines) {
    final demoReception = tontines.where((t) => t.id == 'tontine_tour_reception').toList();
    if (demoReception.isNotEmpty) {
      return demoReception.first.name;
    }
    if (tontines.isNotEmpty) {
      return tontines.first.name;
    }
    return 'Tontine Tour Réception';
  }

  static Widget _buildTontinesSection(BuildContext context, List<Tontine> visibleTontines) {
    final int activeCount = visibleTontines.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tontines Actives',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$activeCount cercles en cours',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ActiveTontinesDropdownList(
          tontines: visibleTontines,
          onTapTontine: (tontine) => _openTontineDetails(context, tontine),
        ),
      ],
    );
  }

  static void _openTontineDetails(BuildContext context, Tontine tontine) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TontineDetailsScreen(tontine: tontine),
      ),
    );
  }

  static String _formattedFrequency(String frequency) {
    final value = frequency.trim().toLowerCase();
    if (value == 'mois' || value == 'mensuel') return 'mois';
    if (value == 'trimestre' || value == 'trimestriel') return 'trimestre';
    if (value == 'hebdo' || value == 'hebdomadaire') return 'semaine';
    return value;
  }

  static Widget _buildNextTourSection(String groupName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0EA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF857000), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Votre prochain tour',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD8CFBC)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECDFA9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.groups_rounded, size: 18, color: Color(0xFF6D5700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Groupe concerné',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        groupName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: SizedBox(
              width: 146,
              height: 146,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 146,
                    height: 146,
                    child: CircularProgressIndicator(
                      value: 0.75,
                      strokeWidth: 9,
                      backgroundColor: const Color(0xFFE6E0D6),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF8A6F00),
                      ),
                    ),
                  ),
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'DANS',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '12',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 0.92,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'JOURS',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Date de réception prévue',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              '15 Juillet 2024',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE3E0D8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Text(
                  'MONTANT À RECEVOIR',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C8B84),
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '600 000 FCFA',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8A6F00),
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildActionPanel(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExplorerScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, size: 21),
                  SizedBox(width: 10),
                  Text(
                    'Rejoindre un nouveau cercle',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ContractsListScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD6D0C5), width: 1.2),
                foregroundColor: AppColors.textPrimary,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Voir mes contrats',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WealthMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool alignRight;

  const _WealthMetric({
    required this.label,
    required this.value,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _ActiveTontineCard extends StatelessWidget {
  final Tontine tontine;
  final IconData icon;
  final String statusLabel;
  final Color statusColor;
  final Color participantsColor;
  final String subtitle;
  final VoidCallback onTap;

  const _ActiveTontineCard({
    required this.tontine,
    required this.icon,
    required this.statusLabel,
    required this.statusColor,
    required this.participantsColor,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final int maxMembers = tontine.maxMembers ?? tontine.memberCount;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EEE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tontine.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${tontine.memberCount} / $maxMembers participants',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: participantsColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveTontinesDropdownList extends StatefulWidget {
  final List<Tontine> tontines;
  final ValueChanged<Tontine> onTapTontine;

  const _ActiveTontinesDropdownList({
    required this.tontines,
    required this.onTapTontine,
  });

  @override
  State<_ActiveTontinesDropdownList> createState() =>
      _ActiveTontinesDropdownListState();
}

class _ActiveTontinesDropdownListState extends State<_ActiveTontinesDropdownList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final int total = widget.tontines.length;
    final int collapsedCount = total > 3 ? 3 : total;
    final List<Tontine> collapsedItems = widget.tontines.take(collapsedCount).toList();
    final double desiredHeight = total * 110.0;
    final double maxHeight = desiredHeight > 420 ? 420 : desiredHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Column(
            children: collapsedItems.asMap().entries.map((entry) {
              final index = entry.key;
              final tontine = entry.value;
              final bool first = index == 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _ActiveTontineCard(
                  tontine: tontine,
                  icon: first ? Icons.groups_rounded : Icons.home_rounded,
                  statusLabel: first ? 'EN REGLE' : 'COLLECTE',
                  statusColor:
                      first ? const Color(0xFFCBEFD9) : const Color(0xFFF5DD8D),
                  participantsColor:
                      first ? AppColors.primary : AppColors.secondaryDark,
                  subtitle:
                      'Cotisation : ${tontine.monthlyAmount.toInt()} FCFA / ${DashboardScreen._formattedFrequency(tontine.frequency ?? '')}',
                  onTap: () => widget.onTapTontine(tontine),
                ),
              );
            }).toList(),
          ),
          secondChild: SizedBox(
            height: maxHeight,
            child: ListView.separated(
              itemCount: widget.tontines.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final tontine = widget.tontines[index];
                final bool first = index == 0;
                return _ActiveTontineCard(
                  tontine: tontine,
                  icon: first ? Icons.groups_rounded : Icons.home_rounded,
                  statusLabel: first ? 'EN REGLE' : 'COLLECTE',
                  statusColor:
                      first ? const Color(0xFFCBEFD9) : const Color(0xFFF5DD8D),
                  participantsColor:
                      first ? AppColors.primary : AppColors.secondaryDark,
                  subtitle:
                      'Cotisation : ${tontine.monthlyAmount.toInt()} FCFA / ${DashboardScreen._formattedFrequency(tontine.frequency ?? '')}',
                  onTap: () => widget.onTapTontine(tontine),
                );
              },
              separatorBuilder: (_, index) => const SizedBox(height: 14),
            ),
          ),
        ),
        if (total > 3)
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: AppColors.primary,
              ),
              label: Text(
                _expanded
                    ? 'Reduire la liste'
                    : 'Voir toutes les tontines ($total)',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DashboardDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8E1D7).withValues(alpha: 0.85)
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

class _DiamondPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const double spacing = 34;
    const double half = spacing / 2;

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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}