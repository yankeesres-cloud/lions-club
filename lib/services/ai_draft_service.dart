import '../models/club_role.dart';
import '../models/member.dart';
import '../models/post_desk.dart';
import 'app_clock.dart';
import 'board_store.dart';
import 'club_settings_store.dart';
import 'star_rating_service.dart';

/// Local AI draft helper (template-based) — offline, Lions Club tone.
class AiDraftService {
  static String generate({
    required DeskType desk,
    required ClubRole role,
    required String userName,
    required String programName,
    required String date,
    required String place,
    required String guestOrNote,
    String language = 'hi',
  }) {
    final club = ClubSettingsStore.current.clubName;
    final city = ClubSettingsStore.current.city;
    final prog = programName.trim().isEmpty ? 'Club Meeting / Program' : programName.trim();
    final when = date.trim().isEmpty ? 'निर्धारित तिथि' : date.trim();
    final where = place.trim().isEmpty ? (city.isEmpty ? 'Club venue' : city) : place.trim();
    final guest = guestOrNote.trim();
    final who = userName.trim().isEmpty ? role.label : userName.trim();

    if (language == 'en') {
      return _en(desk, club, prog, when, where, guest, who, role);
    }
    return _hi(desk, club, prog, when, where, guest, who, role);
  }

  /// Club wall birthday — naam, umr, business, board post, star rating se personalized.
  static String birthdayWallWishForMember(
    Member member, {
    bool forTomorrow = false,
  }) {
    final clubLabel = _clubLabel();
    final name = member.displayName.trim().isEmpty
        ? 'लायन्स मित्र'
        : member.displayName.trim();
    final honor = member.gender == MemberGender.female ? 'लायनेस' : 'लायन';
    final whenHi = forTomorrow ? 'कल' : 'आज';
    final age = member.ageYears(asOf: AppClock.today);
    final business = member.profession.trim();
    final post = _boardPostLabel(member.id);
    final stars = StarRatingService.starsFor(member.id);
    final praise = _achaiyanLines(
      age: age,
      business: business,
      post: post,
      stars: stars,
      gender: member.gender,
    );

    return '🦁 आदरणीय $honor $name जी,\n\n'
        '$whenHi आपके जन्मदिन पर $clubLabel परिवार की ओर से हार्दिक शुभकामनाएँ!\n\n'
        '$praise\n\n'
        'सुख, स्वास्थ्य, समृद्धि और लंबी आयु की कामना। आपका यह वर्ष सेवा और सफलता से भरा रहे।\n\n'
        'Happy Birthday! 🎂\n'
        'जय लायन्स, जय हिन्द।';
  }

