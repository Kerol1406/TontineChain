import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tontinechain/constants/app_colors.dart';
import 'package:tontinechain/models/tontine.dart';
import 'package:tontinechain/services/auth_state.dart';
import 'package:tontinechain/services/firestore_database_service.dart';

class JoinTontineScreen extends StatefulWidget {
  final Tontine tontine;

  const JoinTontineScreen({super.key, required this.tontine});

  @override
  State<JoinTontineScreen> createState() => _JoinTontineScreenState();
}

class _JoinTontineScreenState extends State<JoinTontineScreen> {
  final List<bool> _checks = List<bool>.filled(5, false);
  bool _joining = false;
  bool _requestSent = false;
  final FirestoreDatabaseService _db = FirestoreDatabaseService.instance;

  @override
  void initState() {
    super.initState();
    _checkExistingRequest();
  }

  Future<void> _checkExistingRequest() async {
    try {
      final userId = context.read<AuthState>().currentUser?['uid']?.toString();
      if (userId == null || userId.isEmpty) return;

      final requests = await _db.watchTontineJoinRequests(widget.tontine.id).first;
      Map<String, dynamic>? existingRequest;
      for (final req in requests) {
        if ((req['userId'] ?? '').toString() == userId) {
          existingRequest = req;
          break;
        }
      }

      if (existingRequest != null && mounted) {
        setState(() => _requestSent = true);
      }
    } catch (e) {
      // Silently ignore errors loading requests
    }
  }

  static const Color _pageBackground = Color(0xFFF6F4EE);
  static const Color _cardGreen = Color(0xFF0A4A39);
  static const Color _gold = Color(0xFFF6CF55);
  static const Color _textPrimary = Color(0xFF151515);
  static const Color _border = Color(0xFFE5E0D4);
  static const Color _surface = Colors.white;

  bool get _canJoin => _checks.every((value) => value);

