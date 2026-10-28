import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';
import 'package:bookswaphub/core/constants/categories.dart';
import 'package:bookswaphub/core/utils/app_failure.dart';
import 'package:bookswaphub/data/models/book.dart';
import 'package:bookswaphub/data/providers/providers.dart';
import 'package:bookswaphub/data/repositories/book_repository.dart';

/// One form used by both "List a New Book" and "Edit Book".
/// Success messages are shown ONLY after Firebase confirms the save.
class BookForm extends ConsumerStatefulWidget {
  final Book? existing;
  const BookForm({super.key, this.existing});

  @override
  ConsumerState<BookForm> createState() => _BookFormState();
}

class _PickedImage {
  final XFile file;
  final Uint8List bytes;
  _PickedImage(this.file, this.bytes);
}

class _BookFormState extends ConsumerState<BookForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _author;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late final TextEditingController _price;
  String? _categoryId;
  String? _condition;
  String? _language;
  String _listingType = 'swap';
  bool _isAvailable = true;
  bool _saving = false;
  final List<String> _keepUrls = [];
  final List<_PickedImage> _newImages = [];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _title = TextEditingController(text: b?.title ?? '');
    _author = TextEditingController(text: b?.author ?? '');
    _description = TextEditingController(text: b?.description ?? '');
    _location = TextEditingController(text: b?.location ?? '');
    _price = TextEditingController(text: b?.price != null ? b!.price.toString() : '');
    if (b != null) {
      _categoryId = categoryById(b.categoryId) != null ? b.categoryId : null;
      _condition = b.condition;
      _language = ['English', 'Hindi', 'Gujarati', 'Other'].contains(b.language) ? b.language : 'Other';
      _listingType = b.listingType;
      _isAvailable = b.status == 'available';
      _keepUrls.addAll(b.imageUrls);
    } else {
      // Pre-fill the location from the user's profile.
      final profile = ref.read(myProfileProvider).when(data: (u) => u, loading: () => null, error: (_, __) => null);
      if (profile != null) _location.text = profile.location;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _description.dispose();
    _location.dispose();
    _price.dispose();
    super.dispose();
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickImages() async {
    final room = 5 - _keepUrls.length - _newImages.length;
    if (room <= 0) {
      _toast('You can add up to 5 images.');
      return;
    }
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: 1600);
      for (final f in picked.take(room)) {
        final bytes = await f.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          _toast('${f.name} is larger than 5 MB and was skipped.');
          continue;
        }
        _newImages.add(_PickedImage(f, bytes));
      }
      if (mounted) setState(() {});
    } catch (e) {
      _toast('Could not pick images: ${friendlyError(e)}');
    }
  }

  String? _validatePrice(String? v) {
    if (_listingType == 'swap') return null;
    final value = double.tryParse((v ?? '').trim());
    if (value == null) return 'Enter a price';
    if (value <= 0) return 'Price must be more than 0';
    if (value > 100000) return 'Price is too high';
    if (((value * 100).round() / 100 - value).abs() > 1e-9) return 'Use at most 2 decimals';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUidProvider);
    final profile = ref.read(myProfileProvider).when(data: (u) => u, loading: () => null, error: (_, __) => null);
    if (uid == null || profile == null) {
      _toast('Your profile is still loading. Please try again in a moment.');
      return;
    }
    final category = categoryById(_categoryId!)!;
    final draft = BookDraft(
      title: _title.text.trim(),
      author: _author.text.trim(),
      categoryId: category.id,
      categoryName: category.name,
      description: _description.text.trim(),
      condition: _condition!,
      language: _language ?? 'English',
      location: _location.text.trim(),
      listingType: _listingType,
      price: _listingType == 'swap' ? null : double.parse(_price.text.trim()),
    );
    final repo = ref.read(bookRepositoryProvider);
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await repo.updateBook(
          existing: widget.existing!,
          draft: draft,
          keepUrls: _keepUrls,
          newImages: _newImages.map((e) => e.file).toList(),
          isAvailable: _isAvailable,
        );
        if (mounted) _toast('Changes saved.');
      } else {
        await repo.createBook(
          uid: uid,
          ownerName: profile.name,
          ownerAvatar: profile.avatarUrl,
          draft: draft,
          images: _newImages.map((e) => e.file).toList(),
        );
        if (mounted) _toast('Book listed successfully!');
      }
      if (mounted) context.go('/my-books');
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Book'),
        content: const Text('Are you sure you want to delete this book? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(bookRepositoryProvider).deleteBook(widget.existing!);
      if (mounted) {
        _toast('Book deleted.');
        context.go('/my-books');
      }
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _imageTile({required Widget image, required VoidCallback onRemove}) {
    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 90, height: 120, child: image)),
        Positioned(
          top: 0,
          right: 0,
          child: InkWell(
            onTap: onRemove,
            child: const CircleAvatar(radius: 10, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 12, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final editableStatus = !_isEdit || widget.existing!.status == 'available' || widget.existing!.status == 'unavailable';
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isEdit) ...[
            SwitchListTile(
              title: const Text('Status'),
              subtitle: Text(editableStatus
                  ? (_isAvailable ? 'Available for Swap' : 'Unavailable')
                  : 'Locked: this book is ${widget.existing!.status}'),
              value: _isAvailable,
              onChanged: editableStatus ? (val) => setState(() => _isAvailable = val) : null,
            ),
            const SizedBox(height: AppDimensions.paddingMd),
          ],
          TextFormField(
            controller: _title,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder()),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: AppDimensions.paddingMd),
          TextFormField(
            controller: _author,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Author *', border: OutlineInputBorder()),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: AppDimensions.paddingMd),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
            value: _categoryId,
            items: bookCategories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (val) => setState(() => _categoryId = val),
            validator: (value) => value == null ? 'Required' : null,
          ),
          const SizedBox(height: AppDimensions.paddingMd),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            maxLines: 4,
            maxLength: 2000,
          ),
          const SizedBox(height: AppDimensions.paddingMd),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Condition *', border: OutlineInputBorder()),
            value: _condition,
            items: ['Like New', 'Good', 'Fair', 'Worn'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => setState(() => _condition = val),
            validator: (value) => value == null ? 'Required' : null,
          ),
          const SizedBox(height: AppDimensions.paddingMd),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Language', border: OutlineInputBorder()),
            value: _language,
            items: ['English', 'Hindi', 'Gujarati', 'Other'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => setState(() => _language = val),
          ),
          const SizedBox(height: AppDimensions.paddingMd),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Listing type *', border: OutlineInputBorder()),
            value: _listingType,
            items: const [
              DropdownMenuItem(value: 'swap', child: Text('Swap only')),
              DropdownMenuItem(value: 'sale', child: Text('Sell only')),
              DropdownMenuItem(value: 'both', child: Text('Swap or sell')),
            ],
            onChanged: (val) => setState(() => _listingType = val ?? 'swap'),
          ),
          if (_listingType != 'swap') ...[
            const SizedBox(height: AppDimensions.paddingMd),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Price (INR) *',
                helperText: 'Payments are Stripe TEST mode only: no real money moves.',
                border: OutlineInputBorder(),
              ),
              validator: _validatePrice,
            ),
          ],
          const SizedBox(height: AppDimensions.paddingMd),
          TextFormField(
            controller: _location,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Location *', border: OutlineInputBorder()),
            validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: AppDimensions.paddingMd),
          if (_keepUrls.isNotEmpty || _newImages.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final url in _keepUrls)
                  _imageTile(image: Image.network(url, fit: BoxFit.cover), onRemove: () => setState(() => _keepUrls.remove(url))),
                for (final img in _newImages)
                  _imageTile(image: Image.memory(img.bytes, fit: BoxFit.cover), onRemove: () => setState(() => _newImages.remove(img))),
              ],
            ),
          const SizedBox(height: AppDimensions.paddingMd),
          InkWell(
            onTap: _saving ? null : _pickImages,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.paddingXl),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Column(
                children: [
                  const Icon(Icons.camera_alt, size: 48, color: AppColors.textHint),
                  const SizedBox(height: AppDimensions.paddingSm),
                  Text(_isEdit ? 'Update Book Images' : 'Add Book Images', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Text('Tap to browse (up to 5, max 5 MB each)', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingXxl),
          if (_isEdit)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _saving ? null : _delete,
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent, side: const BorderSide(color: AppColors.accent)),
                      child: const Text('Delete Book'),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.paddingMd),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      child: Text(_saving ? 'Saving...' : 'Save Changes', style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Listing...' : 'List Book', style: const TextStyle(fontSize: 18)),
              ),
            ),
        ],
      ),
    );
  }
}
