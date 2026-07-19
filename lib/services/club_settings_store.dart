import 'package:shared_preferences/shared_preferences.dart';

import '../models/member.dart';

class ClubSettingsStore {
  static const _kName = 'club_name';
  static const _kDistrict = 'club_district';
  static const _kRegion = 'club_region';
  static const _kCity = 'club_city';
  static const _kState = 'club_state';
  static const _kCharter = 'club_charter_date';
  static const _kMeetingPlace = 'club_meeting_place';
  static const _kMeetingDay = 'club_meeting_day';
  static const _kEmail = 'club_email';
  static const _kPhone = 'club_phone';

  static ClubProfile _cache = const ClubProfile();
  static bool _loaded = false;

  static ClubProfile get current => _cache;

  static Future<ClubProfile> load() async {
    final p = await SharedPreferences.getInstance();
    const d = ClubProfile();
    _cache = ClubProfile(
      clubName: p.getString(_kName) ?? d.clubName,
      district: p.getString(_kDistrict) ?? d.district,
      region: p.getString(_kRegion) ?? d.region,
      city: p.getString(_kCity) ?? d.city,
      state: p.getString(_kState) ?? d.state,
      charterDate: p.getString(_kCharter) ?? d.charterDate,
      meetingPlace: p.getString(_kMeetingPlace) ?? d.meetingPlace,
      meetingDay: p.getString(_kMeetingDay) ?? d.meetingDay,
      clubEmail: p.getString(_kEmail) ?? d.clubEmail,
      clubPhone: p.getString(_kPhone) ?? d.clubPhone,
    );
    _loaded = true;
    return _cache;
  }

  static Future<void> save(ClubProfile club) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kName, club.clubName.trim());
    await p.setString(_kDistrict, club.district.trim());
    await p.setString(_kRegion, club.region.trim());
    await p.setString(_kCity, club.city.trim());
    await p.setString(_kState, club.state.trim());
    await p.setString(_kCharter, club.charterDate.trim());
    await p.setString(_kMeetingPlace, club.meetingPlace.trim());
    await p.setString(_kMeetingDay, club.meetingDay.trim());
    await p.setString(_kEmail, club.clubEmail.trim());
    await p.setString(_kPhone, club.clubPhone.trim());
    _cache = club;
    _loaded = true;
  }

  static Future<ClubProfile> ensureLoaded() async {
    if (_loaded) return _cache;
    return load();
  }
}
