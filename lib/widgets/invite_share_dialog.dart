import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tontinechain/constants/app_colors.dart';
import 'package:tontinechain/models/tontine.dart';
import 'package:tontinechain/services/auth_state.dart';
import 'package:tontinechain/services/firestore_database_service.dart';
import 'package:tontinechain/widgets/active_users_notification_dialog.dart';

/// Dialog de partage d'invitation pour une tontine
/// Affiche QR code, code d'accès unique, lien de partage
/// et options pour partager via WhatsApp, Email, etc.
class InviteShareDialog extends StatefulWidget {
  final Tontine tontine;

  const InviteShareDialog({super.key, required this.tontine});

  @override
  State<InviteShareDialog> createState() => _InviteShareDialogState();
}

class _InviteShareDialogState extends State<InviteShareDialog> {
  late String _accessCode;
  late String _shareLink;
  bool _copied = false;
  bool _loadingActiveUsers = false;
  List<Map<String, dynamic>> _activeUsers = const [];

  @override
  void initState() {
    super.initState();
    _generateCodes();
    _loadActiveUsers();
  }

  Future<void> _loadActiveUsers() async {
    final currentUserId = context.read<AuthState>().currentUser?['uid']?.toString();
    setState(() => _loadingActiveUsers = true);
    try {
      final users = await FirestoreDatabaseService.instance.getUsersLookingForTontine(
        excludeUid: currentUserId,
      );
      if (!mounted) return;
      setState(() {
        _activeUsers = users;
        _loadingActiveUsers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activeUsers = const [];
        _loadingActiveUsers = false;
      });
    }
  }

  void _generateCodes() {
    // Code d'accès : 6 caractères alphanumériques
    _accessCode = _generateAccessCode();
    // Lien de partage
    _shareLink = 'tontinechain.com/join/${widget.tontine.id}';
  }

  String _generateAccessCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = List<int>.generate(6, (i) => 
      (DateTime.now().millisecond + i * 123) % chars.length
    );
    return random.map((i) => chars[i]).join();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      if (!mounted) return;
      setState(() => _copied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lien copié au presse-papiers'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) setState(() => _copied = false);
      });
    });
  }

  void _shareViaWhatsApp() {
    final message = 'Rejoignez ma tontine "${widget.tontine.name}" sur TontineChain!\n'
        'Lien : $_shareLink\n'
        'Code : $_accessCode\n'
        'Sécurisé par la blockchain 🔐';
    // Implémentation réelle via url_launcher
    // ignore: avoid_print
    print('Share via WhatsApp: $message');
  }

  void _shareViaEmail() {
    final subject = 'Rejoignez la tontine ${widget.tontine.name}';
    final body = 'Bonjour,\n\n'
        'Je vous invite à rejoindre ma tontine "${widget.tontine.name}" sur TontineChain.\n\n'
        'Lien de partage : $_shareLink\n'
        'Code d\'accès : $_accessCode\n\n'
        'Montant : ${widget.tontine.monthlyAmount.toStringAsFixed(0)} FCFA\n'
        'Membres : ${widget.tontine.memberCount}\n\n'
        'Sécurisé par la blockchain.\n';
    // Implémentation réelle via url_launcher
      // ignore: avoid_print
      print('Share via Email - Subject: $subject, Body: $body');
  }

  void _shareSystem() {
    final text = 'Rejoignez ma tontine "${widget.tontine.name}" sur TontineChain!\n'
        'Lien : $_shareLink\n'
        'Code : $_accessCode';
    // Implémentation réelle via share plugin
    // ignore: avoid_print
    print('System share: $text');
  }

  Widget _buildActiveUsersSection() {
    if (_loadingActiveUsers) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3EF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_activeUsers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3EF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: const Text(
          'Aucun compte actif pour le moment.',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3EF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comptes actifs à notifier',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _activeUsers.map((user) {
              final firstName = (user['firstName'] ?? '').toString().trim();
              final lastName = (user['lastName'] ?? '').toString().trim();
              final displayName = (user['displayName'] ?? user['nom'] ?? '').toString().trim();
              final composed = '$firstName $lastName'.trim();
              final name = composed.isNotEmpty
                  ? composed
                  : (displayName.isNotEmpty ? displayName : 'Utilisateur');
              final status = (user['activeSearchStatus'] ?? 'Disponible').toString();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE7E1D6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _activeUsers.isEmpty
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        builder: (_) => ActiveUsersNotificationDialog(
                          tontine: widget.tontine,
                          activeUsers: _activeUsers,
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text(
                'Notifier ces membres',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec fermeture
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Invitez vos proches',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
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
              const SizedBox(height: 8),
              Text(
                'Partagez la sécurité de TontineChain',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 28),

              // Section QR Code
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: Column(
                  children: [
                    // QR Code placeholder
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(Icons.qr_code_2, size: 80, color: Colors.white.withValues(alpha: 0.3)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Code d\'accès',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Affichage du code par digits
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 8,
                      children: List.generate(
                        _accessCode.length,
                        (i) => Container(
                          width: 32,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3EF),
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              _accessCode[i],
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildActiveUsersSection(),
              const SizedBox(height: 16),

              // Lien de partage unique
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3EF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lien de partage unique',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _shareLink,
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _copyToClipboard(_shareLink),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _copied ? Icons.check : Icons.content_copy,
                          size: 18,
                          color: _copied ? Colors.green : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Boutons de partage
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _shareViaWhatsApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.share, size: 20),
                  label: const Text(
                    'Partager via WhatsApp',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Boutons secondaires
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _shareViaEmail,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.mail_outline, size: 18),
                        label: const Text(
                          'Email',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _shareSystem,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text(
                          'Plus',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Carte incitative
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Offre de bienvenue',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF8D44A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Vos filleuls reçoivent un bonus de 2 000 FCFA lors de leur première cotisation réussie.',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Voir les conditions de parrainage',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bouton fermer
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5F3EF),
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Fermer',
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
        ),
      ),
    );
  }
}
