class ClubProfile {
  const ClubProfile({
    this.clubName = 'Lions Club Gwalior Maitri',
    this.district = 'District 322-B1',
    this.region = '',
    this.city = 'Gwalior',
    this.state = 'Madhya Pradesh',
    this.charterDate = '',
    this.meetingPlace = '',
    this.meetingDay = '',
    this.clubEmail = '',
    this.clubPhone = '',
  });

  final String clubName;
  final String district;
  final String region;
  final String city;
  final String state;
  final String charterDate;
  final String meetingPlace;
  final String meetingDay;
  final String clubEmail;
  final String clubPhone;

  ClubProfile copyWith({
    String? clubName,
    String? district,
    String? region,
    String? city,
    String? state,
    String? charterDate,
    String? meetingPlace,
    String? meetingDay,
    String? clubEmail,
    String? clubPhone,
  }) {
    return ClubProfile(
      clubName: clubName ?? this.clubName,
      district: district ?? this.district,
      region: region ?? this.region,
      city: city ?? this.city,
      state: state ?? this.state,
      charterDate: charterDate ?? this.charterDate,
      meetingPlace: meetingPlace ?? this.meetingPlace,
      meetingDay: meetingDay ?? this.meetingDay,
      clubEmail: clubEmail ?? this.clubEmail,
      clubPhone: clubPhone ?? this.clubPhone,
    );
  }
}

enum MembershipType { couple, single }

extension MembershipTypeX on MembershipType {
  String get label => this == MembershipType.couple ? 'Couple' : 'Single';

  static MembershipType fromLabel(String? raw) {
    final t = (raw ?? '').trim().toLowerCase();
    if (t.contains('couple') || t.contains('दो') || t == 'c') {
      return MembershipType.couple;
    }
    return MembershipType.single;
  }
}

enum MemberGender { male, female }

extension MemberGenderX on MemberGender {
  String get label => this == MemberGender.male ? 'Male' : 'Female';
  String get short => this == MemberGender.male ? 'M' : 'F';

  static MemberGender fromRaw(String? raw) {
    final t = (raw ?? '').trim().toLowerCase();
    if (t.contains('f') || t.contains('female') || t.contains('lioness') || t == 'स्त्री') {
      return MemberGender.female;
    }
    return MemberGender.male;
  }
}

/// One person = one member (pati aur patni alag-alag records).
class Member {
  const Member({
    required this.id,
    this.name = '',
    this.phone = '',
    this.dob = '',
    this.profession = '',
    this.photo = '',
    this.gender = MemberGender.male,
    this.anniversary = '',
    this.address = '',
    this.proposer = '',
    this.membershipType = MembershipType.single,
    this.spouseId = '',
  });

  final String id;
  final String name;
  final String phone;
  final String dob;
  final String profession;
  final String photo;
  final MemberGender gender;
  final String anniversary;
  final String address;
  final String proposer;
  final MembershipType membershipType;
  /// Other person's [Member.id] when couple (pati ↔ patni).
  final String spouseId;

  String get displayName {
    final n = name.trim();
    return n.isEmpty ? 'Unnamed member' : n;
  }

  String get primaryPhone => phone.trim();
  String get primaryPhoto => photo.trim();
  bool get hasSpouse => spouseId.trim().isNotEmpty;

  bool matchesQuery(String q) {
    final needle = q.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return [
      name,
      phone,
      profession,
      address,
      proposer,
      anniversary,
      gender.label,
      membershipType.label,
    ].any((s) => s.toLowerCase().contains(needle));
  }

  bool get isSane {
    final blobs = [name, phone, address, displayName];
    for (final s in blobs) {
      if (s.contains('\uFFFD')) return false;
      if (RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]').hasMatch(s)) return false;
      final letters = RegExp(r'[A-Za-z\u0900-\u097F0-9]').allMatches(s).length;
      final weird = RegExp(r'[^A-Za-z\u0900-\u097F0-9\s\-&./,()+]').allMatches(s).length;
      if (s.length >= 8 && letters > 0 && weird > letters) return false;
      if (s.length > 120) return false;
    }
    if (name.trim().isEmpty) return false;
    if (RegExp(r'[A-Za-z\u0900-\u097F]').allMatches(name).length < 2) return false;
    return true;
  }

  bool hasBirthdayOn(DateTime day) => _sameMonthDay(dob, day);

  bool hasAnniversaryOn(DateTime day) => _sameMonthDay(anniversary, day);

  static bool _sameMonthDay(String raw, DateTime day) {
    final d = parseFlexibleDate(raw);
    if (d == null) return false;
    return d.month == day.month && d.day == day.day;
  }

