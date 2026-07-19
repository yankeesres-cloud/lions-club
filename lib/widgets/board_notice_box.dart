import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/app_clock.dart';
import '../services/board_notice_store.dart';
import '../services/board_store.dart';
import '../services/member_store.dart';
import '../theme/app_theme.dart';

bool isBoardMemberForNotice({
  required String memberId,
  String boardPostTitle = '',
}) {
  final mid = memberId.trim();
  if (mid.isNotEmpty && BoardStore.postsForMember(mid).isNotEmpty) {
    return true;
  }
  return boardPostTitle.trim().isNotEmpty;
}

/// Message kis post ke naam se jaaye — session title ya Board assign.
List<String> boardPostChoicesForNotice({
  required String memberId,
  String boardPostTitle = '',
}) {
  final seats = BoardStore.postsForMember(memberId)
      .map((p) => p.title.trim())
      .where((t) => t.isNotEmpty)
      .toList();
  final session = boardPostTitle.trim();
  if (session.isNotEmpty && !seats.contains(session)) {
    return [session, ...seats];
  }
  if (seats.isNotEmpty) return seats;
  if (session.isNotEmpty) return [session];
  return const [];
}

String resolveBoardPostLabel(BoardNotice n) {
  final saved = n.boardPost.trim();
  if (saved.isNotEmpty) return saved;
  final seats = BoardStore.postsForMember(n.senderMemberId);
  if (seats.isNotEmpty) {
    return seats.map((p) => p.title.trim()).where((t) => t.isNotEmpty).join(' · ');
  }
  return 'Board';
}

class _FeedRow {
  const _FeedRow({
    required this.id,
    required this.label,
    required this.text,
    required this.when,
    required this.daysLeft,
    this.sortKey = 0,
  });

  final String id;
  final String label;
  final String text;
  final DateTime when;
  final int daysLeft;
  final int sortKey;
}

/// Agle 5 din (aaj se) birthday / anniversary auto suchna.
List<_FeedRow> _upcomingOccasionFeed({int withinDays = 5}) {
  final members = MemberStore.current;
  final today = AppClock.today;
  final rows = <_FeedRow>[];
  final seenAnn = <String>{};

  for (var offset = 0; offset <= withinDays; offset++) {
    final day = today.add(Duration(days: offset));
    final dayLabel = DateFormat('d MMM').format(day);
    final whenText = offset == 0
        ? 'aaj'
        : (offset == 1 ? 'kal' : '$offset din baad');

    for (final m in members) {
      final name = m.displayName.trim();
      if (name.isEmpty) continue;

      if (m.hasBirthdayOn(day)) {
        rows.add(
          _FeedRow(
            id: 'bday_${m.id}_${day.month}_${day.day}',
            label: 'BIRTHDAY',
            text: '$name — Birthday $dayLabel ($whenText)',
            when: day,
            daysLeft: offset,
            sortKey: offset,
          ),
        );
      }

      if (m.hasAnniversaryOn(day)) {
        final key = '${m.anniversary.trim()}|${day.month}|${day.day}';
        // Same anniversary date — couple names combine.
        if (seenAnn.contains(key)) continue;
        final mates = members
            .where(
              (o) =>
                  o.anniversary.trim().isNotEmpty &&
                  o.anniversary.trim() == m.anniversary.trim() &&
                  o.hasAnniversaryOn(day),
            )
            .map((o) => o.displayName.trim())
            .where((n) => n.isNotEmpty)
            .toList();
        seenAnn.add(key);
        final who = mates.isEmpty ? name : mates.join(' & ');
        rows.add(
          _FeedRow(
            id: 'ann_${key.hashCode}',
            label: 'ANNIVERSARY',
            text: '$who — Anniversary $dayLabel ($whenText)',
            when: day,
            daysLeft: offset,
            sortKey: offset,
          ),
        );
      }
    }
  }

  rows.sort((a, b) => a.sortKey.compareTo(b.sortKey));
  return rows;
}


/// AppBar double-tap se board message compose — date/time + kitne din.
/// Message usi board post ke naam se save hota hai.
Future<void> openBoardNoticeComposer({
  required BuildContext context,
  required String userName,
  required String memberId,
  String boardPostTitle = '',
}) async {
  await BoardStore.ensureLoaded();
  if (!context.mounted) return;

  if (!isBoardMemberForNotice(
    memberId: memberId,
    boardPostTitle: boardPostTitle,
  )) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sirf Board members message daal sakte hain'),
      ),
    );
    return;
  }

  final postChoices = boardPostChoicesForNotice(
    memberId: memberId,
    boardPostTitle: boardPostTitle,
  );
  if (postChoices.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pehle board post assign / desk select karo'),
      ),
    );
    return;
  }

  final ctrl = TextEditingController();
  var when = DateTime.now();
  var showDays = BoardNotice.defaultTtlDays;
  var selectedPost = boardPostTitle.trim().isNotEmpty &&
          postChoices.contains(boardPostTitle.trim())
      ? boardPostTitle.trim()
      : postChoices.first;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final dateLabel = DateFormat('d MMM yyyy').format(when);
        final timeLabel = DateFormat('h:mm a').format(when);
        return AlertDialog(
          title: const Text('Board message'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Post ke naam se',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 6),
                if (postChoices.length == 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EEF8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5DDF0)),
                    ),
                    child: Text(
                      selectedPost,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.purple,
                      ),
                    ),
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedPost,
                        isExpanded: true,
                        isDense: true,
                        items: [
                          for (final p in postChoices)
                            DropdownMenuItem(value: p, child: Text(p)),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() => selectedPost = v);
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Message likho…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Date'),
                  subtitle: Text(dateLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: when,
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 30)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked == null) return;
                    setLocal(() {
                      when = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        when.hour,
                        when.minute,
                      );
                    });
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: const Text('Time'),
                  subtitle: Text(timeLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(when),
                    );
                    if (picked == null) return;
                    setLocal(() {
                      when = DateTime(
                        when.year,
                        when.month,
                        when.day,
                        picked.hour,
                        picked.minute,
                      );
                    });
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'Kitne din dikhe',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final d in [1, 2, 3, 5, 7, 10, 15, 30])
                      ChoiceChip(
                        label: Text('$d din'),
                        selected: showDays == d,
                        onSelected: (_) => setLocal(() => showDays = d),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    IconButton(
                      onPressed: showDays <= 1
                          ? null
                          : () => setLocal(() => showDays--),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$showDays din',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      onPressed: showDays >= 365
                          ? null
                          : () => setLocal(() => showDays++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send'),
            ),
          ],
        );
      },
    ),
  );
  final text = ctrl.text.trim();
  ctrl.dispose();
  if (ok != true || text.isEmpty) return;

  await BoardNoticeStore.post(
    senderName: userName,
    senderMemberId: memberId,
    boardPost: selectedPost,
    text: text,
    createdAt: when,
    showDays: showDays,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$selectedPost — message bhej diya ($showDays din)'),
    ),
  );
}

