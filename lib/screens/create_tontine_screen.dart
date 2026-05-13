import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:tontinechain/constants/app_colors.dart';
import 'package:tontinechain/providers/tontine_provider.dart';
import 'package:tontinechain/services/auth_state.dart';
import 'package:tontinechain/screens/tontine_details_screen.dart';
import 'package:tontinechain/widgets/invite_share_dialog.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// MODÈLE — Option de fréquence fixe
/// ─────────────────────────────────────────────────────────────────────────
class _FrequencyOption {
  final String label;
  final String value;
  final IconData icon;
  const _FrequencyOption({
    required this.label,
    required this.value,
    required this.icon,
  });
}

/// ─────────────────────────────────────────────────────────────────────────
/// ÉCRAN CRÉER UNE TONTINE
/// ─────────────────────────────────────────────────────────────────────────
class CreateTontineScreen extends StatefulWidget {
  const CreateTontineScreen({Key? key}) : super(key: key);

  @override
  State<CreateTontineScreen> createState() => _CreateTontineScreenState();
}

class _CreateTontineScreenState extends State<CreateTontineScreen> {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _nameController         = TextEditingController();
  final _cotisationController   = TextEditingController(text: '50000');
  final _membresController      = TextEditingController(text: '12');
  final _customFreqController   = TextEditingController();

  // ── Fréquences fixes ───────────────────────────────────────────────────────
  static const List<_FrequencyOption> _fixedFrequencies = [
    _FrequencyOption(
      label: 'Journalier',
      value: 'Journalier',
      icon: Icons.today_outlined,
    ),
    _FrequencyOption(
      label: 'Hebdomadaire',
      value: 'Hebdomadaire',
      icon: Icons.bar_chart_rounded,
    ),
    _FrequencyOption(
      label: 'Mensuel',
      value: 'Mensuel',
      icon: Icons.calendar_month_outlined,
    ),
    _FrequencyOption(
      label: 'Trimestriel',
      value: 'Trimestriel',
      icon: Icons.calendar_view_month_outlined,
    ),
  ];

  // ── State ──────────────────────────────────────────────────────────────────
  /// null = aucune fixe sélectionnée (→ personnalisée active)
  String? _selectedFrequency = 'Hebdomadaire';
  bool _isCustomFrequency = false;   // champ personnalisé affiché
  bool _appelMembres      = false;
  bool _isSubmitting      = false;

  @override
  void dispose() {
    _nameController.dispose();
    _cotisationController.dispose();
    _membresController.dispose();
    _customFreqController.dispose();
    super.dispose();
  }

  // ── Getters simulation ─────────────────────────────────────────────────────
  double get _cotisation =>
      double.tryParse(_cotisationController.text.replaceAll(' ', '')) ?? 0;

  int get _membres =>
      int.tryParse(_membresController.text.trim()) ?? 0;

  double get _totalParCycle => _cotisation * _membres;

  String get _frequenceLabel {
    if (_isCustomFrequency) {
      final v = _customFreqController.text.trim();
      return v.isNotEmpty ? v : '—';
    }
    return _selectedFrequency ?? '—';
  }

  String get _dureeCycle {
    if (_membres <= 0) return '—';
    switch (_selectedFrequency) {
      case 'Journalier':   return '$_membres jours';
      case 'Hebdomadaire': return '$_membres semaines';
      case 'Trimestriel':  return '${_membres * 3} mois';
      case 'Mensuel':      return '$_membres mois';
      default:
        // Fréquence personnalisée : on affiche juste le nb de cycles
        return '$_membres cycles';
    }
  }

