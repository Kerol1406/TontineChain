import 'package:flutter/material.dart';
import 'package:tontinechain/constants/app_colors.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime date;
  final String tag; // ex: 'PAIEMENT', 'RAPPEL', 'SÉCURITÉ'
  NotificationItem({required this.id, required this.title, required this.body, required this.date, required this.tag});
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  List<NotificationItem> _mockData() {
    return [
      NotificationItem(
        id: 'n1',
        title: 'PAIEMENT REÇU',
        body: 'Cotisation reçue - 50 000 FCFA pour le Cercle des Entrepreneurs',
        date: DateTime.now().subtract(const Duration(hours: 1, minutes: 10)),
        tag: 'paiement',
      ),
      NotificationItem(
        id: 'n2',
        title: 'RAPPEL URGENT',
        body: "Il reste 2 jours pour votre cotisation mensuelle au Cercle des Entrepreneurs.",
        date: DateTime.now().subtract(const Duration(hours: 4)),
        tag: 'rappel',
      ),
      NotificationItem(
        id: 'n3',
        title: "ACTIVITÉ DE GROUPE",
        body: 'Fatou Sow a envoyé un nouveau message dans la discussion "Cercle des Entrepreneurs".',
        date: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
        tag: 'activity',
      ),
      NotificationItem(
        id: 'n4',
        title: 'SÉCURITÉ',
        body: 'Nouvelle connexion détectée sur votre compte depuis un appareil iPhone 15 Pro à Dakar.',
        date: DateTime.now().subtract(const Duration(days: 1, hours: 9)),
        tag: 'security',
      ),
    ];
  }

  Color _tagColor(String tag) {
    switch (tag) {
      case 'paiement':
        return const Color(0xFFE8F5E9);
      case 'rappel':
        return const Color(0xFFFFF8E1);
      case 'security':
        return const Color(0xFFFFEBEE);
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  IconData _tagIcon(String tag) {
    switch (tag) {
      case 'paiement':
        return Icons.attach_money_outlined;
      case 'rappel':
        return Icons.access_time_filled;
      case 'security':
        return Icons.shield_outlined;
      case 'activity':
        return Icons.chat_bubble_outline;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.year == dt.year && now.month == dt.month && now.day == dt.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final items = _mockData();

    // Split into groups: today and earlier
    final today = items.where((i) => i.date.day == DateTime.now().day).toList();
    final earlier = items.where((i) => i.date.day != DateTime.now().day).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF003D2D),
        elevation: 0,
        automaticallyImplyLeading: true,
        title: const Text('Notifications', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (today.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('AUJOURD\'HUI', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey)),
              ),
              ...today.map((n) => _buildCard(context, n)).toList(),
              const SizedBox(height: 20),
            ],
            if (earlier.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('HIER', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey)),
              ),
              ...earlier.map((n) => _buildCard(context, n)).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, NotificationItem n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0,4))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _tagColor(n.tag),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_tagIcon(n.tag), color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(n.title, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w900)),
                      ),
                      Text(_formatTime(n.date), style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(n.body, style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.9), fontSize: 14, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
