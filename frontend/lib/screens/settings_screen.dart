import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _groqController = TextEditingController();

  @override
  void dispose() {
    _groqController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyAsync = ref.watch(groqApiKeyProvider);
    final email = ref.watch(currentUserEmailProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Account'),
            const SizedBox(height: 8),
            Text(email == null ? 'Not logged in' : 'Signed in as $email'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await ref.read(supabaseClientProvider).auth.signOut();
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Signed out')),
                );
              },
              child: const Text('Sign Out'),
            ),
            const SizedBox(height: 24),
            const Text('LLM Provider'),
            const SizedBox(height: 8),
            const DropdownMenu<String>(
              initialSelection: 'groq',
              enabled: false,
              dropdownMenuEntries: [
                DropdownMenuEntry(value: 'groq', label: 'Groq'),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Groq API Key (BYOK)'),
            const SizedBox(height: 8),
            TextField(
              controller: _groqController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste your Groq key',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await ref
                    .read(secureStorageProvider)
                    .saveGroqApiKey(_groqController.text.trim());
                ref.invalidate(groqApiKeyProvider);
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Groq key saved securely')),
                );
              },
              child: const Text('Save Groq Key'),
            ),
            const SizedBox(height: 12),
            keyAsync.when(
              data: (value) => Text(
                value == null || value.isEmpty
                    ? 'No Groq key saved'
                    : 'Groq key detected',
              ),
              loading: () => const CircularProgressIndicator(),
              error: (error, stackTrace) => const Text('Failed to load Groq key'),
            ),
          ],
        ),
      ),
    );
  }
}