  String _formatCurrency(int amount) {
    final text = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(text[i]);
    }
    return buffer.toString();
  }

  int _monthlyAmount() {
    return widget.tontine.monthlyAmount.round();
  }

  int _membersCount() {
    return widget.tontine.memberCount;
  }

  int _maxMembers() {
    return widget.tontine.maxMembers ?? widget.tontine.memberCount;
  }

  int _durationMonths() {
    final maxMembers = _maxMembers();
    final cycle = widget.tontine.currentCycle > 0 ? widget.tontine.currentCycle : 1;
    return maxMembers > 0 ? maxMembers * cycle : 1;
  }

  String _statusLabel() {
    final status = widget.tontine.status.trim().toUpperCase();
    if (status == 'EN_COURS' || status == 'ACTIVE') return 'EN COURS';
    if (status == 'EN_ATTENTE' || status == 'PENDING') return 'EN FORMATION';
    if (status == 'TERMINE' || status == 'COMPLETED') return 'TERMINÉE';
    return status.replaceAll('_', ' ');
  }

  Future<void> _joinTontine() async {
    if (!_canJoin || _joining) return;

    final userId = context.read<AuthState>().currentUser?['uid']?.toString();
    final messenger = ScaffoldMessenger.of(context);
    if (userId == null || userId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Connectez-vous pour rejoindre cette tontine.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _joining = true);

    try {
        final db = FirestoreDatabaseService.instance;
        final fresh = await db.getTontineAsModel(widget.tontine.id);
        final referenceTontine = fresh ?? widget.tontine;
        final currentUser = context.read<AuthState>().currentUser;
        final userName_var = (currentUser?['name'] ?? 'Utilisateur').toString();
        final alreadyMember =
          referenceTontine.memberIds.contains(userId) || referenceTontine.creatorId == userId;

      if (alreadyMember) {
        if (!mounted) return;
        setState(() => _joining = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Vous êtes déjà membre de cette tontine.'),
            backgroundColor: AppColors.primary,
          ),
        );
        return;
      }
      // Create a join request so the tontine creator can accept it.
      final userName = userName_var;
      final userPhone = (currentUser?['phone'] ?? '').toString();
      await db.addJoinRequest(
        tontineId: widget.tontine.id,
        userId: userId,
        userName: userName,
        userPhone: userPhone,
      );

      // Notify the creator
      final creatorId = widget.tontine.creatorId;
      if (creatorId.isNotEmpty) {
        await db.addNotification(
          userId: creatorId,
          title: 'Nouvelle demande',
          message: 'Quelqu\'un a demandé à rejoindre "${widget.tontine.name}".',
          type: 'JOIN_REQUEST',
          tontineId: widget.tontine.id,
        );
      }

      if (!mounted) return;
      setState(() {
        _joining = false;
        _requestSent = true;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Demande envoyée. Le créateur doit l\'accepter.'),
          backgroundColor: AppColors.primary,
        ),
      );

      // Attendre 2 secondes avant de naviguer pour montrer le message
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Impossible de rejoindre la tontine: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersCount = _membersCount();
    final maxMembers = _maxMembers();
    final joinedAmount = _monthlyAmount();
    final totalAmount = joinedAmount * maxMembers;
    final durationMonths = _durationMonths();

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: _pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
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
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F5EF),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F1EA),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF55534E),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: _canJoin
                          ? [
                              BoxShadow(
                                color: const Color(0xFF003527).withValues(alpha: 0.28),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : const [],
                    ),
                    child: ElevatedButton(
                      onPressed: (_canJoin && !_joining && !_requestSent) ? _joinTontine : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                          (_canJoin && !_joining && !_requestSent) ? const Color(0xFF003527) : const Color(0xFFD8DED9),
                        disabledBackgroundColor: const Color(0xFFD8DED9),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _requestSent
                                ? Icons.check_rounded
                                : (_joining
                                    ? Icons.hourglass_top_rounded
                                    : (_canJoin
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.lock_outline_rounded)),
                            size: 18,
                            color: (_requestSent || (_canJoin && !_joining))
                                ? const Color(0xFFEAF7F1)
                                : const Color(0xFF909B94),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _requestSent
                                ? 'Demande\nenvoyée'
                                : (_joining
                                    ? 'Intégration\nen cours...'
                                    : (_canJoin
                                        ? 'Rejoindre la\nTontine'
                                        : 'Valider les\nengagements')),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 15,
                              fontWeight: (_requestSent || (_canJoin && !_joining)) ? FontWeight.w700 : FontWeight.w500,
                              color: (_requestSent || (_canJoin && !_joining))
                                  ? const Color(0xFFEAF7F1)
                                  : const Color(0xFF7A857E),
                              height: 1.05,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                color: _cardGreen,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _gold,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _statusLabel(),
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF8B6B00),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.tontine.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF8BA69C),
                      height: 0.95,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStatCard(
                          icon: Icons.groups_rounded,
                          title: 'Membres',
                          value: '$membersCount / $maxMembers',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MiniStatCard(
                          icon: Icons.payments_outlined,
                          title: 'Cotisation',
                          value: '${_formatCurrency(joinedAmount)}\nFCFA',
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _WhiteStatCard(
                    title: 'POT TOTAL',
                    value: '${_formatCurrency(totalAmount)}\nFCFA',
                    highlightBorder: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _WhiteStatCard(
                    title: 'DURÉE',
                    value: '$durationMonths mois',
                    subtitle: 'Cycles mensuels',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Règles de Fonctionnement',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.gavel_rounded, color: _textPrimary.withValues(alpha: 0.9), size: 21),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _border),
              ),
              child: Column(
                children: [
                  _RuleItem(icon: Icons.lock_outline_rounded, text: 'Pas de retrait possible après le début'),
                  const SizedBox(height: 14),
                  _RuleItem(icon: Icons.event_available_rounded, text: 'Paiement obligatoire à chaque cycle'),
                  const SizedBox(height: 14),
                  _RuleItem(icon: Icons.verified_outlined, text: 'Règles appliquées par la blockchain (immuables)'),
                  const SizedBox(height: 14),
                  _RuleItem(icon: Icons.report_problem_outlined, text: 'Gestion automatique des impayés'),
                  const SizedBox(height: 18),
                  const Divider(height: 1, color: Color(0xFFE7E1D7)),
                  const SizedBox(height: 12),
                  const Text(
                    'Toutes les règles sont appliquées automatiquement via des\ncontrats intelligents sur la blockchain.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5D5A52),
                      height: 1.45,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                color: _gold,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD2A316).withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DÉPÔT DE GARANTIE',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF836300),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(joinedAmount),
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 54,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111111),
                          height: 0.9,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 7),
                        child: Text(
                          'FCFA',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111111),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0C6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFB45D00), size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'En cas d\'impayé, votre dépôt sera\nautomatiquement utilisé pour maintenir la tontine.',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 12,
                              height: 1.35,
                              color: Color(0xFF6C4D00),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Engagement du Membre',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_checks.length, (index) {
              final entries = [
                'Je m\'engage à payer chaque cotisation à temps',
                'Je comprends que je ne peux pas quitter après le début',
                'J\'accepte l\'ordre automatique des bénéficiaires',
                'Je comprends que mon dépôt sera utilisé en cas d\'impayé',
                'J\'accepte que les règles soient immuables (blockchain)',
              ];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EngagementItem(
                  text: entries[index],
                  checked: _checks[index],
                  onChanged: (value) {
                    setState(() {
                      _checks[index] = value;
                    });
                  },
                ),
              );
            }),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool compact;

  const _MiniStatCard({
    required this.icon,
    required this.title,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 98,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF114D3D),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFF2A5C4C), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFF4D36A), size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFFC9DDD5),
            ),
          ),
          const SizedBox(height: 2),
          if (compact)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    value.split('\n').first,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 18,
                      height: 0.98,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(bottom: 1),
                  child: Text(
                    'FCFA',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 20,
                height: 1.03,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _WhiteStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final bool highlightBorder;

  const _WhiteStatCard({
    required this.title,
    required this.value,
    this.subtitle,
    this.highlightBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: highlightBorder ? const Color(0xFFB79240) : const Color(0xFFF0EBE0),
          width: highlightBorder ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF696660),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 24,
              height: 0.98,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111111),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12,
                color: Color(0xFF7B776E),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _RuleItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, color: const Color(0xFF8B6A10), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 14,
              height: 1.35,
              color: Color(0xFF25231E),
            ),
          ),
        ),
      ],
    );
  }
}

class _EngagementItem extends StatelessWidget {
  final String text;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _EngagementItem({
    required this.text,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => onChanged(!checked),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F2ED),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: checked ? const Color(0xFF6E8E80) : const Color(0xFF909090),
                  width: 1.1,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 16, color: Color(0xFF6E8E80))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 15,
                  height: 1.35,
                  color: Color(0xFF2A2A26),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
