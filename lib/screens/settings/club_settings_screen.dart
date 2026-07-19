import 'package:flutter/material.dart';

import '../../models/club_role.dart';
import '../../models/member.dart';
import '../../services/club_settings_store.dart';
import '../../theme/app_theme.dart';

class ClubSettingsScreen extends StatefulWidget {
  const ClubSettingsScreen({
    super.key,
    required this.role,
    required this.onSaved,
    required this.onLogout,
  });

  final ClubRole role;
  final VoidCallback onSaved;
  final VoidCallback onLogout;

  @override
  State<ClubSettingsScreen> createState() => _ClubSettingsScreenState();
}

class _ClubSettingsScreenState extends State<ClubSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _clubName;
  late final TextEditingController _district;
  late final TextEditingController _region;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _charter;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  bool _loading = true;
  bool _saving = false;

  bool get _canEdit => widget.role.canEditClubSettings;

  @override
  void initState() {
    super.initState();
    _clubName = TextEditingController();
    _district = TextEditingController();
    _region = TextEditingController();
    _city = TextEditingController();
    _state = TextEditingController();
    _charter = TextEditingController();
    _email = TextEditingController();
    _phone = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final club = await ClubSettingsStore.load();
    if (!mounted) return;
    _clubName.text = club.clubName;
    _district.text = club.district;
    _region.text = club.region;
    _city.text = club.city;
    _state.text = club.state;
    _charter.text = club.charterDate;
    _email.text = club.clubEmail;
    _phone.text = club.clubPhone;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _clubName.dispose();
    _district.dispose();
    _region.dispose();
    _city.dispose();
    _state.dispose();
    _charter.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canEdit) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final existing = ClubSettingsStore.current;
    final club = ClubProfile(
      clubName: _clubName.text,
      district: _district.text,
      region: _region.text,
      city: _city.text,
      state: _state.text,
      charterDate: _charter.text,
      meetingPlace: existing.meetingPlace,
      meetingDay: existing.meetingDay,
      clubEmail: _email.text,
      clubPhone: _phone.text,
    );
    await ClubSettingsStore.save(club);
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Club settings saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Club Settings',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            _canEdit
                ? 'Club name, district aur baaki details yahan edit karein'
                : 'Sirf President / Secretary / Club Admin edit kar sakte hain',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _field(_clubName, 'Club Name', Icons.pets, required: true),
                  const SizedBox(height: 12),
                  _field(_district, 'District', Icons.map_outlined, required: true),
                  const SizedBox(height: 12),
                  _field(_region, 'Region / Zone', Icons.public_outlined),
                  const SizedBox(height: 12),
                  _field(_city, 'City', Icons.location_city_outlined, required: true),
                  const SizedBox(height: 12),
                  _field(_state, 'State', Icons.flag_outlined),
                  const SizedBox(height: 12),
                  _field(_charter, 'Charter Date', Icons.event_outlined),
                  const SizedBox(height: 12),
                  _field(
                    _phone,
                    'Club Phone',
                    Icons.phone_outlined,
                    keyboard: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _email,
                    'Club Email',
                    Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_canEdit)
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving…' : 'SAVE CLUB SETTINGS'),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    TextInputType? keyboard,
  }) {
    return TextFormField(
      controller: controller,
      enabled: _canEdit,
      keyboardType: keyboard,
      textCapitalization: TextCapitalization.words,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}
