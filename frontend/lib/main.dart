import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/auth_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/login_screen.dart';
import 'screens/pantry_screen.dart';
import 'screens/settings_screen.dart';

const _defaultSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://zvcletmdhjeduxwhkynl.supabase.co',
);

const _defaultSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp2Y2xldG1kaGplZHV4d2hreW5sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE2NzAwMDMsImV4cCI6MjA4NzI0NjAwM30.DblDIIPtdIv78KRIdOe7wg2b0Q8KyRELaCYQe2gcG5o',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: _defaultSupabaseUrl,
    anonKey: _defaultSupabaseAnonKey,
  );
  runApp(const ProviderScope(child: PantryPilotApp()));
}

class PantryPilotApp extends StatelessWidget {
  const PantryPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PantryPilot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF206A5D)),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    if (session == null) {
      return const LoginScreen();
    }
    return const AppShell();
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _screens = [
    PantryScreen(),
    ChatScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.kitchen), label: 'Pantry'),
          NavigationDestination(icon: Icon(Icons.chat), label: 'Chef'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        onDestinationSelected: (value) => setState(() => _index = value),
      ),
    );
  }
}
