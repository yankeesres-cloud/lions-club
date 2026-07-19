import 'dart:io';

import 'package:flutter/material.dart';

import '../models/member.dart';
import '../theme/app_theme.dart';

class MemberFaceAvatar extends StatelessWidget {
  const MemberFaceAvatar({
    super.key,
    required this.member,
    this.radius = 22,
  });

  final Member member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = member.primaryPhoto;
    final file = path.isEmpty ? null : File(path);
    final exists = file != null && file.existsSync();
    return CircleAvatar(
      key: ValueKey(path.isEmpty ? member.id : path),
      radius: radius,
      backgroundColor: AppTheme.purple.withValues(alpha: 0.12),
      backgroundImage: exists ? FileImage(file) : null,
      onBackgroundImageError: exists ? (_, _) {} : null,
      child: exists
          ? null
          : Icon(
              member.gender == MemberGender.female ? Icons.person_outline : Icons.person,
              color: AppTheme.purple,
              size: radius,
            ),
    );
  }
}

class MemberPhotoPickerTile extends StatelessWidget {
  const MemberPhotoPickerTile({
    super.key,
    required this.title,
    required this.photoPath,
    required this.onGallery,
    required this.onCamera,
    required this.onClear,
  });

  final String title;
  final String photoPath;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final path = photoPath.trim();
    final file = path.isEmpty ? null : File(path);
    final has = file != null && file.existsSync();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppTheme.purple.withValues(alpha: 0.1),
              backgroundImage: has ? FileImage(file) : null,
              child: has
                  ? null
                  : const Icon(Icons.person, size: 36, color: AppTheme.purple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    has ? 'Photo saved' : 'Gallery ya Camera se photo lagayein',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onGallery,
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: const Text('Gallery'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onCamera,
                        icon: const Icon(Icons.photo_camera_outlined, size: 16),
                        label: const Text('Camera'),
                      ),
                      if (has)
                        TextButton(
                          onPressed: onClear,
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
