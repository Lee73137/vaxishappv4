import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Single source of truth for this device's persisted id.
///
/// Previously LocationService and FcmTokenService each generated and saved
/// their own id independently. On a fresh install, both fire concurrently
/// right after login (login_page.dart's two `unawaited()` calls) — with no
/// id in storage yet, both could read null at the same moment and each
/// generate a *different* random id, splitting one physical device across
/// two separate vaxi_UserDevice rows server-side (one with the FCM token,
/// a sibling with the location). Memoizing the in-flight load here means
/// every concurrent caller — regardless of which service asks first —
/// converges on the exact same id.
class DeviceIdService {
  static final DeviceIdService _instance = DeviceIdService._internal();
  factory DeviceIdService() => _instance;
  DeviceIdService._internal();

  static const _prefsKey = 'device_id';
  final Uuid _uuid = const Uuid();

  String? _cached;
  Future<String>? _inFlight;

  /// Returns this device's id, generating and persisting one on first use.
  Future<String> getOrCreate() {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    return _inFlight ??= _load();
  }

  /// Returns the id if one already exists, without generating a new one.
  Future<String?> peek() async {
    if (_cached != null) return _cached;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }

  Future<String> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_prefsKey);
      if (id == null || id.isEmpty) {
        id = _uuid.v4();
        await prefs.setString(_prefsKey, id);
      }
      _cached = id;
      return id;
    } finally {
      _inFlight = null;
    }
  }
}
