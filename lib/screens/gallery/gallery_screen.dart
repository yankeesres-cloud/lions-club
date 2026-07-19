import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../services/gallery_store.dart';
import '../../theme/app_theme.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, this.embedded = false});

  /// When true, no outer Material padding assumptions for desk embed.
  final bool embedded;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  bool _loading = true;
  List<GalleryPhoto> _photos = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await GalleryStore.load();
    if (!mounted) return;
    setState(() {
      _photos = list;
      _loading = false;
    });
  }

  Future<String?> _persistPicked(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'gallery_photos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final ext = p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
    final dest = File(
      p.join(dir.path, 'g_${DateTime.now().microsecondsSinceEpoch}$ext'),
    );
    await dest.writeAsBytes(bytes, flush: true);
    return dest.path;
  }

  Future<void> _addPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;

    final program = TextEditingController();
    final caption = TextEditingController();
    final date = TextEditingController(
      text:
          '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Program photo add'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: program,
              decoration: const InputDecoration(labelText: 'Program name'),
            ),
            TextField(
              controller: date,
              decoration: const InputDecoration(labelText: 'Date (dd/MM/yyyy)'),
            ),
            TextField(
              controller: caption,
              decoration: const InputDecoration(labelText: 'Caption (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;

    final path = await _persistPicked(file);
    if (path == null) return;
    await GalleryStore.add(
      GalleryPhoto(
        id: GalleryStore.newId(),
        path: path,
        programName: program.text.trim(),
        date: date.text.trim(),
        caption: caption.text.trim(),
      ),
    );
    await _reload();
  }

  Future<void> _delete(GalleryPhoto photo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete photo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
    if (ok != true) return;
    await GalleryStore.delete(photo.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) ...[
          Text(
            'Photo Gallery',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pehle programmes ke photos — sab members desk par dekh sakte hain',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _addPhoto,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Photo add'),
          ),
        ),
        const SizedBox(height: 12),
        if (_photos.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Abhi koi photo nahi. Program ke baad yahan photos add karein.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (_, i) {
              final ph = _photos[i];
              final file = File(ph.path);
              return InkWell(
                onLongPress: () => _delete(ph),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: file.existsSync()
                            ? Image.file(file, fit: BoxFit.cover)
                            : Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ph.programName.isEmpty ? 'Program' : ph.programName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    Text(
                      ph.date,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );

    if (widget.embedded) return body;
    return Material(
      color: Colors.transparent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [body],
      ),
    );
  }
}

/// Compact strip for desks.
class GalleryDeskStrip extends StatelessWidget {
  const GalleryDeskStrip({super.key, required this.photos, this.onOpenAll});

  final List<GalleryPhoto> photos;
  final VoidCallback? onOpenAll;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Text(
        'Abhi gallery khali hai — Photo Gallery se pehle programmes ke photos add karein.',
        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length.clamp(0, 12),
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final ph = photos[i];
              final file = File(ph.path);
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: file.existsSync()
                      ? Image.file(file, fit: BoxFit.cover)
                      : Container(color: Colors.grey.shade200),
                ),
              );
            },
          ),
        ),
        if (onOpenAll != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: onOpenAll, child: const Text('Poori gallery')),
        ],
      ],
    );
  }
}
