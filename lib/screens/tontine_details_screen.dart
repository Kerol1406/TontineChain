import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:tontinechain/constants/app_colors.dart';
import 'package:tontinechain/models/index.dart';
import 'package:tontinechain/screens/cotisation_payment_screen.dart';
import 'package:tontinechain/screens/notifications_screen.dart';
import 'package:tontinechain/screens/reception_cagnotte_screen.dart';
import 'package:tontinechain/screens/contrat_smart_screen.dart';
import 'package:tontinechain/services/backend_service.dart';
import 'package:tontinechain/services/auth_state.dart';
import 'package:tontinechain/services/firestore_database_service.dart';
import 'package:tontinechain/widgets/invite_share_dialog.dart';

// ═══════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════
String _formatAllocationDate(dynamic dateAllocation) {
  try {
    DateTime dateTime;
    if (dateAllocation is String) {
      dateTime = DateTime.parse(dateAllocation);
    } else if (dateAllocation is int) {
      dateTime = DateTime.fromMillisecondsSinceEpoch(dateAllocation);
    } else {
      // Try to convert to string and parse (handles Firestore Timestamp)
      String dateStr = dateAllocation.toString();
      if (dateStr.contains('Timestamp')) {
        // Handle Firestore Timestamp toString format
        // Format is like: Timestamp(seconds=1704067200, nanoseconds=0)
        final secondsMatch = RegExp(r'seconds=(\d+)').firstMatch(dateStr);
        if (secondsMatch != null) {
          final seconds = int.parse(secondsMatch.group(1)!);
          dateTime = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        } else {
          return 'Date';
        }
      } else {
        dateTime = DateTime.parse(dateStr);
      }
    }
    
    final months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin',
                    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    final month = months[dateTime.month - 1].toUpperCase();
    return '$month ${dateTime.year}';
  } catch (e) {
    return 'Date';
  }
}

bool _isTontineLaunchedForUi(Tontine tontine) {
  final status = tontine.status.trim().toLowerCase();
  final maxMembers = tontine.maxMembers ?? tontine.memberCount;
  return status == 'active' ||
      status == 'en_cours' ||
      status == 'en cours' ||
      status == 'started' ||
      (maxMembers > 0 && tontine.memberCount >= maxMembers) ||
      tontine.currentCycle > 0;
}

class TontineDetailsScreen extends StatefulWidget {
  final Tontine tontine;

  const TontineDetailsScreen({super.key, required this.tontine});

  @override
  State<TontineDetailsScreen> createState() => _TontineDetailsScreenState();
}

class _TontineDetailsScreenState extends State<TontineDetailsScreen> with WidgetsBindingObserver {
  final FirestoreDatabaseService _db = FirestoreDatabaseService.instance;
  late Future<List<Map<String, dynamic>>> _membersFuture;
  late Future<List<Map<String, dynamic>>> _allocationFuture;
  bool _showJoinRequests = false;

