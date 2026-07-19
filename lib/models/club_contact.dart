/// Lions from other clubs / district contacts (Directory).
class ClubContact {
  const ClubContact({
    required this.id,
    this.name = '',
    this.phone = '',
    this.clubName = '',
    this.district = '',
    this.designation = '',
    this.city = '',
    this.notes = '',
  });

  final String id;
  final String name;
  final String phone;
  final String clubName;
  final String district;
  final String designation;
  final String city;
  final String notes;

  String get displayName {
    final n = name.trim();
    return n.isEmpty ? 'Unnamed' : n;
  }

  /// Digits-only phone for dial / compare.
  String get phoneDigits => phone.replaceAll(RegExp(r'\D'), '');

  bool get hasPhone => phoneDigits.length >= 8;

  /// Display like 94069 84445 / +91 …
  String get phoneDisplay {
    final d = phoneDigits;
    if (d.isEmpty) return '';
    if (d.length == 10) {
      return '${d.substring(0, 5)} ${d.substring(5)}';
    }
    if (d.length == 12 && d.startsWith('91')) {
      return '+91 ${d.substring(2, 7)} ${d.substring(7)}';
    }
    return phone.trim().isEmpty ? d : phone.trim();
  }

  String get telUri {
    final d = phoneDigits;
    if (d.isEmpty) return '';
    if (d.length == 10) return 'tel:+91$d';
    if (d.startsWith('91') && d.length >= 12) return 'tel:+$d';
    if (d.startsWith('0') && d.length == 11) return 'tel:+91${d.substring(1)}';
    return 'tel:$d';
  }

  /// "LIONS CLUB CITY STAR" jaise — person name nahi.
  static bool looksLikeClubOnly(String raw) {
    final t = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return false;
    if (t.startsWith('lions club')) return true;
    if (t.startsWith('lion club')) return true;
    if (RegExp(r'^lc\s').hasMatch(t)) return true;
    // Almost only "club …" without a person first name
    if (t.contains('lions club') && !t.contains(',')) return true;
    return false;
  }

  /// Reject junk; club-only rows without a person name fail.
  bool get isSane {
    final n = name.trim();
    if (n.length < 2 || n.length > 90) return false;
    if (n.contains('\uFFFD')) return false;
    if (RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]').hasMatch(n)) return false;
    if (looksLikeClubOnly(n)) return false;

    final letters = RegExp(r'[A-Za-z\u0900-\u097F]').allMatches(n).length;
    if (letters < 2) return false;

    final weird = RegExp(
      r"[^A-Za-z\u0900-\u097F0-9\s\-&./,()'+]",
    ).allMatches(n).length;
    if (weird > letters) return false;
    if (weird >= 3 && weird * 2 >= letters) return false;

    if (!RegExp(r'^[A-Za-z\u0900-\u097F]').hasMatch(n)) return false;

    final club = clubName.trim();
    if (club.isNotEmpty && !fieldOk(club)) return false;
    final post = designation.trim();
    if (post.isNotEmpty && !fieldOk(post)) return false;

    return true;
  }

  static bool fieldOk(String s) {
    if (s.trim().isEmpty) return true;
    if (s.length > 120) return false;
    if (s.contains('\uFFFD')) return false;
    final letters = RegExp(r'[A-Za-z\u0900-\u097F]').allMatches(s).length;
    final weird = RegExp(
      r"[^A-Za-z\u0900-\u097F0-9\s\-&./,()'+]",
    ).allMatches(s).length;
    if (letters < 1) return weird == 0 && RegExp(r'\d').hasMatch(s);
    return weird <= letters;
  }

  bool matchesQuery(String q) {
    final needle = q.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return [
      name,
      phone,
      phoneDigits,
      clubName,
      district,
      designation,
      city,
      notes,
    ].any((s) => s.toLowerCase().contains(needle));
  }

  ClubContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? clubName,
    String? district,
    String? designation,
    String? city,
    String? notes,
  }) {
    return ClubContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      clubName: clubName ?? this.clubName,
      district: district ?? this.district,
      designation: designation ?? this.designation,
      city: city ?? this.city,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'clubName': clubName,
        'district': district,
        'designation': designation,
        'city': city,
        'notes': notes,
      };

  factory ClubContact.fromJson(Map<String, dynamic> j) {
    return ClubContact(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      phone: (j['phone'] ?? j['mobile'] ?? '').toString(),
      clubName: (j['clubName'] ?? j['club'] ?? '').toString(),
      district: (j['district'] ?? '').toString(),
      designation: (j['designation'] ?? j['post'] ?? '').toString(),
      city: (j['city'] ?? '').toString(),
      notes: (j['notes'] ?? '').toString(),
    );
  }
}
