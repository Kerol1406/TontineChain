import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tontinechain/constants/app_colors.dart';
import 'package:tontinechain/models/index.dart';
import 'package:tontinechain/providers/tontine_provider.dart';
import 'package:tontinechain/screens/contrat_smart_screen.dart';
import 'package:tontinechain/widgets/invite_share_dialog.dart';

class ContractsListScreen extends StatefulWidget {
  const ContractsListScreen({super.key});

  @override
  State<ContractsListScreen> createState() => _ContractsListScreenState();
}

class _ContractsListScreenState extends State<ContractsListScreen> {
  String _search = '';
  String _filter = 'Tous'; // Tous | Actifs | Archives
  String _sort = 'Récents'; // Récents | Anciens

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TontineProvider>();
    final isLoading = provider.isLoading;
    final all = provider.tontines;

    List<Tontine> list = all.where((t) {
      final matchSearch = _search.isEmpty || t.name.toLowerCase().contains(_search.toLowerCase());
      final matchFilter = _filter == 'Tous' ||
          (_filter == 'Actifs' && t.status.toLowerCase() == 'active') ||
          (_filter == 'Archives' && t.status.toLowerCase() != 'active');
      return matchSearch && matchFilter;
    }).toList();

    if (_sort == 'Récents') {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Mes contrats',
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
            onPressed: () => provider.loadTontines(),
            icon: const Icon(Icons.refresh_outlined, color: AppColors.textPrimary),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search & actions
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Rechercher un contrat',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: (v) => setState(() => _search = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sort,
                      items: const [
                        DropdownMenuItem(value: 'Récents', child: Text('Récents')),
                        DropdownMenuItem(value: 'Anciens', child: Text('Anciens')),
                      ],
                      onChanged: (v) => setState(() => _sort = v ?? 'Récents'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Tous', 'Actifs', 'Archives'].map((label) {
                  final selected = _filter == label;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) => setState(() => _filter = label),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Content
            if (isLoading) ...[
              const Expanded(child: Center(child: CircularProgressIndicator())),
            ] else if (list.isEmpty) ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('Aucun contrat pour le moment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/creer'),
                        child: const Text('Créer une tontine', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final t = list[index];
                    return _ContractCard(tontine: t, onView: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ContratSmartScreen(tontine: t)),
                      );
                    }, onShare: () {
                      showDialog(context: context, builder: (_) => InviteShareDialog(tontine: t));
                    });
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContractCard extends StatelessWidget {
  final Tontine tontine;
  final VoidCallback onView;
  final VoidCallback onShare;

  const _ContractCard({required this.tontine, required this.onView, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final bool isActive = tontine.status.toLowerCase() == 'active';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0,6))],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tontine.name,
                        style: const TextStyle(fontFamily: 'Manrope', fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isActive ? 'Actif & Audité' : 'Archivé',
                        style: TextStyle(color: isActive ? const Color(0xFF2E7D32) : AppColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${tontine.memberCount} membres • Créé le ${tontine.createdAt.day}/${tontine.createdAt.month}/${tontine.createdAt.year}',
                  style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        '${tontine.monthlyAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r"\\B(?=(\\d{3})+(?!\\d))"), (m) => '.') } FCFA',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: onShare,
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: const Text('Partager'),
                        ),
                        ElevatedButton(
                          onPressed: onView,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Text('Voir', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
