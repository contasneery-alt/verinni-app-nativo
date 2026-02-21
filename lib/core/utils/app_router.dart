import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:verinni_os/core/services/auth_service.dart';
import 'package:verinni_os/features/auth/login_screen.dart';
import 'package:verinni_os/features/dashboard/dashboard_screen.dart';
import 'package:verinni_os/features/orcamentos/orcamentos_list_screen.dart';
import 'package:verinni_os/features/orcamentos/orcamento_detail_screen.dart';
import 'package:verinni_os/features/orcamentos/orcamento_form_screen.dart';
import 'package:verinni_os/features/totem/totem_screen.dart';
import 'package:verinni_os/features/frota/frota_screen.dart';
import 'package:verinni_os/features/financeiro/financeiro_screen.dart';
import 'package:verinni_os/shared/widgets/main_scaffold.dart';

GoRouter createRouter(BuildContext context) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final auth = Provider.of<AuthService>(context, listen: false);
      final isLoggedIn = auth.isAuthenticated;
      final isLoginPage = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && isLoginPage) return '/dashboard';
      return null;
    },
    refreshListenable: Provider.of<AuthService>(context, listen: false),
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/orcamentos',
            name: 'orcamentos',
            builder: (context, state) => const OrcamentosListScreen(),
            routes: [
              GoRoute(
                path: 'novo',
                name: 'orcamento-novo',
                builder: (context, state) => const OrcamentoFormScreen(),
              ),
              GoRoute(
                path: ':id',
                name: 'orcamento-detail',
                builder: (context, state) => OrcamentoDetailScreen(
                  id: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/totem',
            name: 'totem',
            builder: (context, state) => const TotemScreen(),
          ),
          GoRoute(
            path: '/frota',
            name: 'frota',
            builder: (context, state) => const FrotaScreen(),
          ),
          GoRoute(
            path: '/financeiro',
            name: 'financeiro',
            builder: (context, state) => const FinanceiroScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 64),
            const SizedBox(height: 16),
            const Text(
              'Página não encontrada',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.message ?? '404',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Voltar ao Início'),
            ),
          ],
        ),
      ),
    ),
  );
}
