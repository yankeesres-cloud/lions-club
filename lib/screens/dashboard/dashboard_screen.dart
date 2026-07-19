import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/club_role.dart';
import '../../models/member.dart';
import '../../services/app_clock.dart';
import '../../services/club_chat_store.dart';
import '../../services/member_store.dart';
import '../../services/occasion_wall_poster.dart';
import '../../services/planner_store.dart';
import '../../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.role,
    required this.userName,
    required this.club,
    required this.onOpenModule,
    this.memberId = '',
    this.embedded = false,
  });

  final ClubRole role;
  final String userName;
  final ClubProfile club;
  final ValueChanged<AppModule> onOpenModule;
  final String memberId;
  /// Desk ke andar: upar club stats hide, sirf club wall.
  final bool embedded;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Member> _members = [];
  List<ClubChatMessage> _messages = [];
  bool _loading = true;
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  String? _pendingPhotoPath;
  String? _pendingFilePath;
  String? _pendingFileName;
  String? _pendingPhone;
  bool _sending = false;

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  bool get _hasPending =>
      (_pendingPhotoPath?.isNotEmpty == true) ||
      (_pendingFilePath?.isNotEmpty == true) ||
      (_pendingPhone?.isNotEmpty == true);

  @override
  void initState() {
    super.initState();
    AppClock.changes.addListener(_onClockChanged);
    _load();
  }

  @override
  void dispose() {
    AppClock.changes.removeListener(_onClockChanged);
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onClockChanged() {
    if (!mounted) return;
    _load();
  }

  Future<void> _load() async {
    final list = await MemberStore.ensureLoaded();
    await PlannerStore.ensureLoaded();
    await OccasionWallPoster.postTodaysWishes();
    final chat = await ClubChatStore.load();
    if (!mounted) return;
    setState(() {
      _members = list;
      _messages = chat;
      _loading = false;
    });
    _scrollToBottom(jump: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      if (jump) {
        _scrollCtrl.jumpTo(max);
      } else {
        _scrollCtrl.animateTo(
          max,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Chhota naam — pehla naam + last initial.
  String _shortName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'Member';
    if (parts.length == 1) {
      final n = parts.first;
      return n.length <= 14 ? n : '${n.substring(0, 12)}…';
    }
    final last = parts.last;
    final initial = last.isEmpty ? '' : '${last[0].toUpperCase()}.';
    return '${parts.first} $initial';
  }

  Future<String?> _persistBytes(Uint8List bytes, String folder, String ext) async {
    if (bytes.isEmpty) return null;
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, folder));
    if (!await dir.exists()) await dir.create(recursive: true);
    final safeExt = ext.isEmpty ? '.bin' : ext;
    final dest = File(
      p.join(dir.path, 'c_${DateTime.now().microsecondsSinceEpoch}$safeExt'),
    );
    await dest.writeAsBytes(bytes, flush: true);
    return dest.path;
  }

  Future<String?> _persistXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    final ext =
        p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
    return _persistBytes(bytes, 'club_chat_photos', ext);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _clearPending() {
    setState(() {
      _pendingPhotoPath = null;
      _pendingFilePath = null;
      _pendingFileName = null;
      _pendingPhone = null;
    });
  }

  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null || !mounted) return;
      final path = await _persistXFile(file);
      if (path == null || !mounted) {
        _toast('Camera photo save nahi hui');
        return;
      }
      setState(() {
        _pendingPhotoPath = path;
        _pendingFilePath = null;
        _pendingFileName = null;
      });
      _focusNode.requestFocus();
    } catch (_) {
      _toast('Camera open nahi hui — Gallery try karein');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      if (_isDesktop) {
        final picked = await FilePicker.pickFiles(
          type: FileType.image,
          withData: true,
          allowMultiple: false,
        );
        if (picked == null || picked.files.isEmpty || !mounted) return;
        final file = picked.files.first;
        var bytes = file.bytes;
        if ((bytes == null || bytes.isEmpty) && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }
        if (bytes == null || bytes.isEmpty) {
          _toast('Photo read nahi hui');
          return;
        }
        final ext = p.extension(file.name).isNotEmpty
            ? p.extension(file.name)
            : '.jpg';
        final path = await _persistBytes(bytes, 'club_chat_photos', ext);
        if (path == null || !mounted) return;
        setState(() {
          _pendingPhotoPath = path;
          _pendingFilePath = null;
          _pendingFileName = null;
        });
        _focusNode.requestFocus();
        return;
      }

      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null || !mounted) return;
      final path = await _persistXFile(file);
      if (path == null || !mounted) {
        _toast('Gallery photo save nahi hui');
        return;
      }
      setState(() {
        _pendingPhotoPath = path;
        _pendingFilePath = null;
        _pendingFileName = null;
      });
      _focusNode.requestFocus();
    } catch (_) {
      _toast('Gallery open nahi hui');
    }
  }

  Future<void> _pickFile() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
        allowMultiple: false,
      );
      if (picked == null || picked.files.isEmpty || !mounted) return;
      final file = picked.files.first;
      var bytes = file.bytes;
      if ((bytes == null || bytes.isEmpty) && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        _toast('File read nahi hui');
        return;
      }
      final name = file.name.trim().isEmpty ? 'file' : file.name.trim();
      final ext = p.extension(name);
      final path = await _persistBytes(bytes, 'club_chat_files', ext);
      if (path == null || !mounted) return;
      setState(() {
        _pendingFilePath = path;
        _pendingFileName = name;
        _pendingPhotoPath = null;
      });
      _focusNode.requestFocus();
    } catch (_) {
      _toast('File transfer open nahi hua');
    }
  }

  Future<void> _composePhone() async {
    final ctrl = TextEditingController(text: _pendingPhone ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Phone number bhejo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '+91 98XXXXXXXX',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final phone = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || phone.isEmpty || !mounted) return;
    setState(() => _pendingPhone = phone);
    _focusNode.requestFocus();
  }

  Future<void> _showAttachSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF25D366),
                  child: Icon(Icons.photo_camera, color: Colors.white),
                ),
                title: const Text('Camera'),
                subtitle: const Text('Nayi photo click karo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF128C7E),
                  child: Icon(Icons.photo_library, color: Colors.white),
                ),
                title: const Text('Gallery'),
                subtitle: const Text('Purani photo select karo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.purple,
                  child: Icon(Icons.insert_drive_file, color: Colors.white),
                ),
                title: const Text('File transfer'),
                subtitle: const Text('PDF / doc / any file'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFile();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF075E54),
                  child: Icon(Icons.phone, color: Colors.white),
                ),
                title: const Text('Phone number'),
                subtitle: const Text('Number share karo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _composePhone();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    final photo = _pendingPhotoPath ?? '';
    final filePath = _pendingFilePath ?? '';
    final fileName = _pendingFileName ?? '';
    final phone = _pendingPhone ?? '';
    if ((text.isEmpty &&
            photo.isEmpty &&
            filePath.isEmpty &&
            phone.isEmpty) ||
        _sending) {
      return;
    }
    setState(() => _sending = true);
    await ClubChatStore.send(
      senderName: widget.userName,
      senderMemberId: widget.memberId,
      text: text,
      photoPath: photo,
      filePath: filePath,
      fileName: fileName,
      phoneNumber: phone,
    );
    if (!mounted) return;
    _textCtrl.clear();
    setState(() {
      _messages = ClubChatStore.messages;
      _pendingPhotoPath = null;
      _pendingFilePath = null;
      _pendingFileName = null;
      _pendingPhone = null;
      _sending = false;
    });
    _scrollToBottom();
    _focusNode.requestFocus();
  }

  bool _isMine(ClubChatMessage m) {
    final mid = widget.memberId.trim();
    if (mid.isNotEmpty && m.senderMemberId.trim() == mid) return true;
    if (mid.isEmpty &&
        m.senderName.trim().toLowerCase() ==
            widget.userName.trim().toLowerCase()) {
      return true;
    }
    return false;
  }

  Future<void> _openPhone(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _toast(phone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.club;
    final today = DateFormat('EEEE, d MMM yyyy').format(DateTime.now());
    final now = DateTime.now();
    final birthdaysToday =
        _members.where((m) => m.hasBirthdayOn(now)).length;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club.clubName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                ),
                Text(
                  [
                    if (club.city.trim().isNotEmpty) club.city,
                    today,
                  ].where((e) => e.trim().isNotEmpty).join(' · '),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniStat('Members', '${_members.length}', Icons.groups),
                    _MiniStat(
                      'Birthdays',
                      '$birthdaysToday',
                      Icons.cake_outlined,
                    ),
                    _MiniStat(
                      'Messages',
                      '${_messages.length}',
                      Icons.chat_bubble_outline,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: Container(
            color: const Color(0xFFECE5DD),
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Abhi koi message nahi.\n+ se Camera, Gallery, File ya Phone bhejo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) =>
                        _bubble(_messages[i], _isMine(_messages[i])),
                  ),
          ),
        ),
        if (_hasPending)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                if (_pendingPhotoPath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_pendingPhotoPath!),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (_pendingFileName != null)
                  const Icon(Icons.insert_drive_file, size: 40, color: AppTheme.purple)
                else if (_pendingPhone != null)
                  const Icon(Icons.phone, size: 36, color: Color(0xFF075E54)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _pendingPhotoPath != null
                        ? 'Photo ready — Send dabao'
                        : (_pendingFileName != null
                            ? 'File: $_pendingFileName'
                            : 'Phone: $_pendingPhone'),
                  ),
                ),
                IconButton(
                  onPressed: _clearPending,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        Material(
          color: const Color(0xFFF0F0F0),
          elevation: 8,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Share menu',
                    onPressed: _sending ? null : _showAttachSheet,
                    icon: const Icon(Icons.add_circle, size: 28),
                    color: AppTheme.purple,
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      focusNode: _focusNode,
                      autofocus: true,
                      enabled: !_sending,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Message likho…',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color: const Color(0xFF25D366),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _sending ? null : _send,
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: Center(
                          child: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 22,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bubble(ClubChatMessage m, bool mine) {
    final time = DateFormat('h:mm a').format(m.createdAt);
    final bg = mine ? const Color(0xFFDCF8C6) : Colors.white;
    final align = mine ? Alignment.centerRight : Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(mine ? 14 : 4),
      bottomRight: Radius.circular(mine ? 4 : 14),
    );
    final nameColor = mine ? Colors.green.shade800 : AppTheme.purple;

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _shortName(m.senderName),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: nameColor,
                ),
              ),
              if (m.hasPhoto) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 180,
                      maxHeight: 160,
                    ),
                    child: Image.file(
                      File(m.photoPath),
                      fit: BoxFit.cover,
                      width: 180,
                      height: 160,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 180,
                        height: 100,
                        color: Colors.grey.shade300,
                        alignment: Alignment.center,
                        child: const Text('Photo nahi mili'),
                      ),
                    ),
                  ),
                ),
              ],
              if (m.hasFile) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file, color: AppTheme.purple),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m.fileName.isEmpty
                              ? p.basename(m.filePath)
                              : m.fileName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (m.hasPhone) ...[
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _openPhone(m.phoneNumber),
                  child: Row(
                    children: [
                      const Icon(Icons.phone, size: 18, color: Color(0xFF075E54)),
                      const SizedBox(width: 6),
                      Text(
                        m.phoneNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF075E54),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (m.hasText) ...[
                const SizedBox(height: 4),
                Text(m.text, style: const TextStyle(fontSize: 14.5, height: 1.3)),
              ],
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  time,
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.purple, size: 18),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