  static DateTime? parseFlexibleDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final parts = s.split(RegExp(r'[/\-.]'));
    if (parts.length == 3) {
      int? a = int.tryParse(parts[0]);
      int? b = int.tryParse(parts[1]);
      int? c = int.tryParse(parts[2]);
      if (a != null && b != null && c != null) {
        if (parts[0].length == 4) return DateTime(a, b, c);
        if (a > 31 && c <= 31) return DateTime(a, b, c);
        final day = a;
        final month = b;
        final year = c < 100 ? 2000 + c : c;
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          return DateTime(year, month, day);
        }
      }
    }
    return DateTime.tryParse(s);
  }

  static String formatDate(DateTime? d) {
    if (d == null) return '';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  Member copyWith({
    String? id,
    String? name,
    String? phone,
    String? dob,
    String? profession,
    String? photo,
    MemberGender? gender,
    String? anniversary,
    String? address,
    String? proposer,
    MembershipType? membershipType,
    String? spouseId,
    bool clearSpouse = false,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      dob: dob ?? this.dob,
      profession: profession ?? this.profession,
      photo: photo ?? this.photo,
      gender: gender ?? this.gender,
      anniversary: anniversary ?? this.anniversary,
      address: address ?? this.address,
      proposer: proposer ?? this.proposer,
      membershipType: membershipType ?? this.membershipType,
      spouseId: clearSpouse ? '' : (spouseId ?? this.spouseId),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'dob': dob,
        'profession': profession,
        'photo': photo,
        'gender': gender.name,
        'anniversary': anniversary,
        'address': address,
        'proposer': proposer,
        'membershipType': membershipType.name,
        'spouseId': spouseId,
        'v': 2,
      };

  factory Member.fromJson(Map<String, dynamic> j) {
    // Legacy couple-row (v1): prefer male fields if present as combined record.
    if (j['v'] != 2 && (j.containsKey('nameM') || j.containsKey('nameF'))) {
      final nameM = (j['nameM'] ?? '').toString().trim();
      final nameF = (j['nameF'] ?? '').toString().trim();
      final useFemale = nameM.isEmpty && nameF.isNotEmpty;
      return Member(
        id: (j['id'] ?? '').toString(),
        name: useFemale ? nameF : (nameM.isNotEmpty ? nameM : (j['name'] ?? '').toString()),
        phone: useFemale
            ? (j['phoneF'] ?? '').toString()
            : (j['phoneM'] ?? j['mobile'] ?? j['phone'] ?? '').toString(),
        dob: useFemale ? (j['dobF'] ?? '').toString() : (j['dobM'] ?? j['dob'] ?? '').toString(),
        profession: useFemale
            ? (j['professionF'] ?? '').toString()
            : (j['professionM'] ?? j['business'] ?? j['profession'] ?? '').toString(),
        photo: useFemale
            ? (j['photoF'] ?? '').toString()
            : (j['photoM'] ?? j['photo'] ?? '').toString(),
        gender: useFemale ? MemberGender.female : MemberGender.male,
        anniversary: (j['anniversary'] ?? '').toString(),
        address: (j['address'] ?? '').toString(),
        proposer: (j['proposer'] ?? '').toString(),
        membershipType: MembershipTypeX.fromLabel(
          (j['membershipType'] ?? j['type'] ?? 'single').toString(),
        ),
        spouseId: (j['spouseId'] ?? '').toString(),
      );
    }

    return Member(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? j['nameM'] ?? '').toString(),
      phone: (j['phone'] ?? j['phoneM'] ?? j['mobile'] ?? '').toString(),
      dob: (j['dob'] ?? j['dobM'] ?? '').toString(),
      profession: (j['profession'] ?? j['professionM'] ?? j['business'] ?? '').toString(),
      photo: (j['photo'] ?? j['photoM'] ?? '').toString(),
      gender: MemberGenderX.fromRaw((j['gender'] ?? 'male').toString()),
      anniversary: (j['anniversary'] ?? '').toString(),
      address: (j['address'] ?? '').toString(),
      proposer: (j['proposer'] ?? '').toString(),
      membershipType: MembershipTypeX.fromLabel(
        (j['membershipType'] ?? j['type'] ?? 'single').toString(),
      ),
      spouseId: (j['spouseId'] ?? '').toString(),
    );
  }

  /// Split a legacy couple JSON row into 1–2 individual members.
  static List<Member> fromLegacyCoupleRow(Map<String, dynamic> j) {
    final type = MembershipTypeX.fromLabel(
      (j['membershipType'] ?? j['type'] ?? '').toString(),
    );
    final anniversary = (j['anniversary'] ?? '').toString();
    final address = (j['address'] ?? '').toString();
    final proposer = (j['proposer'] ?? '').toString();
    final baseId = (j['id'] ?? 'm_${DateTime.now().microsecondsSinceEpoch}').toString();

    final nameM = (j['nameM'] ?? '').toString().trim();
    final nameF = (j['nameF'] ?? '').toString().trim();
    final out = <Member>[];

    String? idM;
    String? idF;
    if (nameM.isNotEmpty) {
      idM = '${baseId}_m';
      out.add(
        Member(
          id: idM,
          name: nameM,
          phone: (j['phoneM'] ?? '').toString(),
          dob: (j['dobM'] ?? '').toString(),
          profession: (j['professionM'] ?? '').toString(),
          photo: (j['photoM'] ?? '').toString(),
          gender: MemberGender.male,
          anniversary: anniversary,
          address: address,
          proposer: proposer,
          membershipType: nameF.isNotEmpty ? MembershipType.couple : type,
        ),
      );
    }
    if (nameF.isNotEmpty) {
      idF = '${baseId}_f';
      out.add(
        Member(
          id: idF,
          name: nameF,
          phone: (j['phoneF'] ?? '').toString(),
          dob: (j['dobF'] ?? '').toString(),
          profession: (j['professionF'] ?? '').toString(),
          photo: (j['photoF'] ?? '').toString(),
          gender: MemberGender.female,
          anniversary: anniversary,
          address: address,
          proposer: proposer,
          membershipType: nameM.isNotEmpty ? MembershipType.couple : type,
        ),
      );
    }

    if (out.length == 2) {
      return [
        out[0].copyWith(spouseId: out[1].id),
        out[1].copyWith(spouseId: out[0].id),
      ];
    }
    return out;
  }
}
