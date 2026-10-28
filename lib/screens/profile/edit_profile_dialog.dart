import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bookswaphub/core/utils/app_failure.dart';
import 'package:bookswaphub/data/models/user.dart';
import 'package:bookswaphub/data/providers/providers.dart';

/// Edit name / bio / location. Role, rating and counters can NOT be changed here
/// (Firestore rules block them), so users cannot make themselves admins.
Future<void> showEditProfileDialog(BuildContext context, WidgetRef ref, User me) async {
  final name = TextEditingController(text: me.name);
  final bio = TextEditingController(text: me.bio);
  final loc = TextEditingController(text: me.location);
  String? error;
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Edit profile'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, maxLength: 60, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: loc, maxLength: 80, decoration: const InputDecoration(labelText: 'Location (city)')),
            TextField(controller: bio, maxLength: 300, maxLines: 3, decoration: const InputDecoration(labelText: 'Bio')),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (name.text.trim().length < 2) {
                setS(() => error = 'Please enter your name.');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (saved != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(userRepositoryProvider).updateProfile(me.id, name: name.text, bio: bio.text, location: loc.text);
    messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }
}

Future<void> pickAndUploadAvatar(BuildContext context, WidgetRef ref, String uid) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (file == null) return;
    await ref.read(userRepositoryProvider).uploadAvatar(uid, file);
    messenger.showSnackBar(const SnackBar(content: Text('Photo updated')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }
}
