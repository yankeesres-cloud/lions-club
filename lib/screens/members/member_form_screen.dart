import 'package:flutter/material.dart';

import '../../models/member.dart';
import '../../services/member_photo_service.dart';
import '../../services/member_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/member_photo.dart';

class MemberFormScreen extends StatefulWidget {
  const MemberFormScreen({super.key, this.existing});

  final Member? existing;

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _dob;
  late final TextEditingController _profession;
  late final TextEditingController _anniversary;
  late final TextEditingController _address;
  late final TextEditingController _proposer;
  late MembershipType _type;
  late MemberGender _gender;
  late String _memberId;
  String _photo = '';
  String _spouseId = '';
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _memberId = m?.id ?? MemberStore.newId();
    _name = TextEditingController(text: m?.name ?? '');
    _phone = TextEditingController(text: m?.phone ?? '');
    _dob = TextEditingController(text: m?.dob ?? '');
    _profession = TextEditingController(text: m?.profession ?? '');
    _anniversary = TextEditingController(text: m?.anniversary ?? '');
    _address = TextEditingController(text: m?.address ?? '');
    _proposer = TextEditingController(text: m?.proposer ?? '');
    _type = m?.membershipType ?? MembershipType.single;
    _gender = m?.gender ?? MemberGender.male;
    _photo = m?.photo ?? '';
    _spouseId = m?.spouseId ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _dob.dispose();
    _profession.dispose();
    _anniversary.dispose();
    _address.dispose();
    _proposer.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController c) async {
    final parsed = Member.parseFlexibleDate(c.text);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed ?? DateTime(now.year - 30),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() => c.text = Member.formatDate(picked));
  }

  Member _buildMember() {
    return Member(
      id: _memberId,
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      dob: _dob.text.trim(),
      profession: _profession.text.trim(),
      photo: _photo,
      gender: _gender,
      anniversary: _anniversary.text.trim(),
      address: _address.text.trim(),
      proposer: _proposer.text.trim(),
      membershipType: _type,
      spouseId: _type == MembershipType.couple ? _spouseId : '',
    );
  }

  Future<void> _setPhoto({required bool camera}) async {
    try {
      final path = camera
          ? await MemberPhotoService.pickFromCamera(
              memberId: _memberId,
              side: _gender.short,
            )
          : await MemberPhotoService.pickFromGallery(
              memberId: _memberId,
              side: _gender.short,
            );
      if (!mounted) return;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo select cancel ho gayi')),
        );
        return;
      }
      setState(() => _photo = path);
      if (_name.text.trim().isNotEmpty) {
        await MemberStore.upsert(_buildMember());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _name.text.trim().isNotEmpty
                ? 'Photo save ho gayi'
                : 'Photo lag gayi — neeche Save dabayein',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo save fail: $e')),
      );
    }
  }

  Future<void> _pickSpouse() async {
    final all = await MemberStore.ensureLoaded();
    final others = all.where((m) => m.id != _memberId).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    if (!mounted) return;
    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pehle pati/patni ko alag member ke roop mein add karein, phir yahan link karein'),
        ),
      );
      return;
    }
    final selected = await showModalBottomSheet<Member?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.7,
          child: ListView(
            children: [
              const ListTile(
                title: Text(
                  'Spouse / partner select (alag member)',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (_spouseId.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.link_off),
                  title: const Text('Unlink spouse'),
                  onTap: () => Navigator.pop(ctx, const Member(id: '')),
                ),
              for (final m in others)
                ListTile(
                  leading: MemberFaceAvatar(member: m, radius: 18),
                  title: Text(m.displayName),
                  subtitle: Text('${m.gender.label} · ${m.primaryPhone}'),
                  selected: m.id == _spouseId,
                  onTap: () => Navigator.pop(ctx, m),
                ),
            ],
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    if (selected.id.isEmpty) {
      setState(() {
        _spouseId = '';
        _type = MembershipType.single;
      });
      return;
    }
    setState(() {
      _spouseId = selected.id;
      _type = MembershipType.couple;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name zaroori hai')),
      );
      return;
    }
    if (_type == MembershipType.couple && _spouseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couple ke liye spouse member select karein (pati/patni alag member hona chahiye)'),
        ),
      );
      return;
    }
    if (_spouseId.isNotEmpty && _spouseId == _memberId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spouse khud ka member nahi ho sakta')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final member = _buildMember();
      await MemberStore.upsert(member);
      if (_type == MembershipType.couple && _spouseId.isNotEmpty) {
        await MemberStore.linkSpouses(_memberId, _spouseId);
      } else if (_type == MembershipType.single) {
        await MemberStore.unlinkSpouse(_memberId);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save fail: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spouse = _spouseId.isEmpty ? null : MemberStore.byId(_spouseId);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Member' : 'Add Member'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Ek form = ek vyakti (pati aur patni alag-alag members)',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MemberGender>(
              initialValue: _gender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(value: MemberGender.male, child: Text('Male (Lion)')),
                DropdownMenuItem(value: MemberGender.female, child: Text('Female (Lioness)')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _gender = v);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<MembershipType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Couple / Single Member',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(value: MembershipType.single, child: Text('Single')),
                DropdownMenuItem(value: MembershipType.couple, child: Text('Couple')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _type = v;
                  if (v == MembershipType.single) _spouseId = '';
                });
              },
            ),
            if (_type == MembershipType.couple) ...[
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: spouse != null
                      ? MemberFaceAvatar(member: spouse, radius: 20)
                      : const CircleAvatar(child: Icon(Icons.link)),
                  title: Text(
                    spouse?.displayName ?? 'Spouse member select karein',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Pati/patni alag member list se'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickSpouse,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _SectionTitle('Face photo'),
            MemberPhotoPickerTile(
              title: 'Photo (${_gender.label})',
              photoPath: _photo,
              onGallery: () => _setPhoto(camera: false),
              onCamera: () => _setPhoto(camera: true),
              onClear: () => setState(() => _photo = ''),
            ),
            _SectionTitle('Details'),
            _field(_name, 'Name', Icons.person),
            _field(_phone, 'Phone No', Icons.phone, keyboard: TextInputType.phone),
            _dateField(_dob, 'DOB'),
            _field(_profession, 'Profession', Icons.work_outline),
            _dateField(_anniversary, 'Anniversary'),
            _field(_address, 'Address', Icons.home_outlined, maxLines: 2),
            _field(_proposer, 'Proposer', Icons.handshake_outlined),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEdit ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _dateField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        readOnly: true,
        onTap: () => _pickDate(c),
        decoration: InputDecoration(
          labelText: label,
          hintText: 'dd/MM/yyyy',
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: IconButton(
            tooltip: 'Clear',
            onPressed: () => setState(() => c.clear()),
            icon: const Icon(Icons.clear, size: 18),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppTheme.purpleDeep,
          fontSize: 15,
        ),
      ),
    );
  }
}
