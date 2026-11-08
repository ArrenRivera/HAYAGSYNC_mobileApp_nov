import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/user_model.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/terms_screen.dart';
import 'screens/parent/parent_dashboard.dart';
import 'screens/staff/staff_dashboard.dart';
import 'services/database_service.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zrttfhtmylwbrbvvgfpg.supabase.co',
    publishableKey: 'sb_publishable_VfbNvG2rBZwJZYG-kIcTJg_Bol5YYSd',
  );

  final db = DatabaseService();
  final initialUser = await db.restoreSession();
  final acceptedTerms =
      initialUser != null && await TermsStorage.isAccepted(initialUser.id);
  runApp(HayagSyncApp(initialUser: initialUser, acceptedTerms: acceptedTerms));
}

class HayagSyncApp extends StatelessWidget {
  final UserModel? initialUser;
  final bool acceptedTerms;

  const HayagSyncApp({
    super.key,
    required this.initialUser,
    required this.acceptedTerms,
  });

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return ListenableBuilder(
      listenable: db,
      builder: (context, child) {
        return MaterialApp(
          title: 'HAYAGSYNC',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2563EB), // Blue 600
              brightness: Brightness.light,
              primary: const Color(0xFF2563EB),
              secondary: const Color(0xFF0D9488), // Teal 600
              surface: Colors.white,
            ),
            fontFamily: 'Outfit',
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF0F172A), // Slate 900
              elevation: 0,
              shadowColor: Colors.transparent,
              iconTheme: IconThemeData(color: Color(0xFF64748B)), // Slate 500
              shape: Border(
                bottom: BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 1,
                ), // Slate 200
              ),
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 1,
                ), // Slate 200
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 1,
                ), // Slate 200
              ),
            ),
          ),
          home: initialUser == null
              ? const LoginScreen()
              : (acceptedTerms
                    ? (initialUser!.role == UserRole.parent
                          ? const ParentDashboard()
                          : const StaffDashboard())
                    : TermsScreen(user: initialUser!)),
        );
      },
    );
  }
}
