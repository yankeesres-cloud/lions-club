import 'package:flutter/material.dart';

import '../models/club_role.dart';
import '../theme/app_theme.dart';

/// Shared “foundation screen” — real forms will replace these one by one.
class ModuleScaffold extends StatelessWidget {
  const ModuleScaffold({
    super.key,
    required this.title,
    required this.bullets,
    this.actions = const [],
    this.child,
  });

  final String title;
  final List<String> bullets;
  final List<Widget> actions;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
              ),
            ),
            ...actions,
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'V1 Foundation — screen yahan se expand hogi',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Planned features',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final b in bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.purple),
                        const SizedBox(width: 8),
                        Expanded(child: Text(b)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (child != null) ...[
          const SizedBox(height: 12),
          child!,
        ],
      ],
    );
  }
}

class ModuleHubPage extends StatelessWidget {
  const ModuleHubPage({super.key, required this.module});

  final AppModule module;

  @override
  Widget build(BuildContext context) {
    switch (module) {
      case AppModule.dashboard:
        return const SizedBox.shrink(); // separate screen
      case AppModule.members:
        return const SizedBox.shrink(); // MembersScreen in MainShell
      case AppModule.birthday:
        return const ModuleScaffold(
          title: 'Birthday & Anniversary',
          bullets: [
            'Birthday list / Anniversary list',
            'Auto reminder',
            'WhatsApp greeting + call button',
            'Greeting card',
          ],
        );
      case AppModule.meetings:
        return const ModuleScaffold(
          title: 'Meeting Management',
          bullets: [
            'Schedule + agenda',
            'Attendance',
            'Minutes of Meeting (MOM)',
            'Photo upload',
            'Event registration (commercial)',
          ],
        );
      case AppModule.accounts:
        return const ModuleScaffold(
          title: 'Accounts',
          bullets: [
            'Membership fee + pending dues',
            'Donation entry + receipt',
            'Treasurer report',
            'Online fee tracking (commercial)',
          ],
        );
      case AppModule.activities:
        return const ModuleScaffold(
          title: 'Service Activities',
          bullets: [
            'Blood donation, tree plantation, medical / eye camp',
            'Food distribution',
            'Full activity records',
          ],
        );
      case AppModule.gallery:
        return const ModuleScaffold(
          title: 'Photo Gallery',
          bullets: ['Event-wise albums', 'Photos & videos'],
        );
      case AppModule.notices:
        return const ModuleScaffold(
          title: 'Notice Board',
          bullets: [
            'Club notice',
            'Emergency message',
            'Meeting reminder',
            'Push notifications (commercial)',
          ],
        );
      case AppModule.awards:
        return const ModuleScaffold(
          title: 'Awards & Honors',
          bullets: ['MJF / PMJF / Progressive PMJF', 'District & Club awards'],
        );
      case AppModule.documents:
        return const ModuleScaffold(
          title: 'Documents',
          bullets: [
            'Constitution, Bye Laws',
            'Meeting reports, budget, circulars',
            'PDF export',
          ],
        );
      case AppModule.reports:
        return const ModuleScaffold(
          title: 'Reports',
          bullets: [
            'Attendance / Birthday / Donation',
            'Activity / Membership reports',
            'PDF + analytics dashboard',
          ],
        );
      case AppModule.directory:
        return const SizedBox.shrink(); // ClubDirectoryScreen in MainShell
      case AppModule.ai:
      case AppModule.myDesk:
        return const SizedBox.shrink(); // PostDeskHubScreen in MainShell
      case AppModule.officers:
        return const SizedBox.shrink(); // BoardMembersScreen in MainShell
      case AppModule.guests:
        return const SizedBox.shrink(); // GuestListScreen in MainShell
      case AppModule.planner:
        return const SizedBox.shrink(); // PlannerScreen in MainShell
      case AppModule.settings:
        return const SizedBox.shrink();
    }
  }
}
