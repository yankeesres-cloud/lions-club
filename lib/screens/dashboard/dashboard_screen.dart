import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/board_post.dart';
import '../../models/club_role.dart';
import '../../models/member.dart';
import '../../models/planned_program.dart';
import '../../services/board_store.dart';
import '../../services/member_store.dart';
import '../../services/planner_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/member_photo.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.role,
    required this.userName,
    required this.club,
    required this.onOpenModule,
  });

  final ClubRole role;
  final String userName;
  final ClubProfile club;
  final ValueChanged<AppModule> onOpenModule;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Member> _members = [];
  List<BoardPost> _board = [];
  List<PlannedProgram> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await MemberStore.ensureLoaded();
    final board = await BoardStore.ensureLoaded();
    await PlannerStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _members = list;
      _board = board;
      _reminders = PlannerStore.reminderActive;
      _loading = false;
    });
  }

  Member? _memberOf(String id) {
    if (id.isEmpty) return null;
    try {
      return _members.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final userName = widget.userName;
    final club = widget.club;
    final today = DateFormat('EEEE, d MMM yyyy').format(DateTime.now());
    final now = DateTime.now();
    final birthdaysToday = _members.where((m) => m.hasBirthdayOn(now)).toList();
    final filledBoard = _board.where((p) => p.hasMember).length;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          club.clubName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          [
            if (club.district.trim().isNotEmpty) club.district,
            if (club.city.trim().isNotEmpty) club.city,
          ].join(' · '),
          style: TextStyle(color: Colors.grey.shade700),
        ),
        if (club.region.trim().isNotEmpty || club.state.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            [
              if (club.region.trim().isNotEmpty) club.region,
              if (club.state.trim().isNotEmpty) club.state,
            ].join(' · '),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
        const SizedBox(height: 2),
        Text(today, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 14),
        Card(
          color: AppTheme.purple,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium, color: AppTheme.goldSoft, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, $userName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Role: ${role.label}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MiniStat('Members', '${_members.length}', Icons.groups),
            _MiniStat('Board filled', '$filledBoard/${_board.length}', Icons.badge_outlined),
            _MiniStat('Birthdays today', '${birthdaysToday.length}', Icons.cake),
            const _MiniStat('Pending dues', '₹0', Icons.payments_outlined),
          ],
        ),
        if (_reminders.isNotEmpty && role.modules.contains(AppModule.planner)) ...[
          const SizedBox(height: 14),
          Card(
            color: AppTheme.goldSoft.withValues(alpha: 0.4),
            child: ListTile(
              leading: const Icon(Icons.notifications_active, color: AppTheme.purpleDeep),
              title: Text(
                'Planner reminder (${_reminders.length})',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                _reminders
                    .take(3)
                    .map((r) => '${r.title} · ${r.dateTimeLabel}')
                    .join('\n'),
              ),
              isThreeLine: _reminders.length > 1,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => widget.onOpenModule(AppModule.planner),
            ),
          ),
        ],
        const SizedBox(height: 18),
        const Text('Quick actions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in [
              AppModule.members,
              AppModule.officers,
              AppModule.guests,
              AppModule.planner,
              AppModule.myDesk,
              AppModule.meetings,
              AppModule.accounts,
              AppModule.birthday,
              AppModule.activities,
              AppModule.settings,
              AppModule.ai,
            ])
              if (role.modules.contains(m))
                ActionChip(
                  avatar: Icon(m.icon, size: 18),
                  label: Text(m.title),
                  onPressed: () => widget.onOpenModule(m),
                ),
          ],
        ),
        if (role.modules.contains(AppModule.officers)) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Board Members',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              TextButton(
                onPressed: () => widget.onOpenModule(AppModule.officers),
                child: const Text('Open all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Dashboard pe preview — full list Board Members mein',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ..._board.take(8).map((post) {
            final member = _memberOf(post.memberId);
            return Card(
              child: ListTile(
                dense: true,
                leading: member != null
                    ? MemberFaceAvatar(member: member, radius: 18)
                    : CircleAvatar(
                        backgroundColor: AppTheme.goldSoft.withValues(alpha: 0.4),
                        child: const Icon(Icons.badge_outlined, size: 18, color: AppTheme.purple),
                      ),
                title: Text(
                  post.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                subtitle: Text(
                  member?.displayName ?? 'Vacant — select member',
                  style: TextStyle(
                    color: member == null ? Colors.grey.shade600 : Colors.grey.shade800,
                  ),
                ),
                onTap: () => widget.onOpenModule(AppModule.officers),
              ),
            );
          }),
          if (_board.length > 8)
            TextButton(
              onPressed: () => widget.onOpenModule(AppModule.officers),
              child: Text('+ ${_board.length - 8} more posts'),
            ),
        ],
        const SizedBox(height: 18),
        const Text("Today's birthdays", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        if (birthdaysToday.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.cake_outlined),
              title: const Text('No birthdays today'),
              subtitle: Text(
                _members.isEmpty
                    ? 'Members module se members add / Excel load karein'
                    : 'Aaj koi birthday nahi',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ...birthdaysToday.map(
            (m) => Card(
              child: ListTile(
                leading: MemberFaceAvatar(member: m, radius: 20),
                title: Text(m.displayName),
                subtitle: Text(
                  m.primaryPhone.isEmpty
                      ? '${m.gender.label} · ${m.membershipType.label}'
                      : m.primaryPhone,
                ),
                trailing: const Icon(Icons.chat, color: Colors.green),
              ),
            ),
          ),
      ],
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
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.purple, size: 20),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ],
          ),
        ),
      ),
    );
  }
}
