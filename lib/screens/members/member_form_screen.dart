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

  late MembershipType _type;
  late String _idM;
  late String _idF;

  // Shared couple / single household fields
  late final TextEditingController _anniversary;
  late final TextEditingController _address;
  late final TextEditingController _proposer;

  // Male (Lion)
  late final TextEditingController _nameM;
  late final TextEditingController _phoneM;
  late final TextEditingController _dobM;
  late final TextEditingController _professionM;
  String _photoM = '';

  // Female (Lioness) — couple form
  late final TextEditingController _nameF;
  late final TextEditingController _phoneF;
  late final TextEditingController _dobF;
  late final TextEditingController _professionF;
  String _photoF = '';

  // Single: which gender
  late MemberGender _singleGender;

  bool _saving = false;

  bool get _isEdit => widget.existing != null;
  bool get _isCouple => _type == MembershipType.couple;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _type = m?.membershipType ?? MembershipType.single;
    _singleGender = m?.gender ?? MemberGender.male;

    _anniversary = TextEditingController(text: m?.anniversary ?? '');
    _address = TextEditingController(text: m?.address ?? '');
    _proposer = TextEditingController(text: m?.proposer ?? '');

    _nameM = TextEditingController();
    _phoneM = TextEditingController();
    _dobM = TextEditingController();
    _professionM = TextEditingController();
    _nameF = TextEditingController();
    _phoneF = TextEditingController();
    _dobF = TextEditingController();
    _professionF = TextEditingController();

    if (m == null) {
      _idM = MemberStore.newId();
      _idF = MemberStore.newId();
      return;
    }

    // Edit: load self + spouse into M/F slots.
    final spouse =
        m.hasSpouse ? MemberStore.byId(m.spouseId) : null;
    final male = m.gender == MemberGender.male
        ? m
        : (spouse?.gender == MemberGender.male ? spouse : null);
    final female = m.gender == MemberGender.female
        ? m
        : (spouse?.gender == MemberGender.female ? spouse : null);

    if (male != null) {
      _idM = male.id;
      _nameM.text = male.name;
      _phoneM.text = male.phone;
      _dobM.text = male.dob;
      _professionM.text = male.profession;
      _photoM = male.photo;
      if (m.anniversary.isEmpty) {
        _anniversary.text = male.anniversary;
      }
    } else {
      _idM = MemberStore.newId();
    }

    if (female != null) {
      _idF = female.id;
      _nameF.text = female.name;
      _phoneF.text = female.phone;
      _dobF.text = female.dob;
      _professionF.text = female.profession;
      _photoF = female.photo;
    } else {
      _idF = MemberStore.newId();
    }

    // Single edit of one person — fill the matching side + gender.
    if (_type == MembershipType.single) {
      if (m.gender == MemberGender.male) {
        _idM = m.id;
        _nameM.text = m.name;
        _phoneM.text = m.phone;
        _dobM.text = m.dob;
        _professionM.text = m.profession;
        _photoM = m.photo;
      } else {
        _idF = m.id;
        _nameF.text = m.name;
        _phoneF.text = m.phone;
        _dobF.text = m.dob;
        _professionF.text = m.profession;
        _photoF = m.photo;
      }
    } else if (male == null && female == null) {
      // Couple flag but no clear gender split — put existing on male side.
      _idM = m.id;
      _nameM.text = m.name;
      _phoneM.text = m.phone;
      _dobM.text = m.dob;
      _professionM.text = m.profession;
      _photoM = m.photo;
    }
  }

  @override
  void dispose() {
    _anniversary.dispose();
    _address.dispose();
    _proposer.dispose();
    _nameM.dispose();
    _phoneM.dispose();
    _dobM.dispose();
    _professionM.dispose();
    _nameF.dispose();
    _phoneF.dispose();
    _dobF.dispose();
    _professionF.dispose();
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

  Future<void> _setPhoto({
    required bool camera,
    required bool maleSide,
  }) async {
    final id = maleSide ? _idM : _idF;
    final side = maleSide ? 'M' : 'F';
    try {
      final path = camera
          ? await MemberPhotoService.pickFromCamera(memberId: id, side: side)
          : await MemberPhotoService.pickFromGallery(memberId: id, side: side);
      if (!mounted) return;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo select cancel ho gayi')),
        );
        return;
      }
      setState(() {
        if (maleSide) {
          _photoM = path;
        } else {
          _photoF = path;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo lag gayi — Save dabayein')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo save fail: $e')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final ann = _anniversary.text.trim();
    final addr = _address.text.trim();
    final prop = _proposer.text.trim();

    if (_isCouple) {
      final nM = _nameM.text.trim();
      final nF = _nameF.text.trim();
      if (nM.isEmpty || nF.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couple ke liye dono naam zaroori — Lion aur Lioness'),
          ),
        );
        return;
      }
      setState(() => _saving = true);
      try {
        final male = Member(
          id: _idM,
          name: nM,
          phone: _phoneM.text.trim(),
          dob: _dobM.text.trim(),
          profession: _professionM.text.trim(),
          photo: _photoM,
          gender: MemberGender.male,
          anniversary: ann,
          address: addr,
          proposer: prop,
          membershipType: MembershipType.couple,
          spouseId: _idF,
        );
        final female = Member(
          id: _idF,
          name: nF,
          phone: _phoneF.text.trim().isEmpty
              ? _phoneM.text.trim()
              : _phoneF.text.trim(),
          dob: _dobF.text.trim(),
          profession: _professionF.text.trim(),
          photo: _photoF,
          gender: MemberGender.female,
          anniversary: ann,
          address: addr,
          proposer: prop,
          membershipType: MembershipType.couple,
          spouseId: _idM,
        );
        if (!male.isSane || !female.isSane) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Naam sahi bharein (dono sides)')),
          );
          setState(() => _saving = false);
          return;
        }
        await MemberStore.upsert(male);
        await MemberStore.upsert(female);
        await MemberStore.linkSpouses(_idM, _idF);
        if (!mounted) return;
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save fail: $e')),
        );
      }
      return;
    }

    // Single
    final isMale = _singleGender == MemberGender.male;
    final name = (isMale ? _nameM : _nameF).text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name zaroori hai')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final id = isMale ? _idM : _idF;
      final member = Member(
        id: id,
        name: name,
        phone: (isMale ? _phoneM : _phoneF).text.trim(),
        dob: (isMale ? _dobM : _dobF).text.trim(),
        profession: (isMale ? _professionM : _professionF).text.trim(),
        photo: isMale ? _photoM : _photoF,
        gender: _singleGender,
        anniversary: ann,
        address: addr,
        proposer: prop,
        membershipType: MembershipType.single,
        spouseId: '',
      );
      if (!member.isSane) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Naam sahi bharein')),
        );
        setState(() => _saving = false);
        return;
      }
      await MemberStore.upsert(member);
      await MemberStore.unlinkSpouse(id);
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
              _isCouple
                  ? 'Couple: ek form mein Lion + Lioness dono bhariye — save par dono members banenge.'
                  : 'Single member: ek vyakti ka form.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MembershipType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Couple / Single Member',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(
                  value: MembershipType.single,
                  child: Text('Single'),
                ),
                DropdownMenuItem(
                  value: MembershipType.couple,
                  child: Text('Couple'),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _type = v);
              },
            ),
            if (!_isCouple) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<MemberGender>(
                initialValue: _singleGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: const [
                  DropdownMenuItem(
                    value: MemberGender.male,
                    child: Text('Male (Lion)'),
                  ),
                  DropdownMenuItem(
                    value: MemberGender.female,
                    child: Text('Female (Lioness)'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _singleGender = v);
                },
              ),
            ],
            const SizedBox(height: 16),
            if (_isCouple) ...[
              _personBlock(
                title: 'Lion (Male)',
                name: _nameM,
                phone: _phoneM,
                dob: _dobM,
                profession: _professionM,
                photo: _photoM,
                maleSide: true,
              ),
              const SizedBox(height: 8),
              _personBlock(
                title: 'Lioness (Female)',
                name: _nameF,
                phone: _phoneF,
                dob: _dobF,
                profession: _professionF,
                photo: _photoF,
                maleSide: false,
              ),
            ] else if (_singleGender == MemberGender.male)
              _personBlock(
                title: 'Details',
                name: _nameM,
                phone: _phoneM,
                dob: _dobM,
                profession: _professionM,
                photo: _photoM,
                maleSide: true,
              )
            else
              _personBlock(
                title: 'Details',
                name: _nameF,
                phone: _phoneF,
                dob: _dobF,
                profession: _professionF,
                photo: _photoF,
                maleSide: false,
              ),
            const SizedBox(height: 8),
            _SectionTitle(_isCouple ? 'Shared (dono ke liye)' : 'Aur details'),
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEdit ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personBlock({
    required String title,
    required TextEditingController name,
    required TextEditingController phone,
    required TextEditingController dob,
    required TextEditingController profession,
    required String photo,
    required bool maleSide,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title),
        MemberPhotoPickerTile(
          title: 'Photo',
          photoPath: photo,
          onGallery: () => _setPhoto(camera: false, maleSide: maleSide),
          onCamera: () => _setPhoto(camera: true, maleSide: maleSide),
          onClear: () => setState(() {
            if (maleSide) {
              _photoM = '';
            } else {
              _photoF = '';
            }
          }),
        ),
        _field(name, 'Name', Icons.person),
        _field(phone, 'Phone No', Icons.phone, keyboard: TextInputType.phone),
        _dateField(dob, 'DOB'),
        _field(profession, 'Profession / Business', Icons.work_outline),
      ],
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