void _showFullBoardNotice(
  BuildContext context, {
  required String label,
  required String text,
  required DateTime when,
  required int daysLeft,
}) {
  final whenStr = DateFormat('d MMM yyyy, h:mm a').format(when);

  showDialog<void>(
    context: context,
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.8;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxH,
            maxWidth: 420,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          label.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: AppTheme.purple,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$whenStr · ${daysLeft <= 0 ? 'aaj' : '$daysLeft din'}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Compact board strip — board msgs + auto birthday/anniversary (5 din pehle).
class BoardNoticeBox extends StatefulWidget {
  const BoardNoticeBox({
    super.key,
    required this.userName,
    required this.memberId,
    this.boardPostTitle = '',
  });

  final String userName;
  final String memberId;
  final String boardPostTitle;

  @override
  State<BoardNoticeBox> createState() => _BoardNoticeBoxState();
}

class _BoardNoticeBoxState extends State<BoardNoticeBox> {
  List<_FeedRow> _feed = [];
  bool _loading = true;
  String? _expandedId;
  final _scrollCtrl = ScrollController();

  static const double _boxHeight = 96;

  @override
  void initState() {
    super.initState();
    BoardNoticeStore.changes.addListener(_onStoreChanged);
    AppClock.changes.addListener(_onClockChanged);
    _reload();
  }

  @override
  void dispose() {
    BoardNoticeStore.changes.removeListener(_onStoreChanged);
    AppClock.changes.removeListener(_onClockChanged);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    setState(() => _feed = _buildFeed(BoardNoticeStore.active));
  }

  void _onClockChanged() {
    if (!mounted) return;
    setState(() => _feed = _buildFeed(BoardNoticeStore.active));
  }

  List<_FeedRow> _buildFeed(List<BoardNotice> notices) {
    final auto = _upcomingOccasionFeed(withinDays: 5);
    final board = notices
        .map(
          (n) => _FeedRow(
            id: n.id,
            label: resolveBoardPostLabel(n),
            text: n.text,
            when: n.createdAt,
            daysLeft: n.daysLeft,
            sortKey: 1000 + (n.daysLeft),
          ),
        )
        .toList();
    // Occasions pehle (jaldi aane wale), phir board messages.
    return [...auto, ...board];
  }

  Future<void> _reload() async {
    await Future.wait([
      BoardStore.ensureLoaded(),
      MemberStore.ensureLoaded(),
    ]);
    final list = await BoardNoticeStore.load();
    if (!mounted) return;
    setState(() {
      _feed = _buildFeed(list);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: _boxHeight,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Material(
      color: const Color(0xFFF3EEF8),
      child: Container(
        height: _boxHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: _feed.isEmpty
            ? Center(
                child: Text(
                  'Board / Birthday / Anniversary yahan',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey.shade600,
                  ),
                ),
              )
            : Scrollbar(
                controller: _scrollCtrl,
                thumbVisibility: true,
                trackVisibility: true,
                thickness: 5,
                radius: const Radius.circular(4),
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
                  itemExtent: _boxHeight - 8,
                  itemCount: _feed.length,
                  itemBuilder: (ctx, i) => _feedTile(_feed[i]),
                ),
              ),
      ),
    );
  }

  Widget _feedTile(_FeedRow n) {
    final expanded = _expandedId == n.id;
    final when = DateFormat('d MMM, h:mm a').format(n.when);
    final left = n.daysLeft;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: GestureDetector(
        onTap: () => setState(() {
          _expandedId = expanded ? null : n.id;
        }),
        onDoubleTap: () => _showFullBoardNotice(
          context,
          label: n.label,
          text: n.text,
          when: n.when,
          daysLeft: n.daysLeft,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5DDF0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                n.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  color: AppTheme.purple,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  n.text,
                  maxLines: expanded ? 5 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    color: AppTheme.ink,
                  ),
                ),
              ),
              if (expanded)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '$when · ${left <= 0 ? 'aaj' : '$left din'}',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