  /// Club wall anniversary — couple / member ke details se.
  static String anniversaryWallWishForMembers(
    List<Member> mates, {
    bool forTomorrow = false,
  }) {
    final clubLabel = _clubLabel();
    final whenHi = forTomorrow ? 'कल' : 'आज';
    final names = mates
        .map((m) => m.displayName.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    final who = names.isEmpty
        ? 'लायन्स दंपति'
        : (names.length == 1 ? names.first : names.join(' एवं '));

    final bits = <String>[];
    for (final m in mates) {
      final business = m.profession.trim();
      final post = _boardPostLabel(m.id);
      final part = <String>[];
      if (business.isNotEmpty) part.add(business);
      if (post.isNotEmpty) part.add(post);
      if (m.stars > 0) part.add('${'★' * m.stars} (${m.stars}/5)');
      if (part.isNotEmpty) {
        bits.add('${m.displayName.trim()} — ${part.join(', ')}');
      }
    }

    final mid = bits.isEmpty
        ? 'आपका प्रेम, समझ और परिवार के प्रति समर्पण हमारे क्लब के लिए प्रेरणा है।'
        : 'क्लब परिवार आपकी उपलब्धियों का सम्मान करता है:\n${bits.map((b) => '• $b').join('\n')}\n\n'
            'आपके वैवाहिक जीवन की मधुरता और सेवा-भाव दोनों अनुकरणीय हैं।';

    return '💍 आदरणीय $who,\n\n'
        '$whenHi आपके विवाहोत्सव पर $clubLabel की हार्दिक बधाई!\n\n'
        '$mid\n\n'
        'साथ-साथ सुख, शांति और समृद्धि बनी रहे।\n\n'
        'Happy Anniversary! ❤️\n'
        'जय लायन्स।';
  }

  static String _clubLabel() {
    final club = ClubSettingsStore.current.clubName.trim();
    return club.isEmpty ? 'Lions Club' : club;
  }

  static String _boardPostLabel(String memberId) {
    final posts = BoardStore.postsForMember(memberId)
        .map((p) => p.title.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (posts.isEmpty) return '';
    return posts.join(' / ');
  }

  /// Umr, business, post, stars — Narendra Singhal style achaiyan paragraph.
  static String _achaiyanLines({
    required int? age,
    required String business,
    required String post,
    required int stars,
    required MemberGender gender,
  }) {
    final lines = <String>[];

    if (age != null) {
      lines.add(
        'लगभग $age वर्षों की समृद्ध जीवन-यात्रा के साथ आप अनुभव और समझ के प्रतीक हैं।',
      );
    }
    if (business.isNotEmpty) {
      lines.add(
        'व्यवसाय / पेशे में ($business) आपकी मेहनत और सफलता क्लब परिवार के लिए गर्व की बात है।',
      );
    }
    if (post.isNotEmpty) {
      lines.add(
        'क्लब में "$post" के पद पर आपके नेतृत्व, सहयोग और सेवा ने सबको प्रेरित किया है।',
      );
    } else {
      lines.add(
        'लायन्स आंदोलन में आपकी सक्रिय सदस्यता और सेवा-भाव सराहनीय है।',
      );
    }
    if (stars > 0) {
      final starBar = '★' * stars + '☆' * (5 - stars);
      lines.add(
        'आपकी क्लब स्टार रेटिंग $starBar ($stars/5) — '
        '${_starPraise(stars, gender)}',
      );
    }

    if (lines.isEmpty) {
      return 'आपकी सेवा, मित्रता और सहयोग ${_clubLabel()} की पहचान हैं।';
    }
    return lines.join('\n');
  }

  static String _starPraise(int stars, MemberGender gender) {
    final aap = gender == MemberGender.female ? 'आप' : 'आप';
    switch (stars) {
      case 5:
        return '$aap क्लब के सितारे हैं; आपकी उपलब्धियाँ अनुकरणीय हैं।';
      case 4:
        return 'उत्कृष्ट योगदान — क्लब आप पर गर्व करता है।';
      case 3:
        return 'निरंतर सहयोग और अच्छी सेवा के लिए धन्यवाद।';
      case 2:
        return 'आपकी भागीदारी महत्वपूर्ण है; आगे भी साथ बने रहें।';
      default:
        return 'क्लब परिवार में आपका स्वागत और सहयोग अमूल्य है।';
    }
  }

  static String _hi(
    DeskType desk,
    String club,
    String prog,
    String when,
    String where,
    String guest,
    String who,
    ClubRole role,
  ) {
    final g = guest.isEmpty ? '' : '\nविशिष्ट अतिथि / नोट: $guest';
    switch (desk) {
      case DeskType.agenda:
        return '''$club
कार्यसूची (Agenda)
कार्यक्रम: $prog
दिनांक: $when
स्थान: $where$g

1. सभापति द्वारा सभा का आह्वान
2. लायन्स प्रार्थना / ओथ
3. स्वागत भाषण
4. पिछली बैठक के कार्यवृत्त की पुष्टि
5. सचिव की रिपोर्ट
6. कोषाध्यक्ष की रिपोर्ट
7. आगामी कार्यक्रमों पर चर्चा
8. अतिथि / विशेष संबोधन${guest.isEmpty ? '' : ' ($guest)'}
9. धन्यवाद ज्ञापन
10. सभापति की अनुमति से सभा समाप्ति

— तैयारकर्ता: $who (${role.label})
— AI Assistant सहायता से''';
      case DeskType.abharSpeech:
        return '''आदरणीय सभापति महोदय, पदाधिकारीगण, लायन्स मित्रों,

आज के कार्यक्रम "$prog" ($when, $where) में आप सभी का हार्दिक आभार।

${guest.isEmpty ? 'विशेष रूप से सभी सहयोगियों का धन्यवाद जिन्होंने इस आयोजन को सफल बनाया।' : 'विशेष रूप से $guest का हार्दिक आभार, जिनकी उपस्थिति से कार्यक्रम गरिमामय बना।'}

$club परिवार की ओर से सबके स्वास्थ्य, सुख-समृद्धि की कामना करता/करती हूँ।

धन्यवाद।
जय लायन्स, जय हिन्द।

— $who (${role.label})''';
      case DeskType.welcomeSpeech:
        return '''आदरणीय सभापति महोदय, पदाधिकारीगण एवं लायन्स मित्रों,

$club की ओर से आप सभी का "$prog" में हार्दिक स्वागत है।
दिनांक: $when | स्थान: $where$g

आज हम सेवा, मित्रता और नेतृत्व की भावना से एकत्र हुए हैं। आशा है यह कार्यक्रम प्रेरणादायक एवं सफल होगा।

स्वागत है, स्वागत है, स्वागत है।

— $who (${role.label})''';
      case DeskType.invitation:
        return '''प्रिय लायन्स मित्र,

$club आपको सादर आमंत्रित करता है:

कार्यक्रम: $prog
दिनांक: $when
स्थान: $where$g

कृपया समय पर पधारें और परिवार सहित उपस्थिति दर्ज कराएँ।
आपकी उपस्थिति हमें गौरवान्वित करेगी।

सादर,
$who
${role.label}
$club''';
      case DeskType.meetingReport:
        return '''$club — कार्यक्रम / बैठक रिपोर्ट

विषय: $prog
दिनांक: $when
स्थान: $where$g

मुख्य बिंदु:
• उपस्थिति संतोषजनक रही
• एजेंडा अनुसार चर्चा संपन्न
• आगामी कार्यों हेतु जिम्मेदारियाँ तय
• सेवा भाव से सभी का सहयोग सराहनीय

निष्कर्ष: कार्यक्रम सफलतापूर्वक संपन्न हुआ।

रिपोर्ट: $who (${role.label})''';
      case DeskType.birthdayWish:
        return '''प्रिय ${guest.isEmpty ? 'लायन्स मित्र' : guest},

जन्मदिन की हार्दिक शुभकामनाएँ!
$club परिवार की ओर से सुख, स्वास्थ्य और लंबी आयु की कामना।

Happy Birthday!
— $who''';
      case DeskType.anniversaryWish:
        return '''प्रिय ${guest.isEmpty ? 'लायन्स दंपति' : guest},

विवाहोत्सव की हार्दिक बधाई!
आपके वैवाहिक जीवन में सुख-शांति बनी रहे — $club की शुभकामनाएँ।

— $who''';
      case DeskType.socialCaption:
        return '''🦁 $club
📍 $where | 📅 $when

"$prog" — सेवा की मिसाल! ✨
${guest.isEmpty ? '' : 'विशेष उपस्थिति: $guest\n'}
#LionsClub #WeServe #Gwalior #LionsClubPro

— $who''';
      case DeskType.mediaRelease:
        return '''प्रेस नोट / Media Release

$club द्वारा "$prog" का आयोजन
दिनांक: $when | स्थान: $where$g

क्लब ने समुदाय सेवा एवं नेतृत्व विकास के उद्देश्य से यह कार्यक्रम आयोजित किया। पदाधिकारियों एवं सदस्यों की सक्रिय भागीदारी रही।

अधिक जानकारी: $who (${role.label})
$club''';
      case DeskType.accountsNote:
        return '''$club — लेखा नोट

संदर्भ: $prog
दिनांक: $when$g

• आय / सदस्य शुल्क: ______
• व्यय: ______
• शेष / बैंक बैलेंस नोट: ______
• लंबित बकाया: ______

टिप्पणी: कृपया रसीदें / वाउचर संलग्न करें।

— $who (${role.label})''';
      case DeskType.serviceNote:
        return '''$club — सेवा गतिविधि नोट

गतिविधि: $prog
दिनांक: $when | स्थान: $where$g

उद्देश्य: समुदाय सेवा / स्वास्थ्य / शिक्षा / सहायता
सहभागी: सदस्य एवं स्वयंसेवक
प्रभाव: लाभार्थियों को सहयोग प्रदान

— $who (${role.label})''';
      case DeskType.noticeDraft:
        return '''सूचना / NOTICE

$club

विषय: $prog
दिनांक: $when
स्थान: $where$g

सभी सदस्यों से अनुरोध है कि उपरोक्त कार्यक्रम में अवश्य भाग लें।

आदेशानुसार,
$who
${role.label}''';
    }
  }

  static String _en(
    DeskType desk,
    String club,
    String prog,
    String when,
    String where,
    String guest,
    String who,
    ClubRole role,
  ) {
    final g = guest.isEmpty ? '' : '\nGuest / note: $guest';
    switch (desk) {
      case DeskType.agenda:
        return '''$club\nAgenda — $prog\nDate: $when | Venue: $where$g\n\n1. Call to order\n2. Lions prayer / pledge\n3. Welcome\n4. Confirm previous minutes\n5. Secretary report\n6. Treasurer report\n7. Upcoming programs\n8. Guest remarks\n9. Vote of thanks\n10. Adjournment\n\n— $who (${role.label})''';
      case DeskType.abharSpeech:
        return '''Respected President, officers and Lions friends,\n\nOn behalf of $club, my sincere thanks for "$prog" ($when, $where).\n${guest.isEmpty ? 'Thank you to every member who made this program a success.' : 'Special thanks to $guest for gracing the occasion.'}\n\nJai Lions.\n— $who (${role.label})''';
      case DeskType.welcomeSpeech:
        return '''Respected President and Lions friends,\n\nA warm welcome to "$prog" of $club.\nDate: $when | Venue: $where$g\n\nWelcome, welcome, welcome.\n— $who (${role.label})''';
      case DeskType.invitation:
        return '''Dear Lion,\n\n$club cordially invites you:\nProgram: $prog\nDate: $when\nVenue: $where$g\n\nYour presence will encourage us.\n— $who, ${role.label}''';
      case DeskType.meetingReport:
        return '''$club — Report\nProgram: $prog\nDate: $when | Venue: $where$g\n\nKey points discussed; responsibilities assigned; program concluded successfully.\n— $who (${role.label})''';
      case DeskType.birthdayWish:
        return '''Dear ${guest.isEmpty ? 'Lion Friend' : guest},\n\nHappy Birthday from $club!\n— $who''';
      case DeskType.anniversaryWish:
        return '''Dear ${guest.isEmpty ? 'Lion Couple' : guest},\n\nHappy Anniversary from $club!\n— $who''';
      case DeskType.socialCaption:
        return '''🦁 $club | $prog\n📍 $where | 📅 $when\n${guest.isEmpty ? '' : 'Guest: $guest\n'}#LionsClub #WeServe\n— $who''';
      case DeskType.mediaRelease:
        return '''Media Release — $club\n"$prog" held on $when at $where.$g\nContact: $who (${role.label})''';
      case DeskType.accountsNote:
        return '''$club — Accounts note\nRef: $prog | $when\nIncome: __  Expense: __  Pending: __\n— $who (${role.label})''';
      case DeskType.serviceNote:
        return '''$club — Service note\nActivity: $prog | $when | $where$g\n— $who (${role.label})''';
      case DeskType.noticeDraft:
        return '''NOTICE — $club\nSubject: $prog\nDate: $when | Place: $where$g\nAll members are requested to attend.\n— $who (${role.label})''';
    }
  }
}
