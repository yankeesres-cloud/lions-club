class BoardPost {
  const BoardPost({
    required this.id,
    required this.title,
    required this.sortOrder,
    this.memberId = '',
    this.isCustom = false,
  });

  final String id;
  final String title;
  final int sortOrder;
  /// Links to [Member.id] — no duplicate name/phone storage.
  final String memberId;
  final bool isCustom;

  bool get hasMember => memberId.trim().isNotEmpty;

  BoardPost copyWith({
    String? id,
    String? title,
    int? sortOrder,
    String? memberId,
    bool? isCustom,
    bool clearMember = false,
  }) {
    return BoardPost(
      id: id ?? this.id,
      title: title ?? this.title,
      sortOrder: sortOrder ?? this.sortOrder,
      memberId: clearMember ? '' : (memberId ?? this.memberId),
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'sortOrder': sortOrder,
        'memberId': memberId,
        'isCustom': isCustom,
      };

  factory BoardPost.fromJson(Map<String, dynamic> j) {
    return BoardPost(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      sortOrder: (j['sortOrder'] is int)
          ? j['sortOrder'] as int
          : int.tryParse('${j['sortOrder']}') ?? 0,
      memberId: (j['memberId'] ?? '').toString(),
      isCustom: j['isCustom'] == true,
    );
  }
}

/// Default Lions Club board / officer posts (first launch seed).
class BoardDefaults {
  static List<BoardPost> posts() {
    const titles = [
      'FOUNDER PRESIDENT',
      'IPP',
      'PRESIDENT',
      'SECRETARY',
      'TREASURER',
      'V.P.-1',
      'V.P.-2',
      'V.P.-3',
      'Joint SECRETARY',
      'Joint TREASURER',
      'Club ADMINISTRATION',
      'LICF COORDINATOR',
      'CLUB MARKETING COMMUNICATION',
      'CLUB SERVICE CHAIRPERSON',
      'PRO',
      'MEDIA CONVENER',
      'TAMOR',
      'TAIL-TWISTER',
      'GREETING CHAIRPERSON',
      'CMC',
      'EDITOR',
      'CO EDITOR',
      'DIRECTOR',
      'DIRECTOR',
      'DIRECTOR',
      'DIRECTOR',
      'DIRECTOR',
      'DIRECTOR',
    ];
    return [
      for (var i = 0; i < titles.length; i++)
        BoardPost(
          id: 'post_$i',
          title: titles[i],
          sortOrder: i,
          isCustom: false,
        ),
    ];
  }
}
