import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:verinni_os/core/config/supabase_config.dart';
import 'package:verinni_os/core/services/auth_service.dart';
import 'package:verinni_os/core/services/orcamento_service.dart';
import 'package:verinni_os/core/services/frota_service.dart';
import 'package:verinni_os/core/theme/app_theme.dart';
import 'package:verinni_os/core/utils/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Configure status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A0F1E),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    debug: false,
  );

  runApp(const VerinniApp());
}

class VerinniApp extends StatelessWidget {
  const VerinniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => OrcamentoService()),
        ChangeNotifierProvider(create: (_) => FrotaService()),
      ],
      child: Builder(
        builder: (context) {
          final router = createRouter(context);
          return MaterialApp.router(
            title: 'Verinni OS',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            routerConfig: router,
            builder: (context, child) {
              // Ensure text scale doesn't exceed 1.5 for factory use
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    MediaQuery.of(context).textScaler.scale(1.0).clamp(
                          0.8,
                          1.5,
                        ),
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
