import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:verinni_os/core/services/auth_service.dart';
import 'package:verinni_os/core/theme/app_theme.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/orcamentos')) return 1;
    if (location.startsWith('/totem')) return 2;
    if (location.startsWith('/frota')) return 3;
    if (location.startsWith('/financeiro')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    final selectedIndex = _getSelectedIndex(context);
    final auth = context.read<AuthService>();

    final destinations = [
      const _NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'Dashboard',
        path: '/dashboard',
      ),
      const _NavItem(
        icon: Icons.description_outlined,
        activeIcon: Icons.description,
        label: 'Orçamentos',
        path: '/orcamentos',
      ),
      const _NavItem(
        icon: Icons.factory_outlined,
        activeIcon: Icons.factory,
        label: 'Totem',
        path: '/totem',
      ),
      const _NavItem(
        icon: Icons.directions_car_outlined,
        activeIcon: Icons.directions_car,
        label: 'Frota',
        path: '/frota',
      ),
      const _NavItem(
        icon: Icons.account_balance_outlined,
        activeIcon: Icons.account_balance,
        label: 'Financeiro',
        path: '/financeiro',
      ),
    ];

    if (isWide) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: AppColors.surface,
              selectedIndex: selectedIndex,
              extended: MediaQuery.of(context).size.width >= 1100,
              onDestinationSelected: (i) =>
                  context.go(destinations[i].path),
              minWidth: 72,
              minExtendedWidth: 220,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.engineering,
                          color: Colors.white, size: 24),
                    ),
                    if (MediaQuery.of(context).size.width >= 1100) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Verinni OS',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: AppColors.textMuted),
                      tooltip: 'Sair',
                      onPressed: () async {
                        await auth.signOut();
                        if (context.mounted) context.go('/login');
                      },
                    ),
                  ),
                ),
              ),
              destinations: destinations
                  .map((d) => NavigationRailDestination(
                        icon: Icon(d.icon, color: AppColors.textMuted),
                        selectedIcon: Icon(d.activeIcon, color: AppColors.primary),
                        label: Text(d.label),
                      ))
                  .toList(),
            ),
            const VerticalDivider(
              thickness: 1,
              width: 1,
              color: AppColors.border,
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: destinations.asMap().entries.map((entry) {
                final i = entry.key;
                final dest = entry.value;
                final isSelected = selectedIndex == i;
                return Expanded(
                  child: InkWell(
                    onTap: () => context.go(dest.path),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSelected ? dest.activeIcon : dest.icon,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textMuted,
                          size: 24,
                          semanticLabel: dest.label,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dest.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
}
