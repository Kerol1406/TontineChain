import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tontinechain/constants/app_colors.dart';
import 'package:tontinechain/models/index.dart';
import 'package:tontinechain/providers/tontine_provider.dart';
import 'package:tontinechain/screens/contrat_smart_screen.dart';
import 'package:tontinechain/services/auth_state.dart';

String _formatAmount(int amount) {
  final text = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(text[i]);
  }
  return buffer.toString();
}

String _frequencyLabel(String? frequency) {
  final value = (frequency ?? '').trim().toLowerCase();
  if (value.contains('heb')) return 'Hebdomadaire';
  if (value.contains('jour')) return 'Journalier';
  if (value.contains('trime')) return 'Trimestrielle';
  if (value.contains('mens')) return 'Mensuelle';
  return value.isEmpty ? 'Mensuelle' : value[0].toUpperCase() + value.substring(1);
}

class ContractsListScreen extends StatefulWidget {
  const ContractsListScreen({super.key});

  @override
  State<ContractsListScreen> createState() => _ContractsListScreenState();
}

class _ContractsListScreenState extends State<ContractsListScreen> {
  String? _loadedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthState>().currentUser?['uid']?.toString();
    if (userId != null && userId.isNotEmpty && userId != _loadedUserId) {
      _loadedUserId = userId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<TontineProvider>().loadHomeSummary(userId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TontineProvider>();
    final all = provider.userTontines;

    final formation = all.where(_isInFormation).toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final active = all.where(_isActive).toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final completed = all.where(_isCompleted).toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Tontines',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: AppColors.textPrimary,
        ),
        actions: [
          IconButton(
            onPressed: () {
              final userId = context.read<AuthState>().currentUser?['uid']?.toString();
              if (userId != null && userId.isNotEmpty) {
                context.read<TontineProvider>().loadHomeSummary(userId);
              }
            },
            icon: const Icon(Icons.refresh_outlined, color: AppColors.textPrimary),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: provider.homeSummaryLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                final userId = context.read<AuthState>().currentUser?['uid']?.toString();
                if (userId != null && userId.isNotEmpty) {
                  await context.read<TontineProvider>().loadHomeSummary(userId);
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntroCard(all.length, formation.length, active.length, completed.length),
                    const SizedBox(height: 18),
                    _buildSectionHeader(
                      title: 'En formation',
                      subtitle: 'Les groupes qui n’ont pas encore atteint le nombre de membres requis.',
                      count: formation.length,
                    ),
                    const SizedBox(height: 12),
                    if (formation.isEmpty)
                      const _EmptySection(label: 'Aucune tontine en formation')
                    else
                      ...formation.map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TontineCard(
                              tontine: t,
                              mode: _TontineCardMode.formation,
                              onPrimaryAction: () => _openDetails(context, t),
                              primaryLabel: 'Voir les détails',
                            ),
                          )),
                    const SizedBox(height: 12),
                    _buildSectionHeader(
                      title: 'Actives',
                      subtitle: 'Les tontines complètes et en cours de rotation.',
                      count: active.length,
                    ),
                    const SizedBox(height: 12),
                    if (active.isEmpty)
                      const _EmptySection(label: 'Aucune tontine active')
                    else
                      ...active.map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TontineCard(
                              tontine: t,
                              mode: _TontineCardMode.active,
                              onPrimaryAction: () => _openDetails(context, t),
                              primaryLabel: 'Voir les détails',
                            ),
                          )),
                    const SizedBox(height: 12),
                    _buildSectionHeader(
                      title: 'Terminées',
                      subtitle: 'L’historique des tontines arrivées à leur terme.',
                      count: completed.length,
                    ),
                    const SizedBox(height: 12),
                    if (completed.isEmpty)
                      const _EmptySection(label: 'Aucune tontine terminée')
                    else
                      ...completed.map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TontineCard(
                              tontine: t,
                              mode: _TontineCardMode.completed,
                              onPrimaryAction: () => _openDetails(context, t),
                              primaryLabel: 'Voir l’historique',
                            ),
                          )),
                  ],
                ),
              ),
            ),
    );
  }

  static bool _isInFormation(Tontine tontine) {
    final status = tontine.status.trim().toUpperCase();
    return status == 'EN_ATTENTE' || status == 'PENDING';
  }

  static bool _isActive(Tontine tontine) {
    final status = tontine.status.trim().toUpperCase();
    return status == 'EN_COURS' || status == 'ACTIVE';
  }

  static bool _isCompleted(Tontine tontine) {
    return !_isInFormation(tontine) && !_isActive(tontine);
  }

  void _openDetails(BuildContext context, Tontine tontine) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ContratSmartScreen(tontine: tontine)),
    );
  }

  static Widget _buildIntroCard(
    int total,
    int formation,
    int active,
    int completed,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF033326), Color(0xFF0C4A37)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vos tontines',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Classement automatique selon le statut et votre appartenance au groupe.',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _SummaryPill(label: 'Total', value: total.toString())),
              const SizedBox(width: 8),
              Expanded(child: _SummaryPill(label: 'Formation', value: formation.toString())),
              const SizedBox(width: 8),
              Expanded(child: _SummaryPill(label: 'Actives', value: active.toString())),
              const SizedBox(width: 8),
              Expanded(child: _SummaryPill(label: 'Terminées', value: completed.toString())),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required int count,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _TontineCard extends StatelessWidget {
  final Tontine tontine;
  final _TontineCardMode mode;
  final VoidCallback onPrimaryAction;
  final String primaryLabel;

  const _TontineCard({
    required this.tontine,
    required this.mode,
    required this.onPrimaryAction,
    required this.primaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final maxMembers = tontine.maxMembers ?? tontine.memberCount;
    final membersCount = tontine.memberCount;
    final percent = maxMembers <= 0 ? 0.0 : (membersCount / maxMembers).clamp(0.0, 1.0);
    final isFormation = mode == _TontineCardMode.formation;
    final isActive = mode == _TontineCardMode.active;
    final isCompleted = mode == _TontineCardMode.completed;
    final amount = '${_formatAmount(tontine.monthlyAmount.round())} FCFA';
    final frequency = _frequencyLabel(tontine.frequency);
    final tourNumber = tontine.currentCycle > 0 ? tontine.currentCycle : 1;
    final totalTours = maxMembers > 0 ? maxMembers : membersCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFFE9E2D3)
              : AppColors.primary.withValues(alpha: 0.14),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tontine.name,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _StatusBadge(mode: mode),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isFormation
                ? 'En attente de membres supplémentaires pour lancer automatiquement la tontine.'
                : isActive
                    ? 'La tontine est complète et tourne normalement.'
                    : 'La tontine est terminée et reste consultable dans l’historique.',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoBlock(
                  label: 'Membres',
                  value: '$membersCount / $maxMembers',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _InfoBlock(
                  label: 'Cotisation',
                  value: amount,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoBlock(
            label: 'Fréquence',
            value: frequency,
          ),
          if (isFormation) ...[
            const SizedBox(height: 14),
            Text(
              '$membersCount membres inscrits sur $maxMembers requis',
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: percent,
                backgroundColor: const Color(0xFFF2ECDD),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ] else if (isActive) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F1E8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 20, color: AppColors.textPrimary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tour $tourNumber / $totalTours',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    frequency.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F1E8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, size: 20, color: AppColors.textPrimary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Historique de la tontine',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPrimaryAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: isCompleted ? const Color(0xFF274136) : AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                primaryLabel,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _TontineCardMode { formation, active, completed }

class _StatusBadge extends StatelessWidget {
  final _TontineCardMode mode;

  const _StatusBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    final isFormation = mode == _TontineCardMode.formation;
    final isActive = mode == _TontineCardMode.active;
    final background = isFormation
        ? const Color(0xFFF5E7B8)
        : isActive
            ? const Color(0xFFDDF8E6)
            : const Color(0xFFEDE8DF);
    final foreground = isFormation
        ? const Color(0xFF907000)
        : isActive
            ? const Color(0xFF1F7A3D)
            : AppColors.textSecondary;
    final label = isFormation
        ? 'En formation'
        : isActive
            ? 'En cours'
            : 'Terminé';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String label;
  final String value;

  const _InfoBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary.withValues(alpha: 0.8),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String label;

  const _EmptySection({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 13,
          color: AppColors.textSecondary.withValues(alpha: 0.75),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
