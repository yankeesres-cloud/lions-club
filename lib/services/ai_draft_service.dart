import '../models/club_role.dart';
import '../models/post_desk.dart';
import 'club_settings_store.dart';

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
