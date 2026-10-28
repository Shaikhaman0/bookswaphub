import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';
import 'package:bookswaphub/core/routing/app_navigation_helper.dart';
import 'package:bookswaphub/core/theme/theme_provider.dart';
import 'package:bookswaphub/core/utils/app_failure.dart';
import 'package:bookswaphub/core/utils/session.dart';
import 'package:bookswaphub/data/providers/providers.dart';
import 'package:bookswaphub/main.dart' show pushServiceProvider;
import 'package:bookswaphub/screens/profile/edit_profile_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => AppNavigationHelper.handleBack(context),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(AppDimensions.m),
            children: [
              _buildSectionHeader('Account'),
              _buildAccountSection(),
              const SizedBox(height: AppDimensions.l),
              
              _buildSectionHeader('Appearance'),
              _buildAppearanceSection(),
              const SizedBox(height: AppDimensions.l),
              
              _buildSectionHeader('Notifications'),
              _buildNotificationsSection(),
              const SizedBox(height: AppDimensions.l),
              
              _buildSectionHeader('Language'),
              _buildLanguageSection(),
              const SizedBox(height: AppDimensions.l),
              
              _buildSectionHeader('Privacy'),
              _buildPrivacySection(),
              const SizedBox(height: AppDimensions.l),
              
              _buildSectionHeader('Help & Support'),
              _buildHelpSection(),
              const SizedBox(height: AppDimensions.l),
              
              _buildSectionHeader('About'),
              _buildAboutSection(),
              const SizedBox(height: AppDimensions.xl),
              
              _buildLogoutButton(),
              const SizedBox(height: AppDimensions.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.m, left: AppDimensions.s),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildAccountSection() {
    final me = ref.watch(myProfileProvider).asData?.value;
    final email = ref.watch(currentEmailProvider);
    if (me == null) {
      return const Card(child: Padding(padding: EdgeInsets.all(AppDimensions.m), child: Center(child: CircularProgressIndicator())));
    }
    void edit() => showEditProfileDialog(context, ref, me);
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: me.avatarUrl.isNotEmpty ? NetworkImage(me.avatarUrl) : null,
              child: me.avatarUrl.isEmpty ? const Icon(Icons.person) : null,
            ),
            title: const Text('Profile Photo'),
            trailing: const Icon(Icons.edit, size: 20),
            onTap: () => pickAndUploadAvatar(context, ref, me.id),
          ),
          const Divider(height: 1),
          ListTile(title: const Text('Name'), subtitle: Text(me.name), trailing: const Icon(Icons.edit, size: 20), onTap: edit),
          const Divider(height: 1),
          // The email belongs to Firebase Auth and cannot be edited here.
          ListTile(title: const Text('Email'), subtitle: Text(email.isEmpty ? '-' : email)),
          const Divider(height: 1),
          ListTile(
            title: const Text('Location'),
            subtitle: Text(me.location.isEmpty ? 'Not set' : me.location),
            trailing: const Icon(Icons.edit, size: 20),
            onTap: edit,
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection() {
    final themeMode = ref.watch(themeNotifierProvider);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Theme', style: TextStyle(fontSize: 16)),
            const SizedBox(height: AppDimensions.s),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
              ],
              selected: {themeMode},
              onSelectionChanged: (Set<ThemeMode> newSelection) {
                ref.read(themeNotifierProvider.notifier).setTheme(newSelection.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Push notifications'),
            subtitle: const Text('Swap updates, messages and wishlist alerts on this device'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _enablePush,
          ),
          const Divider(height: 1),
          const ListTile(
            title: Text('Per-type notification switches'),
            subtitle: Text('Coming soon. For now all notification types are on.'),
            enabled: false,
          ),
        ],
      ),
    );
  }

  Future<void> _enablePush() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await FirebaseMessaging.instance.requestPermission();
      messenger.showSnackBar(SnackBar(
          content: Text(r.authorizationStatus == AuthorizationStatus.denied
              ? 'Notifications are blocked. Enable them in your device settings.'
              : 'Notifications enabled.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Widget _buildLanguageSection() {
    return Card(
      child: ListTile(
        title: const Text('Language'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_selectedLanguage, style: const TextStyle(color: Colors.grey)),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: null,
      ),
    );
  }

  Widget _buildPrivacySection() {
    return Card(
      child: Column(
        children: [
          const SwitchListTile(
            title: Text('Profile Visibility'),
            subtitle: Text('Coming soon. Profiles are currently visible to signed-in users.'),
            value: true,
            onChanged: null,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete my account', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Removes your profile, listings and wishlist'),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      try {
        await ref.read(pushServiceProvider).stop();
      } catch (_) {}
      await ref.read(authRepositoryProvider).deleteAccount();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Widget _buildHelpSection() {
    return Card(
      child: Column(
        children: [
          ListTile(title: const Text('FAQ'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          const Divider(height: 1),
          ListTile(title: const Text('Contact Us'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          const Divider(height: 1),
          ListTile(title: const Text('Terms of Service'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          const Divider(height: 1),
          ListTile(title: const Text('Privacy Policy'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      child: Column(
        children: [
          ListTile(title: const Text('Version'), trailing: const Text('1.0.0', style: TextStyle(color: Colors.grey)), onTap: () {}),
          const Divider(height: 1),
          ListTile(title: const Text('Open Source Licenses'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return ElevatedButton(
      onPressed: () => signOutUser(ref),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade50,
        foregroundColor: Colors.red,
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.l),
      ),
      child: const Text('Log Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}
