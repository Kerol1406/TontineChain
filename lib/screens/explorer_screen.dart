import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/index.dart';
import '../providers/tontine_provider.dart';
import '../services/auth_state.dart';
import 'join_tontine_screen.dart';

class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({super.key});

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFrequency = 'Tous';
  String _selectedAmount = 'Tous';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recharger après le build pour éviter setState() during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TontineProvider>().loadTontines();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Tontine> _filterTontines(List<Tontine> tontines) {
    final provider = context.read<TontineProvider>();

    return tontines.where((tontine) {
      if (!provider.isDiscoverable(tontine.id)) return false;

      final maxMembers = tontine.maxMembers ?? 0;
      final isFull = maxMembers > 0 && tontine.memberCount >= maxMembers;
      if (isFull) return false;

      // Filtre recherche
      bool matchesSearch = _searchController.text.isEmpty ||
          tontine.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          tontine.description.toLowerCase().contains(_searchController.text.toLowerCase());

      // Filtre fréquence
      bool matchesFrequency = _selectedFrequency == 'Tous' || tontine.frequency == _selectedFrequency;

      // Filtre montant
      bool matchesAmount = true;
      if (_selectedAmount != 'Tous') {
        switch (_selectedAmount) {
          case 'Petit':
            matchesAmount = tontine.monthlyAmount <= 25000;
            break;
          case 'Moyen':
            matchesAmount = tontine.monthlyAmount > 25000 && tontine.monthlyAmount <= 100000;
            break;
          case 'Grand':
            matchesAmount = tontine.monthlyAmount > 100000;
            break;
        }
      }

      return matchesSearch && matchesFrequency && matchesAmount;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Explorer',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            fontFamily: 'Manrope',
          ),
        ),
        centerTitle: false,
      ),
      body: Consumer<TontineProvider>(
        builder: (context, tontineProvider, _) {
          final currentUserId = context.watch<AuthState>().currentUser?['uid']?.toString();
          final filteredTontines = _filterTontines(tontineProvider.tontines);

          // Debug helpers: show loading / error / count when empty
          if (tontineProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (tontineProvider.error != null && tontineProvider.tontines.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Erreur: ${tontineProvider.error}'),
              ),
            );
          }

          return Column(
            children: [
              // Barre de recherche
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom...',
                    hintStyle: const TextStyle(
                    color: AppColors.textHint,
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    fillColor: AppColors.surface,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  ),
                ),
              ),

              // Filtres
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(
                        label: 'Fréquence',
                        value: _selectedFrequency,
                        options: ['Tous', 'Mensuel', 'Hebdo', 'Journalier'],
                        onChanged: (value) => setState(() => _selectedFrequency = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterDropdown(
                        label: 'Montant',
                        value: _selectedAmount,
                        options: ['Tous', 'Petit', 'Moyen', 'Grand'],
                        onChanged: (value) => setState(() => _selectedAmount = value),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Liste des tontines
              Expanded(
                child: filteredTontines.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: AppColors.textHint.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Aucune tontine trouvée',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                                fontFamily: 'Plus Jakarta Sans',
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredTontines.length,
                        itemBuilder: (context, index) {
                          final tontine = filteredTontines[index];
                          return _buildTontineCard(context, tontine, currentUserId);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
            color: AppColors.surface,
          ),
          child: DropdownButton<String>(
            isExpanded: true,
            value: value,
            underline: const SizedBox(),
            items: options.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    option,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                ),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) onChanged(newValue);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTontineCard(BuildContext context, Tontine tontine, String? currentUserId) {
    final isFull = tontine.memberCount >= (tontine.maxMembers ?? 100);
    final isAlreadyMember = currentUserId != null && currentUserId.isNotEmpty
        ? tontine.memberIds.contains(currentUserId) || tontine.creatorId == currentUserId
        : false;
    final isGuest = currentUserId == null || currentUserId.isEmpty;
    final progressRatio = (tontine.memberCount / (tontine.maxMembers ?? 100)).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête: Nom + Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tontine.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Manrope',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                // Rating ou badge
                if (tontine.rating != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          '${tontine.rating}',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Plus Jakarta Sans',
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.border.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Nouveau',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              tontine.description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontFamily: 'Plus Jakarta Sans',
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 14),

            // Montant + Fréquence
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contribution',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                          fontFamily: 'Plus Jakarta Sans',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${tontine.monthlyAmount.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Manrope',
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fréquence',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                          fontFamily: 'Plus Jakarta Sans',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tontine.frequency ?? 'Mensuel',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Plus Jakarta Sans',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Barre de progression des membres
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Membres',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),
                    Text(
                      '${tontine.memberCount}/${tontine.maxMembers ?? 100}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressRatio,
                    minHeight: 6,
                      backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isFull ? AppColors.error : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Bouton Rejoindre
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isFull
                    ? null
                    : () {
                        if (isGuest) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Connectez-vous pour rejoindre une tontine.'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }

                        if (isAlreadyMember) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Vous êtes déjà membre de cette tontine.'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                          return;
                        }

                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => JoinTontineScreen(tontine: tontine),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFull
                      ? AppColors.border
                      : (isAlreadyMember ? AppColors.success.withValues(alpha: 0.16) : AppColors.primary),
                  disabledBackgroundColor: AppColors.border,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  isFull
                      ? 'Groupe complet'
                      : (isAlreadyMember ? 'Déjà membre' : 'Rejoindre'),
                  style: TextStyle(
                    color: isFull
                        ? AppColors.textHint
                        : (isAlreadyMember ? AppColors.success : AppColors.surface),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
