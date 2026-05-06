import 'package:flutter/material.dart';
import 'package:tontinechain/constants/app_colors.dart';
import 'package:tontinechain/models/tontine.dart';

/// Dialog pour notifier les utilisateurs actifs d'une invitation à une tontine
class ActiveUsersNotificationDialog extends StatefulWidget {
  final Tontine tontine;
  final List<Map<String, dynamic>> activeUsers;

  const ActiveUsersNotificationDialog({
    super.key,
    required this.tontine,
    required this.activeUsers,
  });

  @override
  State<ActiveUsersNotificationDialog> createState() => _ActiveUsersNotificationDialogState();
}

class _ActiveUsersNotificationDialogState extends State<ActiveUsersNotificationDialog> {
  late Map<String, bool> _selectedUsers;
  bool _sendingNotifications = false;

  @override
  void initState() {
    super.initState();
    _selectedUsers = {
      for (final user in widget.activeUsers)
        (user['uid'] as String?) ?? '': true,
    };
  }

  String _getDisplayName(Map<String, dynamic> user) {
    final firstName = (user['firstName'] ?? '').toString().trim();
    final lastName = (user['lastName'] ?? '').toString().trim();
    final displayName = (user['displayName'] ?? user['nom'] ?? '').toString().trim();
    final composed = '$firstName $lastName'.trim();
    return composed.isNotEmpty
        ? composed
        : (displayName.isNotEmpty ? displayName : 'Utilisateur');
  }

  Future<void> _sendNotifications() async {
    final selectedUids = _selectedUsers.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .where((uid) => uid.isNotEmpty)
        .toList();

    if (selectedUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner au moins un utilisateur.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _sendingNotifications = true);

    try {
      // TODO: Implémenter l'envoi de notifications Firebase Cloud Messaging
      // Pour l'instant, on simule l'envoi
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;
      setState(() => _sendingNotifications = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Notification${selectedUids.length > 1 ? 's' : ''} envoyée${selectedUids.length > 1 ? 's' : ''} '
            'à ${selectedUids.length} utilisateur${selectedUids.length > 1 ? 's' : ''}',
          ),
          backgroundColor: AppColors.primary,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingNotifications = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'envoi: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            // En-tête
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notifier les utilisateurs actifs',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Invitez ${widget.activeUsers.length} utilisateur${widget.activeUsers.length > 1 ? 's' : ''} '
                          'pour rejoindre "${widget.tontine.name}"',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),

            // Liste des utilisateurs avec checkboxes
            Expanded(
              child: widget.activeUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off_outlined,
                            size: 48,
                            color: AppColors.textSecondary.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Aucun utilisateur actif',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 14,
                              color: AppColors.textSecondary.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: widget.activeUsers.length,
                      itemBuilder: (context, index) {
                        final user = widget.activeUsers[index];
                        final uid = (user['uid'] as String?) ?? '';
                        final name = _getDisplayName(user);
                        final isSelected = _selectedUsers[uid] ?? false;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.1),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: uid.isEmpty
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedUsers[uid] = value ?? false;
                                    });
                                  },
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              user['activeSearchStatus'] ?? 'Disponible',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 11,
                                color: AppColors.textSecondary.withValues(alpha: 0.75),
                              ),
                            ),
                            activeColor: AppColors.primary,
                            checkColor: Colors.white,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        );
                      },
                    ),
            ),

            // Boutons de confirmation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _sendingNotifications ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Annuler',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _sendingNotifications ? null : _sendNotifications,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _sendingNotifications
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Envoyer notification',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
