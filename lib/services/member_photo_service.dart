import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PhotoPickException implements Exception {
  PhotoPickException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Saves face photos into app documents (survives app restarts).
class MemberPhotoService {
  static final _picker = ImagePicker();

  static Future<Directory> _photosDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'member_photos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Write image bytes into durable storage. Returns saved absolute path.
  static Future<String> persistBytes({
    required Uint8List bytes,
    required String memberId,
    required String side, // 'M' or 'F'
    String ext = '.jpg',
  }) async {
    if (bytes.isEmpty) {
      throw PhotoPickException('Photo empty / read nahi hui');
    }
    final dir = await _photosDir();
    final safeExt = ['.jpg', '.jpeg', '.png', '.webp', '.heic'].contains(ext.toLowerCase())
        ? ext.toLowerCase()
        : '.jpg';
    final dest = File(
      p.join(dir.path, '${memberId}_${side}_${DateTime.now().millisecondsSinceEpoch}$safeExt'),
    );
    await dest.writeAsBytes(bytes, flush: true);
    if (!await dest.exists() || await dest.length() == 0) {
      throw PhotoPickException('Photo disk pe save nahi hui');
    }
    return dest.path;
  }

  static Future<String> persistPickedFile({
    required String sourcePath,
    required String memberId,
    required String side,
    Uint8List? bytes,
  }) async {
    Uint8List? data = bytes;
    if (data == null || data.isEmpty) {
      final src = File(sourcePath);
      if (!await src.exists()) {
        throw PhotoPickException('Selected file open nahi hui (sandbox)');
      }
      data = await src.readAsBytes();
    }
    final ext = p.extension(sourcePath);
    return persistBytes(
      bytes: data,
      memberId: memberId,
      side: side,
      ext: ext.isEmpty ? '.jpg' : ext,
    );
  }

  static Future<String?> pickFromGallery({
    required String memberId,
    required String side,
  }) async {
    // Desktop: file picker + withData (macOS sandbox needs bytes, not path-only).
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      final picked = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );
      if (picked == null || picked.files.isEmpty) return null;
      final file = picked.files.first;
      var bytes = file.bytes;
      if ((bytes == null || bytes.isEmpty) && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        throw PhotoPickException(
          'Photo read nahi hui. Dubara Gallery se try karein.',
        );
      }
      final name = file.name;
      final ext = p.extension(name).isNotEmpty
          ? p.extension(name)
          : (file.path != null ? p.extension(file.path!) : '.jpg');
      return persistBytes(
        bytes: bytes,
        memberId: memberId,
        side: side,
        ext: ext.isEmpty ? '.jpg' : ext,
      );
    }

    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    return persistBytes(
      bytes: bytes,
      memberId: memberId,
      side: side,
      ext: p.extension(x.path).isEmpty ? '.jpg' : p.extension(x.path),
    );
  }

  static Future<String?> pickFromCamera({
    required String memberId,
    required String side,
  }) async {
    try {
      final x = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
        preferredCameraDevice: CameraDevice.front,
      );
      if (x == null) return null;
      final bytes = await x.readAsBytes();
      return persistBytes(
        bytes: bytes,
        memberId: memberId,
        side: side,
        ext: p.extension(x.path).isEmpty ? '.jpg' : p.extension(x.path),
      );
    } on PhotoPickException {
      rethrow;
    } catch (e) {
      // Camera unavailable — fall back to gallery/file.
      return pickFromGallery(memberId: memberId, side: side);
    }
  }
}