  String _formatMontant(double value) {
    if (value <= 0) return '0';
    final parts = value.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(parts[i]);
    }
    return buffer.toString();
  }

  // ── Soumission ─────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Veuillez saisir le nom de la tontine.');
      return;
    }
    if (_cotisation <= 0) {
      _showError('Veuillez saisir un montant de cotisation valide.');
      return;
    }
    if (_membres <= 0) {
      _showError('Veuillez saisir un nombre de membres valide.');
      return;
    }
    if (_isCustomFrequency && _customFreqController.text.trim().isEmpty) {
      _showError('Veuillez décrire votre fréquence personnalisée.');
      return;
    }

    final authUser = context.read<AuthState>().currentUser;
    final creatorId = FirebaseAuth.instance.currentUser?.uid ??
      (authUser?['uid'] ?? 'debug_user').toString();

    setState(() => _isSubmitting = true);

    final provider  = context.read<TontineProvider>();
    final tontine   = await provider.createTontine(
      name:          _nameController.text.trim(),
      description:   '',
      monthlyAmount: _cotisation,
      creatorId:     creatorId,
      maxMembers:    _membres,
      frequency:     _frequenceLabel,
      isDiscoverable: _appelMembres,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (tontine == null) {
      _showError(provider.error ?? 'Impossible de créer la tontine.');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contrat créé avec succès !'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => InviteShareDialog(tontine: tontine),
    ).then((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TontineDetailsScreen(tontine: tontine),
        ),
      );
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildTitle(),
                    const SizedBox(height: 28),
                    _buildForm(),
                    const SizedBox(height: 24),
                    _buildSimulationCard(),
                    const SizedBox(height: 24),
                    _buildSubmitButton(),
                    const SizedBox(height: 12),
                    _buildDisclaimer(),
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
  // TITRE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Initier un Nouvel\nHéritage',
          style: TextStyle(
            fontFamily: 'Manrope', fontSize: 32,
            fontWeight: FontWeight.w800, color: AppColors.textPrimary,
            letterSpacing: -0.8, height: 1.15,
          )),
        const SizedBox(height: 10),
        Text(
          'Configurez votre tontine intelligente en\nquelques étapes sécurisées.',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans', fontSize: 14,
            color: AppColors.textSecondary.withValues(alpha: 0.85),
            height: 1.55,
          )),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FORMULAIRE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nom
          _buildFieldLabel('Nom de la tontine'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _nameController,
            hint: 'Ex: Solidarité Familiale 2024',
          ),
          const SizedBox(height: 20),

          // Cotisation
          _buildFieldLabel('Cotisation individuelle'),
          const SizedBox(height: 8),
          _buildCotisationField(),
          const SizedBox(height: 20),

          // Nombre de membres
          _buildFieldLabel('Nombre de membres'),
          const SizedBox(height: 8),
          _buildMembresField(),
          const SizedBox(height: 20),

          // Fréquence
          _buildFieldLabel('Fréquence des cycles'),
          const SizedBox(height: 12),
          _buildFrequenceSection(),
          const SizedBox(height: 16),

          // Appel à membres
          _buildAppelMembresToggle(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Label de champ
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFieldLabel(String label) {
    return Text(label,
      style: const TextStyle(
        fontFamily: 'Plus Jakarta Sans', fontSize: 13,
        fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Champ texte générique
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        fontFamily: 'Plus Jakarta Sans', fontSize: 15,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'Plus Jakarta Sans', fontSize: 15,
          color: AppColors.textSecondary.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: const Color(0xFFF4F3EF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Champ cotisation avec suffix FCFA
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCotisationField() {
    return TextField(
      controller: _cotisationController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        fontFamily: 'Plus Jakarta Sans', fontSize: 15,
        fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: '50 000',
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.5)),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Align(
            widthFactor: 1,
            alignment: Alignment.centerRight,
            child: Text('FCFA',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              )),
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF4F3EF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Champ nombre de membres avec icône
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMembresField() {
    return TextField(
      controller: _membresController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        fontFamily: 'Plus Jakarta Sans', fontSize: 15,
        fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: '12',
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.5)),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Align(
            widthFactor: 1,
            alignment: Alignment.centerRight,
            child: Icon(Icons.people_alt_outlined,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
                size: 22),
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF4F3EF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION FRÉQUENCE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFrequenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Ligne 1 : Hebdomadaire | Mensuel (fidèle maquette) ────────────
        Row(
          children: [
            Expanded(child: _buildFreqChip(_fixedFrequencies[1])), // Hebdomadaire
            const SizedBox(width: 10),
            Expanded(child: _buildFreqChip(_fixedFrequencies[2])), // Mensuel
          ],
        ),
        const SizedBox(height: 10),

        // ── Ligne 2 : Journalier | Trimestriel ───────────────────────────
        Row(
          children: [
            Expanded(child: _buildFreqChip(_fixedFrequencies[0])), // Journalier
            const SizedBox(width: 10),
            Expanded(child: _buildFreqChip(_fixedFrequencies[3])), // Trimestriel
          ],
        ),
        const SizedBox(height: 10),

        // ── Bouton "+ Personnalisé" ───────────────────────────────────────
        GestureDetector(
          onTap: () {
            setState(() {
              _isCustomFrequency = !_isCustomFrequency;
              if (_isCustomFrequency) {
                // Désélectionner les fixes
                _selectedFrequency = null;
              } else {
                // Revenir à Hebdomadaire par défaut
                _selectedFrequency = 'Hebdomadaire';
                _customFreqController.clear();
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: _isCustomFrequency
                  ? AppColors.secondary.withValues(alpha: 0.08)
                  : const Color(0xFFF4F3EF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isCustomFrequency
                    ? AppColors.secondary
                    : AppColors.primary.withValues(alpha: 0.15),
                width: _isCustomFrequency ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: _isCustomFrequency
                      ? AppColors.tertiary
                      : AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    _isCustomFrequency
                        ? 'Fréquence personnalisée (actif)'
                        : '+ Personnalisé  (ex: Chaque jeudi)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                      fontWeight: _isCustomFrequency
                          ? FontWeight.w700 : FontWeight.w500,
                      color: _isCustomFrequency
                          ? AppColors.tertiary
                          : AppColors.textSecondary.withValues(alpha: 0.6),
                    )),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Icon(
                    _isCustomFrequency
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: _isCustomFrequency
                        ? AppColors.tertiary
                        : AppColors.textSecondary.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Champ texte personnalisé (animé) ─────────────────────────────
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeIn,
          crossFadeState: _isCustomFrequency
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _customFreqController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ex: Chaque jeudi, 1er du mois, Bi-mensuel…',
                    hintStyle: TextStyle(
                      fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    prefixIcon: const Icon(Icons.edit_calendar_outlined,
                        color: AppColors.tertiary, size: 20),
                    filled: true,
                    fillColor: AppColors.secondary.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.secondary, width: 1.5)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppColors.secondary.withValues(alpha: 0.4),
                          width: 1.5)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.secondary, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),

                const SizedBox(height: 8),

                // Suggestions rapides
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    'Chaque lundi',
                    'Chaque jeudi',
                    'Bi-mensuel',
                    '1er du mois',
                    'Chaque trimestre',
                  ].map((suggestion) => GestureDetector(
                    onTap: () {
                      setState(() {
                        _customFreqController.text = suggestion;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(suggestion,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.tertiary,
                        )),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Chip de fréquence fixe
  Widget _buildFreqChip(_FrequencyOption option) {
    final bool selected = !_isCustomFrequency &&
        _selectedFrequency == option.value;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedFrequency = option.value;
        _isCustomFrequency = false;
        _customFreqController.clear();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : const Color(0xFFF4F3EF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.textPrimary
                : AppColors.primary.withValues(alpha: 0.15),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(option.icon,
              size: 18,
              color: selected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Text(option.label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary.withValues(alpha: 0.6),
              )),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Toggle Appel à membres
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAppelMembresToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F3EF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Appel à membres',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontSize: 14,
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                  )),
                const SizedBox(height: 3),
                Text('Rendre cette tontine visible sur\nl\'explorateur',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    height: 1.4,
                  )),
              ],
            ),
          ),
          Switch(
            value: _appelMembres,
            onChanged: (val) => setState(() => _appelMembres = val),
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor:
                AppColors.textSecondary.withValues(alpha: 0.25),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SIMULATION DU CONTRAT
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSimulationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SIMULATION DU CONTRAT',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 10,
              fontWeight: FontWeight.w700, color: Colors.white54,
              letterSpacing: 1.6,
            )),
          const SizedBox(height: 10),
          const Text('Total à recevoir par cycle',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 13,
              color: Colors.white70,
            )),
          const SizedBox(height: 6),

          // Montant doré dynamique
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatMontant(_totalParCycle),
                style: const TextStyle(
                  fontFamily: 'Manrope', fontSize: 38,
                  fontWeight: FontWeight.w800, color: AppColors.secondary,
                  letterSpacing: -1, height: 1.0,
                )),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('FCFA',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans', fontSize: 16,
                    fontWeight: FontWeight.w600, color: AppColors.secondary,
                    letterSpacing: 1,
                  )),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 16),

          // Durée — affiche la fréquence choisie
          _SimulationRow(label: 'Durée totale du cycle', value: _dureeCycle),
          const SizedBox(height: 10),
          const _SimulationRow(
            label: 'Frais de réseau (Gas)',
            value: '~0.002 ETH',
            valueColor: AppColors.secondary,
          ),
          const SizedBox(height: 10),
          const _SimulationRow(
            label: 'Sécurité',
            value: 'Vérifié',
            trailingIcon: Icons.verified_rounded,
            valueColor: Colors.white,
          ),

          // Affichage de la fréquence choisie si personnalisée
          if (_isCustomFrequency &&
              _customFreqController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _SimulationRow(
              label: 'Fréquence',
              value: _customFreqController.text.trim(),
              valueColor: AppColors.secondary,
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOUTON CRÉER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.textPrimary,
          disabledBackgroundColor:
              AppColors.secondary.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.primary))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 20),
                  SizedBox(width: 10),
                  Text('Créer le contrat intelligent',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans', fontSize: 15,
                      fontWeight: FontWeight.w700,
                    )),
                ],
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Disclaimer
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDisclaimer() {
    return Center(
      child: Text(
        'EN CRÉANT CE CONTRAT, VOUS ACCEPTEZ LES RÈGLES D\'INTÉGRITÉ\nDE LA COMMUNAUTÉ TONTINECHAIN',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Plus Jakarta Sans', fontSize: 9,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary.withValues(alpha: 0.55),
          letterSpacing: 0.6, height: 1.6,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGET PRIVÉ — Ligne simulation
// ══════════════════════════════════════════════════════════════════════════════
class _SimulationRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final IconData? trailingIcon;

  const _SimulationRow({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 13,
              color: Colors.white60,
            )),
        ),
        if (trailingIcon != null) ...[
          Text(value,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 13,
              fontWeight: FontWeight.w700, color: valueColor,
            )),
          const SizedBox(width: 4),
          Icon(trailingIcon, color: valueColor, size: 16),
        ] else
          Text(value,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 13,
              fontWeight: FontWeight.w700, color: valueColor,
            )),
      ],
    );
  }
}