  bool _isTontineLaunched(Tontine tontine) {
    final status = tontine.status.trim().toLowerCase();
    final maxMembers = tontine.maxMembers ?? tontine.memberCount;
    return status == 'active' ||
        status == 'en_cours' ||
        status == 'en cours' ||
        status == 'started' ||
        (maxMembers > 0 && tontine.memberCount >= maxMembers) ||
        tontine.currentCycle > 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _membersFuture = _loadMembers();
    _allocationFuture = _db.getAllocationCalendar(widget.tontine.id);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Recharger les données quand l'app reprend au premier plan
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {
        _membersFuture = _loadMembers();
        _allocationFuture = _db.getAllocationCalendar(widget.tontine.id);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadMembers() async {
    try {
      final members = await _db.getTontineMembersWithPayments(widget.tontine.id);
      final enrichedMembers = <Map<String, dynamic>>[];

      for (final member in members) {
        final memberWallet = (member['userId'] ?? '').toString();
        var score = 40;

        if (memberWallet.isNotEmpty) {
          try {
            final response = await BackendService.instance.getUserGlobalScore(memberWallet);
            final globalScore = response['globalScore'];
            if (globalScore is Map) {
              score = (globalScore['score'] as num?)?.toInt() ?? 40;
            }
          } catch (_) {
            score = 40;
          }
        }

        enrichedMembers.add({
          ...member,
          'score': score,
        });
      }

      return enrichedMembers;
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().currentUser;
    final String userName = (user?['name'] ?? 'Utilisateur').toString();
    final String userPhone = (user?['phone'] ?? '').toString();

    final tontine = widget.tontine;
    final int maxMembers = tontine.maxMembers ?? tontine.memberCount;
    final double occupancy = maxMembers == 0 ? 0.0 : tontine.memberCount / maxMembers;
    final double totalAmount = tontine.monthlyAmount * tontine.memberCount;
    final String creatorName = tontine.creatorName ?? 'Amadou Diop';
    final int cycleMonths = _cycleMonths(tontine.frequency);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Détails de la Tontine',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
            fontSize: 19,
            color: Colors.black,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Colors.black87, size: 24),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _DotsBackgroundPainter()),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(
                  tontine: tontine,
                  creatorName: creatorName,
                  totalAmount: totalAmount,
                  occupancy: occupancy,
                ),
                const SizedBox(height: 20),
                _buildActionButtons(currentUserPhone: userPhone),
                const SizedBox(height: 20),
                if (!_isTontineLaunched(tontine))
                  _buildInviteCard(context, tontine)
                else
                  _buildTransactionButton(context),
                const SizedBox(height: 16),
                _buildJoinRequestsPanel(
                  context,
                  tontine,
                  canManage: (user?['uid'] ?? '').toString() == tontine.creatorId,
                ),
                const SizedBox(height: 26),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(
                      child: Text(
                        'Calendrier des Allocations',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    Text(
                      'Cycle de $cycleMonths mois',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _AllocationTimelineCard(
                  tontine: tontine,
                  currentUserName: userName,
                  allocationFuture: _allocationFuture,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Membres Actifs',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 14),
                _MembersPanel(
                  tontine: tontine,
                  membersFuture: _membersFuture,
                  currentUserName: userName,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard({
    required Tontine tontine,
    required String creatorName,
    required double totalAmount,
    required double occupancy,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: const Color(0xFF003D2D),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DiamondPatternPainter())),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D5D45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'PATRIMOINE ACTIF',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9BC7B6),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                tontine.name,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 33,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 0.98,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Créé par $creatorName - ${tontine.memberCount} Membres',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFB7D4CB),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Montant Total de la Tontine',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF8D44A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrencyCompact(totalAmount),
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF8D44A),
                            letterSpacing: -1.0,
                            height: 0.9,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text(
                            'CFA',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF8D44A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              LinearProgressIndicator(
                value: occupancy,
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.11),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF8D44A)),
                borderRadius: BorderRadius.circular(999),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons({required String currentUserPhone}) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: ouvrir la discussion (non implémenté)
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: AppColors.primary.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                  label: const Text(
                    'Discussion',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContratSmartScreen(
                          tontine: widget.tontine,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF8D44A),
                    foregroundColor: const Color(0xFF5F4A00),
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.description_outlined, size: 20),
                  label: const Text(
                    'Voir le contrat',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInviteCard(BuildContext context, Tontine tontine) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.people_outline_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inviter des membres',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tontine.memberCount} / ${tontine.maxMembers ?? tontine.memberCount} membres',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Partagez l\'invitation avec vos proches pour compléter votre tontine.',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) => InviteShareDialog(tontine: tontine),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: AppColors.primary.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text(
                'Partager l\'invitation',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionButton(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F5D47).withValues(alpha: 0.1),
            const Color(0xFF0F5D47).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFF0F5D47).withValues(alpha: 0.3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F5D47).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.payment_outlined,
                  color: Color(0xFF0F5D47),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Effectuer une transaction',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tontine active - Cotisez maintenant',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'La tontine a commencé. Effectuez votre cotisation à temps pour éviter les pénalités.',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CotisationPaymentScreen(
                      tontine: widget.tontine,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F5D47),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFF0F5D47).withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text(
                'Effectuer ma cotisation',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinRequestsPanel(
    BuildContext context,
    Tontine tontine, {
    required bool canManage,
  }) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.watchTontineJoinRequests(tontine.id),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const <Map<String, dynamic>>[];
        final pendingCount = requests.where((r) => (r['statut'] ?? 'PENDING').toString().toUpperCase() == 'PENDING').length;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7E1D6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec bouton toggle
              GestureDetector(
                onTap: () => setState(() => _showJoinRequests = !_showJoinRequests),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Demandes d\'adhésion',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pendingCount > 0 ? '$pendingCount demande${pendingCount > 1 ? 's' : ''} en attente' : 'Aucune demande',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _showJoinRequests ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ],
                ),
              ),
              // Contenu déroulable
              if (_showJoinRequests) ...[
                const SizedBox(height: 12),
                if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Erreur: ${snapshot.error}',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  )
                else if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: SizedBox(height: 40, child: CircularProgressIndicator()))
                else if (requests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Aucune demande pour le moment.',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  ...requests.map((req) {
                    final id = (req['id'] ?? '').toString();
                    final userName = (req['userName'] ?? 'Utilisateur').toString();
                    final trustScore = ((req['trustScore'] as num?)?.toDouble() ?? 0).round();
                    final status = (req['statut'] ?? 'PENDING').toString().toUpperCase();
                    final canDecide = canManage && status == 'PENDING';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F7F1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE7E1D6), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.stars_rounded,
                                size: 16,
                                color: const Color(0xFFF8D44A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Score de confiance: $trustScore/100',
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          if (canDecide) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _handleJoinRequestDecision(id, false),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: AppColors.error),
                                    ),
                                    child: const Text(
                                      'Refuser',
                                      style: TextStyle(color: AppColors.error),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _handleJoinRequestDecision(id, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Accepter'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleJoinRequestDecision(String requestId, bool accept) async {
    if (requestId.isEmpty) return;
    final currentUser = context.read<AuthState>().currentUser;
    final handledBy = (currentUser?['uid'] ?? currentUser?['userId'] ?? '').toString();
    if (handledBy.isEmpty) return;

    try {
      if (accept) {
        await _db.acceptJoinRequest(requestId: requestId, handledBy: handledBy);
      } else {
        await _db.rejectJoinRequest(requestId: requestId, handledBy: handledBy);
      }

      if (mounted) {
        setState(() {
          _membersFuture = _loadMembers();
          _allocationFuture = _db.getAllocationCalendar(widget.tontine.id);
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Demande acceptée' : 'Demande refusée'),
          backgroundColor: accept ? AppColors.primary : AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Action impossible: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  static String _formatCurrencyCompact(num amount) {
    return amount.round().toString().replaceAllMapped(
          RegExp(r'(?<=\d)(?=(\d{3})+$)'),
          (match) => ' ',
        );
  }

  static String _formatCurrency(num amount) {
    return amount.round().toString().replaceAllMapped(
          RegExp(r'(?<=\d)(?=(\d{3})+$)'),
          (match) => '.',
        );
  }

  static int _cycleMonths(String? frequency) {
    final value = (frequency ?? '').toLowerCase();
    if (value.contains('jour')) return 1;
    if (value.contains('heb')) return 3;
    if (value.contains('trim')) return 3;
    return 12;
  }
}

class _AllocationTimelineCard extends StatelessWidget {
  final Tontine tontine;
  final String currentUserName;
  final Future<List<Map<String, dynamic>>> allocationFuture;

  const _AllocationTimelineCard({
    required this.tontine,
    required this.currentUserName,
    required this.allocationFuture,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: allocationFuture,
      builder: (context, snapshot) {
        final allocationSlots = snapshot.data ?? const <Map<String, dynamic>>[];
        final timeline = _buildTimelineItems(allocationSlots);

        if (timeline.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const SizedBox(
              height: 220,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy_outlined, size: 42, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text(
                    'Aucun membre pour le moment',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Le calendrier restera vide jusqu\'à ce que des membres rejoignent la tontine.',
                    textAlign: TextAlign.center,
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
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SizedBox(
            height: 430,
            child: Stack(
              children: [
                Positioned(
                  left: 24,
                  top: 14,
                  bottom: 10,
                  child: Container(
                    width: 2,
                    color: const Color(0xFFE6E1D7),
                  ),
                ),
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: timeline.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = timeline[index];
                    return _TimelineItemRow(
                      item: item,
                      isFirst: index == 0,
                      isCurrent: item.isCurrent,
                      isPast: item.isPast,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_TimelineItem> _buildTimelineItems(List<Map<String, dynamic>> allocationSlots) {
    if (allocationSlots.isEmpty) {
      return const [];
    }

    final currentUserFirstName = currentUserName.trim().split(' ').first.toLowerCase();

    return allocationSlots.map((slot) {
      final displayName = (slot['displayName'] ?? slot['userId'] ?? 'Membre').toString();
      final userId = (slot['userId'] ?? '').toString();
      final rang = (slot['rang'] as num?)?.toInt() ?? 0;
      final dateAllocation = slot['dateAllocation'];
      final isReceived = slot['isReceived'] == true || (slot['status'] ?? '').toString().toUpperCase() == 'RECU';
      final isCurrentUser = displayName.toLowerCase().contains(currentUserFirstName) ||
          userId.toLowerCase() == currentUserFirstName;

      final monthLabel = dateAllocation == null ? 'Tour $rang' : _formatAllocationDate(dateAllocation);
      final statusLabel = isReceived
          ? 'Reçu'
          : (slot['statusLabel'] ?? (rang == 1 ? 'Premier tour' : 'Rang $rang')).toString();

      return _TimelineItem(
        month: monthLabel,
        name: isCurrentUser ? 'Vous ($displayName)' : displayName,
        statusLabel: statusLabel,
        progress: isReceived ? 1 : (rang == 1 ? 1 : 0),
        color: isReceived
            ? const Color(0xFFEAF5EE)
            : (rang == 1 ? const Color(0xFFEFEDE6) : const Color(0xFFF5F5F3)),
        isPast: isReceived || rang == 1,
        isCurrent: isReceived || rang == 1,
      );
    }).toList(growable: false);
  }
}

class _TimelineItemRow extends StatelessWidget {
  final _TimelineItem item;
  final bool isFirst;
  final bool isCurrent;
  final bool isPast;

  const _TimelineItemRow({
    required this.item,
    required this.isFirst,
    required this.isCurrent,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = isCurrent
      ? (item.statusLabel == 'Reçu' ? const Color(0xFF128A3A) : const Color(0xFFF8D44A))
        : item.progress >= 1
            ? const Color(0xFF5C8C7B)
            : const Color(0xFFB8C0BA);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  item.statusLabel == 'Reçu'
                    ? Icons.check_circle_rounded
                    : isCurrent
                      ? Icons.star_rounded
                      : item.progress >= 1
                        ? Icons.check_rounded
                        : Icons.circle_outlined,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(16),
                border: item.statusLabel == 'Reçu'
                  ? Border.all(color: const Color(0xFF128A3A), width: 1.6)
                  : isCurrent
                  ? Border.all(color: const Color(0xFFF8D44A), width: 1.6)
                  : Border.all(color: Colors.transparent),
              boxShadow: isPast
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.month,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: item.statusLabel == 'Reçu'
                              ? const Color(0xFF128A3A)
                              : isCurrent
                                  ? const Color(0xFF8A6F00)
                                  : const Color(0xFFA9B5B0),
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.name,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: isCurrent ? 18 : 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.15,
                        ),
                      ),
                      if (item.progress > 0 && item.progress < 1) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: item.progress,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFE7E2D7),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF8D44A)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCurrent ? const Color(0xFFFFF0C2) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: isCurrent
                        ? Border.all(color: const Color(0xFFF8D44A), width: 1)
                        : Border.all(color: const Color(0xFFE3DED3), width: 1),
                  ),
                  child: Text(
                    item.statusLabel,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: item.statusLabel == 'Reçu'
                          ? const Color(0xFF128A3A)
                          : isCurrent
                              ? const Color(0xFF8A6F00)
                              : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MembersPanel extends StatelessWidget {
  final Tontine tontine;
  final Future<List<Map<String, dynamic>>> membersFuture;
  final String currentUserName;

  const _MembersPanel({
    required this.tontine,
    required this.membersFuture,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    final isLaunched = _isTontineLaunchedForUi(tontine);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: membersFuture,
      builder: (context, memberSnapshot) {
        final members = memberSnapshot.data ?? const <Map<String, dynamic>>[];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
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
              if (memberSnapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else if (members.isEmpty)
                _buildEmptyMembersState(context, showInviteButton: !isLaunched)
              else ...[
                ..._buildMemberRows(members),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyMembersState(BuildContext context, {required bool showInviteButton}) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F7F1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF0EBDD)),
          ),
          child: const Column(
            children: [
              Icon(Icons.group_off_outlined, size: 40, color: AppColors.textSecondary),
              SizedBox(height: 10),
              Text(
                'Aucun membre encore',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Après création, invitez des membres pour voir le calendrier et les statuts de paiement.',
                textAlign: TextAlign.center,
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
        if (showInviteButton) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => InviteShareDialog(tontine: tontine),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF8D44A),
                foregroundColor: const Color(0xFF5F4A00),
                elevation: 3,
                shadowColor: Colors.black.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: const Text(
                'Inviter des membres',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildMemberRows(List<Map<String, dynamic>> members) {
    final highlightedName = currentUserName.toLowerCase();

    final displayMembers = members.map((member) {
      final memberName = (member['displayName'] ?? member['name'] ?? 'Membre').toString();
      final isCurrentUser = memberName.toLowerCase().contains(highlightedName.split(' ').first) || memberName.toLowerCase().contains('vous');
      final bool isPaid = (member['isPaid'] as bool?) ?? false;
      final statusDate = member['statusDate'];
      final score = (member['score'] as num?)?.toInt() ?? 40;
      final role = (member['role'] ?? 'Membre actif').toString();
      return _MemberDisplay(
        name: isCurrentUser ? 'Vous (Moi)' : memberName,
        subtitle: role == 'Créateur' || role == 'organizer' ? 'Créateur' : 'Membre actif',
        status: isPaid ? 'Payé' : 'En attente',
        statusDate: _formatMemberDate(statusDate),
        isPaid: isPaid,
        highlighted: isCurrentUser,
        score: score,
      );
    }).toList();

    return displayMembers.map((member) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _MemberRow(display: member),
      );
    }).toList();
  }
}

class _MemberRow extends StatelessWidget {
  final _MemberDisplay display;

  const _MemberRow({required this.display});

  @override
  Widget build(BuildContext context) {
    final borderColor = display.highlighted
        ? const Color(0xFFF8D44A)
        : const Color(0xFFF0EBDD);
    final statusColor = display.isPaid ? const Color(0xFF128A3A) : const Color(0xFF8A6F00);
    final scoreColor = display.score >= 80
      ? const Color(0xFF128A3A)
      : display.score >= 60
        ? const Color(0xFF8A6F00)
        : const Color(0xFFC4582E);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFEDE9E1),
            child: Icon(
              display.highlighted ? Icons.person_rounded : Icons.person_outline_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  display.name,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF0E9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    display.subtitle,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: scoreColor.withValues(alpha: 0.18)),
                  ),
                  child: Text(
                    'Score ${display.score}/100',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: scoreColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                display.statusDate,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                display.status,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberDisplay {
  final String name;
  final String subtitle;
  final String status;
  final String statusDate;
  final bool isPaid;
  final bool highlighted;
  final int score;

  const _MemberDisplay({
    required this.name,
    required this.subtitle,
    required this.status,
    required this.statusDate,
    required this.isPaid,
    required this.score,
    this.highlighted = false,
  });
}

String _formatMemberDate(dynamic value) {
  final date = _parseMemberDate(value);
  if (date == null) return 'Date indisponible';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day/$month/$year';
}

DateTime? _parseMemberDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    return DateTime.tryParse(value);
  }

  final text = value.toString();
  final match = RegExp(r'seconds=(\d+)').firstMatch(text);
  if (match != null) {
    final seconds = int.tryParse(match.group(1)!);
    if (seconds != null) {
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
  }

  return DateTime.tryParse(text);
}

class _TimelineItem {
  final String month;
  final String name;
  final String statusLabel;
  final double progress;
  final Color color;
  final bool isCurrent;
  final bool isPast;

  const _TimelineItem({
    required this.month,
    required this.name,
    required this.statusLabel,
    required this.progress,
    required this.color,
    this.isCurrent = false,
    this.isPast = false,
  });
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
