import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/auth_state.dart';
import 'dashboard_screen.dart';
import 'explorer_screen.dart';
import 'create_tontine_screen.dart';
import 'profile_screen.dart';
import '../services/tontine_service.dart';
import 'contracts_list_screen.dart';
import 'notifications_screen.dart';

/// Shell principal de l'app — contient la navbar et affiche les écrans
/// La navbar reste visible à tout moment
class AppShell extends StatefulWidget {
  final int initialIndex;

  const AppShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  late int _currentNavIndex;
  final MockTontineService _tontineService = MockTontineService();

  final List<_NavDestination> _navDestinations = const [
    _NavDestination(icon: Icons.grid_view_rounded, label: 'Accueil', route: '/dashboard'),
    _NavDestination(icon: Icons.explore_outlined, label: 'Explorer', route: '/explorer'),
    _NavDestination(icon: Icons.add_circle_outline, label: 'Créer', route: '/creer'),
    _NavDestination(icon: Icons.receipt_long_outlined, label: 'Tontines', route: '/contrats'),
    _NavDestination(icon: Icons.person_outline, label: 'Profil', route: '/profil'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentNavIndex = widget.initialIndex;
    _tontineService.resetDemoReceptionTour();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tontineService.resetDemoReceptionTour();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _onNavTap(int index) {
    if (_currentNavIndex == index) return; // Ignorer si déjà sélectionné
    setState(() => _currentNavIndex = index);
  }

  Widget _buildScreen() {
    switch (_currentNavIndex) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const ExplorerScreen();
      case 2:
        return const CreateTontineScreen();
      case 3:
        return const ContractsListScreen();
      case 4:
        return const ProfileScreen();
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().currentUser;
    final String userName = user?['displayName'] ?? user?['name'] ?? 'Utilisateur';
    final String userInitials = _getInitials(userName);

    // Barre de status
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // AppBar custom — visible sur Accueil, Explorer, Créer, et Profil
            if (_currentNavIndex == 0 || _currentNavIndex == 1 || _currentNavIndex == 2 || _currentNavIndex == 4)
              _buildAppBar(userInitials, userName)
            else
              const SizedBox.shrink(),

            // Contenu principal — remplit l'espace disponible
            Expanded(
              child: _buildScreen(),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAppBar(String initials, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Avatar initiales
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.6),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Nom app
          const Text(
            'TontineChain',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),

          const Spacer(),

          // Cloche notification (navigue vers NotificationsScreen)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM NAV BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_navDestinations.length, (index) {
              final dest = _navDestinations[index];
              final bool isSelected = _currentNavIndex == index;
              final bool isCenter = index == 2; // bouton Créer

              return Expanded(
                child: GestureDetector(
                  onTap: () => _onNavTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icône centrale spéciale
                      isCenter
                          ? Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                dest.icon,
                                color: Colors.white,
                                size: 22,
                              ),
                            )
                          : Icon(
                              dest.icon,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary.withValues(alpha: 0.5),
                              size: 24,
                            ),
                      const SizedBox(height: 4),

                      Text(
                        dest.label,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _NavDestination {
  final IconData icon;
  final String label;
  final String route;

  const _NavDestination({
    required this.icon,
    required this.label,
    required this.route,
  });
}
