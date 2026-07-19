class GuestPost {
  const GuestPost({
    required this.id,
    required this.title,
    required this.sortOrder,
    this.name = '',
    this.phone = '',
    this.photo = '',
    this.notes = '',
    this.memberId = '',
    this.isCustom = false,
  });

  final String id;
  final String title;
  final int sortOrder;
  final String name;
  final String phone;
  final String photo;
  final String notes;
  /// Optional link to club [Member] — fills name/phone/photo without duplicating forever.
  final String memberId;
  final bool isCustom;

  bool get hasPerson => name.trim().isNotEmpty || memberId.trim().isNotEmpty;

  GuestPost copyWith({
    String? id,
    String? title,
    int? sortOrder,
    String? name,
    String? phone,
    String? photo,
    String? notes,
    String? memberId,
    bool? isCustom,
    bool clearPerson = false,
  }) {
    if (clearPerson) {
      return GuestPost(
        id: id ?? this.id,
        title: title ?? this.title,
        sortOrder: sortOrder ?? this.sortOrder,
        isCustom: isCustom ?? this.isCustom,
      );
    }
    return GuestPost(
      id: id ?? this.id,
      title: title ?? this.title,
      sortOrder: sortOrder ?? this.sortOrder,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      photo: photo ?? this.photo,
      notes: notes ?? this.notes,
      memberId: memberId ?? this.memberId,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'sortOrder': sortOrder,
        'name': name,
        'phone': phone,
        'photo': photo,
        'notes': notes,
        'memberId': memberId,
        'isCustom': isCustom,
      };

  factory GuestPost.fromJson(Map<String, dynamic> j) {
    return GuestPost(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      sortOrder: (j['sortOrder'] is int)
          ? j['sortOrder'] as int
          : int.tryParse('${j['sortOrder']}') ?? 0,
      name: (j['name'] ?? '').toString(),
      phone: (j['phone'] ?? '').toString(),
      photo: (j['photo'] ?? '').toString(),
      notes: (j['notes'] ?? '').toString(),
      memberId: (j['memberId'] ?? '').toString(),
      isCustom: j['isCustom'] == true,
    );
  }
}

class GuestDefaults {
  static List<GuestPost> posts() {
    const titles = [
      'Zone Chairperson (Region Chairperson)',
      'District Governor (DG)',
      'Multiple District Council Chairperson',
      'International Director (ID)',
      'International Vice Presidents',
      'International President (IP)',
    ];
    return [
      for (var i = 0; i < titles.length; i++)
        GuestPost(
          id: 'guest_$i',
          title: titles[i],
          sortOrder: i,
          isCustom: false,
        ),
    ];
  }
}
